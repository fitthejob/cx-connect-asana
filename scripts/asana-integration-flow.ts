import {
  DisconnectParticipantActionBuilder,
  FlowBuilder,
  InvokeLambdaFunctionActionBuilder,
  MessageParticipantActionBuilder,
  UpdateContactRecordingBehaviorActionBuilder,
  UpdateFlowLoggingBehaviorActionBuilder,
  WaitActionBuilder,
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

const disableRecording = new UpdateContactRecordingBehaviorActionBuilder(
  "DisableRecording",
)
  .recordParticipants()
  .enableIvrRecording()
  .analyticsEnabled("en-US")
  .next("PleaseWait")
  .build();

const recordingWindow = new WaitActionBuilder("RecordingWindow")
  .timeoutSeconds(20)
  .onWaitCompleted("DisableRecording")
  .build();

const describeIssue = new MessageParticipantActionBuilder("DescribeIssue")
  .text(
    "Please describe the issue you are experiencing after the tone. " +
      "We'll record your description and open a support ticket.",
  )
  .next("RecordingWindow")
  .onError("DisableRecording")
  .build();

const enableRecording = new UpdateContactRecordingBehaviorActionBuilder(
  "EnableRecording",
)
  .recordParticipants()
  .enableIvrRecording()
  .analyticsEnabled("en-US")
  .next("DescribeIssue")
  .build();

const enableLogging = new UpdateFlowLoggingBehaviorActionBuilder(
  "EnableLogging",
)
  .enabled()
  .next("EnableRecording")
  .build();

const flow = new FlowBuilder("AsanaIntegration")
  .startWith(enableLogging)
  .add(enableRecording)
  .add(describeIssue)
  .add(recordingWindow)
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
      RecordingBehavior?: { IVRRecordingBehavior?: string };
      TimeoutSeconds?: number;
      TimeLimitSeconds?: number;
    };
    Transitions?: { Errors?: unknown[] };
  }>;
  Settings?: unknown;
};

for (const action of definition.Actions) {
  if (
    (action.Identifier === "EnableRecording" ||
      action.Identifier === "DisableRecording") &&
    action.Transitions
  ) {
    delete action.Transitions.Errors;
  }
  if (
    action.Identifier === "DisableRecording" &&
    action.Parameters?.RecordingBehavior
  ) {
    action.Parameters.RecordingBehavior.IVRRecordingBehavior = "Disabled";
  }
  if (
    action.Identifier === "RecordingWindow" &&
    action.Parameters?.TimeoutSeconds !== undefined
  ) {
    action.Parameters.TimeLimitSeconds = action.Parameters.TimeoutSeconds;
    delete action.Parameters.TimeoutSeconds;
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
