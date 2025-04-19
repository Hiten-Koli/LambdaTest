import json
import base64
import boto3
import traceback

s3 = boto3.client(
    "s3",
    endpoint_url="http://host.docker.internal:4566",
    aws_access_key_id="test",
    aws_secret_access_key="test",
    region_name="us-east-1",
)

def lambda_handler(event, context):
    try:
        print("Received event:", json.dumps(event))
        key = event.get("key")
        body = event.get("body", "")
        if event.get("isBase64Encoded", False):
            file_content = base64.b64decode(body).decode('utf-8')
        else:
            file_content = body
        
        print("Decoded file content:")
        print(file_content)

        # Upload to S3
        s3.put_object(
            Bucket="my-upload-bucket",  
            Key=key,         # Can be made dynamic
            Body=file_content
        )

        return {
            'statusCode': 200,
            'body': 'File received and uploaded to S3.'
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': 'Error processing file.'
        }
