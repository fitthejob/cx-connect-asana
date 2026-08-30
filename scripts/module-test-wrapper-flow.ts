import {
  DisconnectParticipantActionBuilder,
  FlowBuilder,
  InvokeFlowModuleActionBuilder,
  UpdateFlowLoggingBehaviorActionBuilder,
} from "connect-flow-builder";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

// Disposable manual-test harness -- Connect has no native way to invoke a
// contact flow module standalone (modules only run inside a real flow), so
// this wrapper just invokes our Asana module and disconnects. NOT applied
// via Terraform -- pushed out-of-band to connect-terraform's
// Validation-Sandbox-dev (a real contact flow, not the module sandbox) via
// UpdateContactFlowContent, then point the test phone number at it. Same
// pattern as connect-terraform's own module-test-wrapper-flow.ts.
function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const ASANA_MODULE_ID = requireEnv("ASANA_MODULE_ID");

const disconnect = new DisconnectParticipantActionBuilder("Disconnect").build();

const invokeAsanaModule = new InvokeFlowModuleActionBuilder("InvokeAsanaModule")
  .flowModuleId(ASANA_MODULE_ID)
  .next("Disconnect")
  .onError("Disconnect")
  .build();

// Flow logging is per-flow, not instance-wide -- even though
// /aws/connect/mini-connect is enabled at the instance level, a flow only
// actually emits log entries once a "Set logging behavior" block runs.
// Propagates forward into the invoked module for the rest of the contact
// segment (AWS-documented behavior).
const enableLogging = new UpdateFlowLoggingBehaviorActionBuilder(
  "EnableLogging",
)
  .enabled()
  .next("InvokeAsanaModule")
  .build();

const flow = new FlowBuilder("AsanaModuleTestWrapper")
  .startWith(enableLogging)
  .add(invokeAsanaModule)
  .add(disconnect)
  .build();

const definition = flow.toConnectDefinition();

const outputPath = process.env.FLOW_OUTPUT_PATH
  ? resolve(process.env.FLOW_OUTPUT_PATH)
  : resolve(dirname(fileURLToPath(import.meta.url)), "../module_test_wrapper.json");

writeFileSync(outputPath, JSON.stringify(definition, null, 2));
console.log(`Wrote ${outputPath}`);
