import {
  DynamoDBClient,
} from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
} from "@aws-sdk/lib-dynamodb";
import {
  TranscribeClient,
  StartTranscriptionJobCommand,
} from "@aws-sdk/client-transcribe";

const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const transcribeClient = new TranscribeClient({});

const CONTACT_ID_PATTERN =
  /([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i;

interface S3Event {
  Records: Array<{
    s3: {
      bucket: { name: string };
      object: { key: string };
    };
  }>;
}

function extractContactId(objectKey: string): string {
  const basename = objectKey.split("/").pop() ?? "";
  const match = basename.match(CONTACT_ID_PATTERN);
  if (!match) {
    throw new Error(`Could not extract contactId from object key: ${objectKey}`);
  }
  return match[1];
}

export const handler = async (event: S3Event) => {
  const correlationTableName = process.env.CORRELATION_TABLE_NAME;
  if (!correlationTableName) {
    throw new Error(
      "Missing required environment configuration: CORRELATION_TABLE_NAME",
    );
  }

  const transcribeOutputBucket = process.env.RECORDING_BUCKET_NAME;
  if (!transcribeOutputBucket) {
    throw new Error(
      "Missing required environment configuration: RECORDING_BUCKET_NAME",
    );
  }

  for (const record of event.Records) {
    const bucketName = record.s3.bucket.name;
    const objectKey = decodeURIComponent(
      record.s3.object.key.replace(/\+/g, " "),
    );

    const contactId = extractContactId(objectKey);

    const correlation = await ddbClient.send(
      new GetCommand({
        TableName: correlationTableName,
        Key: { contactId },
      }),
    );

    if (!correlation.Item) {
      throw new Error(
        `No correlation record found for contactId: ${contactId}`,
      );
    }

    const asanaTaskGid = correlation.Item.asanaTaskGid as string;

    await transcribeClient.send(
      new StartTranscriptionJobCommand({
        TranscriptionJobName: `asana-${contactId}`,
        LanguageCode: "en-US",
        MediaFormat: "wav",
        Media: {
          MediaFileUri: `s3://${bucketName}/${objectKey}`,
        },
        OutputBucketName: transcribeOutputBucket,
        OutputKey: `transcripts/${contactId}.json`,
        Tags: [
          { Key: "contactId", Value: contactId },
          { Key: "asanaTaskGid", Value: asanaTaskGid },
        ],
      }),
    );
  }
};
