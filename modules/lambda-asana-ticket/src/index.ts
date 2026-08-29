import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";

const ASANA_API_BASE = "https://app.asana.com/api/1.0";
const secretsClient = new SecretsManagerClient({});

interface ConnectLambdaEvent {
  Details?: {
    Parameters?: {
      IssueDescription?: string;
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
  const issueDescription = event.Details?.Parameters?.IssueDescription;

  if (!issueDescription) {
    throw new Error("Missing required parameter: IssueDescription");
  }

  const projectGid = process.env.ASANA_PROJECT_GID;
  if (!projectGid) {
    throw new Error(
      "Missing required environment configuration: ASANA_PROJECT_GID",
    );
  }

  const apiToken = await getAsanaApiToken;

  const response = await fetch(`${ASANA_API_BASE}/tasks`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      data: {
        name: `Self-service ticket: ${issueDescription.slice(0, 80)}`,
        notes: issueDescription,
        projects: [projectGid],
      },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Asana API error (${response.status}): ${errorBody}`);
  }

  const result = (await response.json()) as AsanaCreateTaskResponse;

  return {
    caseNumber: result.data.gid,
  };
};
