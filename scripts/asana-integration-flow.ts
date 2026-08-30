import {
  ConnectParticipantWithLexBotActionBuilder,
  DisconnectParticipantActionBuilder,
  FlowBuilder,
  InvokeLambdaFunctionActionBuilder,
  MessageParticipantActionBuilder,
  UpdateContactRecordingAndAnalyticsBehaviorActionBuilder,
  UpdateFlowLoggingBehaviorActionBuilder,
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
const BEEP_WAV_S3_URI = requireEnv("BEEP_WAV_S3_URI");
const LEX_SPEECH_DETECTION_BOT_ALIAS_ARN = requireEnv(
  "LEX_SPEECH_DETECTION_BOT_ALIAS_ARN",
);

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
  .invocationAttribute("CustomerId", "$.Attributes.CustomerId")
  .invocationAttribute("CallerAni", "$.CustomerEndpoint.Address")
  .next("ReturnCaseNumber")
  .onError("Disconnect")
  .build();

const pleaseWait = new MessageParticipantActionBuilder("PleaseWait")
  .text(
    "Thank you. Please hold for a moment while we open a case for your " +
      "issue.",
  )
  .next("CreateTicket")
  .onError("Disconnect")
  .build();

const disableRecording = new UpdateContactRecordingAndAnalyticsBehaviorActionBuilder(
  "DisableRecording",
)
  .voiceRecording([], "Disabled")
  .next("PleaseWait")
  .onError("PleaseWait", "NoMatchingError")
  .onError("PleaseWait", "ChannelMismatch")
  .build();

const describeIssue = new MessageParticipantActionBuilder("DescribeIssue")
  .text(
    "Please describe the issue you are experiencing. We'll record your " +
      "description and open a support ticket.",
  )
  .next("Beep")
  .onError("Beep")
  .build();

const beep = new MessageParticipantActionBuilder("Beep")
  .text("placeholder")
  .next("EnableRecording")
  .onError("EnableRecording")
  .build();

const recordingPause = new ConnectParticipantWithLexBotActionBuilder(
  "RecordingPause",
)
  .ssml(`<speak><break time="1s"/></speak>`)
  .lexV2BotAliasArn(LEX_SPEECH_DETECTION_BOT_ALIAS_ARN)
  .sessionAttribute("x-amz-lex:audio:start-timeout-ms:*:*", "4000")
  .sessionAttribute("x-amz-lex:audio:end-timeout-ms:*:*", "2000")
  .sessionAttribute("x-amz-lex:audio:max-length-ms:*:*", "30000")
  .whenIntentEquals("CaptureIntent", "DisableRecording")
  .onNoMatchingCondition("DisableRecording")
  .onInputTimeLimitExceeded("DisableRecording")
  .onError("DisableRecording")
  .build();

const enableRecording = new UpdateContactRecordingAndAnalyticsBehaviorActionBuilder(
  "EnableRecording",
)
  .voiceRecording([], "Enabled")
  .next("RecordingPause")
  .onError("RecordingPause", "NoMatchingError")
  .onError("RecordingPause", "ChannelMismatch")
  .build();

const enableLogging = new UpdateFlowLoggingBehaviorActionBuilder(
  "EnableLogging",
)
  .enabled()
  .next("DescribeIssue")
  .build();

const flow = new FlowBuilder("AsanaIntegration")
  .startWith(enableLogging)
  .add(describeIssue)
  .add(beep)
  .add(enableRecording)
  .add(recordingPause)
  .add(disableRecording)
  .add(pleaseWait)
  .add(createTicket)
  .add(returnCaseNumber)
  .add(disconnect)
  .build();

const definition = flow.toConnectDefinition() as unknown as {
  Actions: Array<{
    Identifier: string;
    Parameters?: {
      Text?: string;
      SSML?: string;
      Media?: { Uri: string; SourceType: string; MediaType: string };
    };
    Transitions?: { Errors?: unknown[] };
  }>;
  Settings?: unknown;
};

for (const action of definition.Actions) {
  if (action.Identifier === "Beep" && action.Parameters) {
    action.Parameters.Media = {
      Uri: BEEP_WAV_S3_URI,
      SourceType: "S3",
      MediaType: "Audio",
    };
    delete action.Parameters.Text;
  }
  if (action.Identifier === "ReturnCaseNumber" && action.Parameters) {
    action.Parameters.SSML =
      `<speak>Your case number is <say-as interpret-as="characters">` +
      `$.External.caseNumber</say-as>. Our support team will review and ` +
      `respond to you as soon as possible. Thank you for calling.</speak>`;
    delete action.Parameters.Text;
  }
}

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
