import {
  ConnectParticipantWithLexBotActionBuilder,
  DisconnectParticipantActionBuilder,
  FlowBuilder,
  GetParticipantInputActionBuilder,
  InvokeLambdaFunctionActionBuilder,
  LoopActionBuilder,
  MessageParticipantActionBuilder,
  UpdateContactAttributesActionBuilder,
  equalsCondition,
} from "connect-flow-builder";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const ASANA_TICKET_LAMBDA_ARN = requireEnv("ASANA_TICKET_LAMBDA_ARN");
const LEX_BOT_ALIAS_ARN = requireEnv("LEX_BOT_ALIAS_ARN");

const disconnect = new DisconnectParticipantActionBuilder("Disconnect").build();

const returnCaseNumber = new MessageParticipantActionBuilder("ReturnCaseNumber")
  .text(
    "Your case number is $.External.caseNumber. Our support team will " +
      "review and respond to you as soon as possible. Thank you for calling.",
  )
  .next("Disconnect")
  .onError("Disconnect")
  .build();

const createTicket = new InvokeLambdaFunctionActionBuilder("CreateTicket")
  .lambdaArn(ASANA_TICKET_LAMBDA_ARN)
  .timeLimitSeconds(8)
  .invocationAttribute("IssueDescription", "$.Attributes.IssueDescription")
  .invocationAttribute("AdditionalDetail", "$.Attributes.AdditionalDetail")
  .next("ReturnCaseNumber")
  .onError("Disconnect")
  .build();

const forwardingMessage = new MessageParticipantActionBuilder(
  "ForwardingMessage",
)
  .text(
    "Thank you. I have recorded the issue you described and am forwarding " +
      "it to our support team. Please hold for a case number.",
  )
  .next("CreateTicket")
  .onError("Disconnect")
  .build();

const saveAdditionalDetail = new UpdateContactAttributesActionBuilder(
  "SaveAdditionalDetail",
)
  .targetCurrent()
  .attribute("AdditionalDetail", "$.Lex.Slots.IssueDescription")
  .next("ForwardingMessage")
  .onError("ForwardingMessage")
  .build();

const captureAdditionalIssue = new ConnectParticipantWithLexBotActionBuilder(
  "CaptureAdditionalIssue",
)
  .text("Okay, what else can we add to your ticket?")
  .lexV2BotAliasArn(LEX_BOT_ALIAS_ARN)
  .whenIntentEquals("DescribeIssueIntent", "SaveAdditionalDetail")
  .onInputTimeLimitExceeded("ForwardingMessage")
  .onNoMatchingCondition("ForwardingMessage")
  .onError("ForwardingMessage")
  .build();

const askAnythingElse = new GetParticipantInputActionBuilder(
  "AskAnythingElse",
)
  .text(
    "Okay, thank you. I have recorded your issue. Is there anything else " +
      "you would like to add? Please answer yes or no.",
  )
  .inputTimeLimitSeconds(5)
  .when(equalsCondition("yes"), "CaptureAdditionalIssue")
  .when(equalsCondition("no"), "ForwardingMessage")
  .next("ForwardingMessage")
  .onError("ForwardingMessage", "NoMatchingCondition")
  .onError("ForwardingMessage", "InputTimeLimitExceeded")
  .onError("ForwardingMessage")
  .build();

const saveIssueDescription = new UpdateContactAttributesActionBuilder(
  "SaveIssueDescription",
)
  .targetCurrent()
  .attribute("IssueDescription", "$.Lex.Slots.IssueDescription")
  .attribute("AdditionalDetail", "")
  .next("AskAnythingElse")
  .onError("AskAnythingElse")
  .build();

const retryLoop = new LoopActionBuilder("RetryLoop")
  .loopCount(2)
  .whenContinueLooping("RetryDescribeIssue")
  .whenDoneLooping("GeneralQueueTransfer")
  .build();

const generalQueueTransfer = new MessageParticipantActionBuilder(
  "GeneralQueueTransfer",
)
  .text(
    "We're having trouble hearing your response. Let's connect you with " +
      "an agent who can help.",
  )
  .next("Disconnect")
  .onError("Disconnect")
  .build();

const retryDescribeIssue = new ConnectParticipantWithLexBotActionBuilder(
  "RetryDescribeIssue",
)
  .text(
    "Sorry, it seems nothing was said. If you would like to continue " +
      "opening a ticket, please describe your issue.",
  )
  .lexV2BotAliasArn(LEX_BOT_ALIAS_ARN)
  .whenIntentEquals("DescribeIssueIntent", "SaveIssueDescription")
  .onInputTimeLimitExceeded("RetryLoop")
  .onNoMatchingCondition("RetryLoop")
  .onError("RetryLoop")
  .build();

const describeIssue = new ConnectParticipantWithLexBotActionBuilder(
  "DescribeIssue",
)
  .text(
    "Please tell us the issue you are experiencing and need help with. " +
      "We'll open a ticket and get started on solving your issue.",
  )
  .lexV2BotAliasArn(LEX_BOT_ALIAS_ARN)
  .whenIntentEquals("DescribeIssueIntent", "SaveIssueDescription")
  .onInputTimeLimitExceeded("RetryLoop")
  .onNoMatchingCondition("RetryLoop")
  .onError("RetryLoop")
  .build();

const flow = new FlowBuilder("AsanaIntegration")
  .startWith(describeIssue)
  .add(retryLoop)
  .add(retryDescribeIssue)
  .add(generalQueueTransfer)
  .add(saveIssueDescription)
  .add(askAnythingElse)
  .add(captureAdditionalIssue)
  .add(saveAdditionalDetail)
  .add(forwardingMessage)
  .add(createTicket)
  .add(returnCaseNumber)
  .add(disconnect)
  .build();

const definition = flow.toConnectDefinition() as unknown as Record<
  string,
  unknown
>;

if (!definition.Settings) {
  definition.Settings = {
    InputParameters: [],
    OutputParameters: [],
    Transitions: [
      { DisplayName: "Success", ReferenceName: "Success", Description: "" },
      { DisplayName: "Error", ReferenceName: "Error", Description: "" },
    ],
  };
}

const outputPath = process.env.FLOW_OUTPUT_PATH
  ? resolve(process.env.FLOW_OUTPUT_PATH)
  : resolve(
      dirname(fileURLToPath(import.meta.url)),
      "../modules/asana-flow-module/contact_flows/asana_integration.json",
    );

writeFileSync(outputPath, JSON.stringify(definition, null, 2));
console.log(`Wrote ${outputPath}`);
