import {
  DisconnectParticipantActionBuilder,
  FlowBuilder,
  MessageParticipantActionBuilder,
} from "connect-flow-builder";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

// Placeholder flow; no logic yet

const greeting = new MessageParticipantActionBuilder("Greeting")
  .text("Asana self-service module placeholder.")
  .next("Disconnect")
  .build();

const disconnect = new DisconnectParticipantActionBuilder("Disconnect").build();

const flow = new FlowBuilder("AsanaIntegration")
  .startWith(greeting)
  .add(disconnect)
  .build();

const outputPath = process.env.FLOW_OUTPUT_PATH
  ? resolve(process.env.FLOW_OUTPUT_PATH)
  : resolve(
      dirname(fileURLToPath(import.meta.url)),
      "../modules/asana-flow-module/contact_flows/asana_integration.json",
    );

// connect-flow-builder's FlowBuilder has no API to set Settings, but
// CreateContactFlowModule requires it (confirmed live: "JSON field is
// missing or null for field name: settings"). ConnectFlowModuleSettings is
// defined in the library's own types.d.ts, so this is a real Connect
// requirement the library doesn't yet expose a builder method for --
// injected here as a post-processing step.
const definition = flow.toConnectDefinition();
const withSettings = {
  ...definition,
  Settings: {
    InputParameters: [],
    OutputParameters: [],
    Transitions: [
      { DisplayName: "Success", ReferenceName: "Success", Description: "" },
      { DisplayName: "Error", ReferenceName: "Error", Description: "" },
    ],
  },
};

writeFileSync(outputPath, JSON.stringify(withSettings, null, 2));
console.log(`Wrote ${outputPath}`);
