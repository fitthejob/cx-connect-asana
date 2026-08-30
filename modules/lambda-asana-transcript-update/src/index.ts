import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";
import {
  DynamoDBClient,
} from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
} from "@aws-sdk/lib-dynamodb";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";

const ASANA_API_BASE = "https://app.asana.com/api/1.0";
const TRANSCRIPTION_JOB_NAME_PREFIX = "asana-";

const secretsClient = new SecretsManagerClient({});
const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const s3Client = new S3Client({});

interface TranscribeEventBridgeEvent {
  source: string;
  "detail-type": string;
  detail: {
    TranscriptionJobName: string;
    TranscriptionJobStatus: "COMPLETED" | "FAILED";
  };
}

interface TranscribeOutput {
  results: {
    transcripts: Array<{ transcript: string }>;
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

async function readS3BodyAsString(
  bucket: string,
  key: string,
): Promise<string> {
  const result = await s3Client.send(
    new GetObjectCommand({ Bucket: bucket, Key: key }),
  );
  const body = await result.Body?.transformToString();
  if (!body) {
    throw new Error(`Empty object body for s3://${bucket}/${key}`);
  }
  return body;
}

export const handler = async (event: TranscribeEventBridgeEvent) => {
  if (event.detail.TranscriptionJobStatus !== "COMPLETED") {
    return;
  }

  const jobName = event.detail.TranscriptionJobName;
  if (!jobName.startsWith(TRANSCRIPTION_JOB_NAME_PREFIX)) {
    return;
  }
  const contactId = jobName.slice(TRANSCRIPTION_JOB_NAME_PREFIX.length);

  const correlationTableName = process.env.CORRELATION_TABLE_NAME;
  if (!correlationTableName) {
    throw new Error(
      "Missing required environment configuration: CORRELATION_TABLE_NAME",
    );
  }

  const recordingBucketName = process.env.RECORDING_BUCKET_NAME;
  if (!recordingBucketName) {
    throw new Error(
      "Missing required environment configuration: RECORDING_BUCKET_NAME",
    );
  }

  const correlation = await ddbClient.send(
    new GetCommand({
      TableName: correlationTableName,
      Key: { contactId },
    }),
  );

  if (!correlation.Item) {
    throw new Error(`No correlation record found for contactId: ${contactId}`);
  }

  const asanaTaskGid = correlation.Item.asanaTaskGid as string;
  const customerId = correlation.Item.customerId as string | undefined;
  const callerAni = correlation.Item.callerAni as string | undefined;

  const transcriptOutputKey = `transcripts/${contactId}.json`;
  const transcriptBody = await readS3BodyAsString(
    recordingBucketName,
    transcriptOutputKey,
  );
  const transcriptOutput = JSON.parse(transcriptBody) as TranscribeOutput;
  const transcriptText =
    transcriptOutput.results.transcripts[0]?.transcript ?? "";

  const notesLines = [transcriptText];
  if (customerId) {
    notesLines.push(`Customer ID: ${customerId}`);
  }
  if (callerAni) {
    notesLines.push(`Caller ANI: ${callerAni}`);
  }

  const apiToken = await getAsanaApiToken();

  const response = await fetch(`${ASANA_API_BASE}/tasks/${asanaTaskGid}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${apiToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      data: {
        notes: notesLines.join("\n\n"),
      },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Asana API error (${response.status}): ${errorBody}`);
  }
};
