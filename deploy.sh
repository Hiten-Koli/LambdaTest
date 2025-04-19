#!/bin/bash

# Variables
ENDPOINT="http://localhost:4566"
BUCKET="my-upload-bucket"
ZIPFILE="function.zip"
FUNCTION_NAME="UploadToS3Function"
REGION="us-east-1"

# Step 1: Zip Lambda
cd lambda && zip -r ../$ZIPFILE . && cd ..

# Step 2: Create S3 Bucket
aws --endpoint-url=$ENDPOINT s3 mb s3://$BUCKET

# Step 3: Create Lambda Function
aws --endpoint-url=$ENDPOINT lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.11 \
  --handler handler.lambda_handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file fileb://$ZIPFILE

# Step 4: Create REST API
REST_API_ID=$(aws --endpoint-url=$ENDPOINT apigateway create-rest-api \
  --name "S3UploaderAPI" \
  --query 'id' --output text)

# Step 5: Get root resource ID
PARENT_ID=$(aws --endpoint-url=$ENDPOINT apigateway get-resources \
  --rest-api-id $REST_API_ID \
  --query 'items[0].id' --output text)

# Step 6: Create /upload resource
RESOURCE_ID=$(aws --endpoint-url=$ENDPOINT apigateway create-resource \
  --rest-api-id $REST_API_ID \
  --parent-id $PARENT_ID \
  --path-part upload \
  --query 'id' --output text)

# Step 7: Add POST method to /upload
aws --endpoint-url=$ENDPOINT apigateway put-method \
  --rest-api-id $REST_API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --authorization-type "NONE"

# Step 8: Integrate Lambda with /upload POST
aws --endpoint-url=$ENDPOINT apigateway put-integration \
  --rest-api-id $REST_API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:000000000000:function:$FUNCTION_NAME/invocations

# Step 9: Grant API Gateway permission to invoke Lambda
aws --endpoint-url=$ENDPOINT lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id apigateway-test-2 \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn arn:aws:execute-api:$REGION:000000000000:$REST_API_ID/*/POST/upload

# Step 10: Deploy the API
aws --endpoint-url=$ENDPOINT apigateway create-deployment \
  --rest-api-id $REST_API_ID \
  --stage-name dev

# Step 11: Print API URL
echo "✅ API endpoint:"
echo "$ENDPOINT/restapis/$REST_API_ID/dev/_user_request_/upload"
