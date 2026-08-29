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

writeFileSync(outputPath, flow.toJsonString());
console.log(`Wrote ${outputPath}`);
