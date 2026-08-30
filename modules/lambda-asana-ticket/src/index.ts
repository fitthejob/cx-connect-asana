import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";
import {
  DynamoDBClient,
} from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  PutCommand,
} from "@aws-sdk/lib-dynamodb";

const ASANA_API_BASE = "https://app.asana.com/api/1.0";
const CORRELATION_TTL_SECONDS = 48 * 60 * 60;
const secretsClient = new SecretsManagerClient({});
const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

interface ConnectLambdaEvent {
  Details?: {
    ContactData?: {
      ContactId?: string;
    };
    Parameters?: {
      CustomerId?: string;
      CallerAni?: string;
    };
  };
}

interface AsanaCreateTaskResponse {
  data: {
    gid: string;
  };
}

async function getAsanaApiToken(): Promise<string> {
  const secretArn = process.env.ASANA_SECRET_ARN;
  if (!secretArn) {
    throw new Error(
      "Missing required environment configuration: ASANA_SECRET_ARN",
    );
  }
  const result = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: secretArn }),
  );
  if (!result.SecretString) {
    throw new Error("Asana API token secret has no string value");
  }
  return result.SecretString;
}

export const handler = async (event: ConnectLambdaEvent) => {
  const contactId = event.Details?.ContactData?.ContactId;
  const customerId = event.Details?.Parameters?.CustomerId;
  const callerAni = event.Details?.Parameters?.CallerAni;

  if (!contactId) {
    throw new Error("Missing required field: Details.ContactData.ContactId");
  }

  const projectGid = process.env.ASANA_PROJECT_GID;
  if (!projectGid) {
    throw new Error(
      "Missing required environment configuration: ASANA_PROJECT_GID",
    );
  }

  const correlationTableName = process.env.CORRELATION_TABLE_NAME;
  if (!correlationTableName) {
    throw new Error(
      "Missing required environment configuration: CORRELATION_TABLE_NAME",
    );
  }

  const apiToken = await getAsanaApiToken();

  const notesLines = ["Transcription pending..."];
  if (customerId) {
    notesLines.push(`Customer ID: ${customerId}`);
  }
  if (callerAni) {
    notesLines.push(`Caller ANI: ${callerAni}`);
  }

  const response = await fetch(`${ASANA_API_BASE}/tasks`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      data: {
        name: `Self-service ticket: ${customerId ?? contactId}`,
        notes: notesLines.join("\n"),
        projects: [projectGid],
      },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Asana API error (${response.status}): ${errorBody}`);
  }

  const result = (await response.json()) as AsanaCreateTaskResponse;
  const taskGid = result.data.gid;

  await ddbClient.send(
    new PutCommand({
      TableName: correlationTableName,
      Item: {
        contactId,
        asanaTaskGid: taskGid,
        expiresAt: Math.floor(Date.now() / 1000) + CORRELATION_TTL_SECONDS,
        ...(customerId ? { customerId } : {}),
        ...(callerAni ? { callerAni } : {}),
      },
    }),
  );

  return {
    caseNumber: taskGid,
  };
};
