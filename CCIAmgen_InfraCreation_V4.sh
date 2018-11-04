#!/bin/bash
#############################################################################################
# AMGEN Call Center Insights - Infra Creation Script 									
# Creates the AWS infra  Inventory including IAM Roles and policies, S3, ECR, Lambdas,
# ApiGateways, Batches , Dynamodb , Cloudwatch Monitoring etc  for CCI Project using aws cli
# Please provide the required paramters and values for subnets, secutiry groups etc under the 
# Variables assignment section 	
# Authors :  rtaduri@amgen.com, cprakash@amgen.com, aatlygom@amgen.com
#############################################################################################

export PATH=/home/ubuntu/.local/bin:$PATH

# VARIABLES ASSIGNMENT 


if [ $ENVIRONMENT_CHOICE = "prod" ]
then
   echo "PRODCUTION"
   ENV_TYPE=""
else
    echo "NON-PRODUCTION"
    ENV_TYPE="-$ENVIRONMENT_CHOICE"
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text )
IAM_ROLE="cci-access-role$ENV_TYPE"
# Subnet Ids required for aws batch creation can be configured here,
# If more need to configured then you can add it at the repective json files
SUBNETID1="subnet-0db01c5bda3f5f19b"
SUBNETID2="subnet-026f6717e61b8382e"
SECURITYGROUPID="sg-06b4fc3210981a601"

# Provide the details for RDS here 
RDS_SECURITYGROUPID="sg-063348f4fedc3ba78"
RDS_SUBNETGROUP_NAME="default-vpc-0b842def9fb641d7c"
RDS_AVAILABILITYZONE="us-west-2b"
ECR_ACCOUNT="$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"


echo "########################################################################"
echo "#######   CREATION OF CCI INFRA FOR $ENV_TYPE ENVIRONMENT  #############"
echo "########################################################################"

echo "### CREATION OF IAM RESOURCES  ###"
echo "####  IAM  Role  creation ####"
aws iam create-role --role-name cci-access-role$ENV_TYPE --description "CCI access role for $ENVIRONMENT_CHOICE" --assume-role-policy-document file://$WORKSPACE/Jenkins-Build/cci_access_iamrole_trusted_relationships.json
sleep 5s
echo "### IAM Custom  Policy  creation and Attaching ###"

aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --role-name cci-access-role$ENV_TYPE
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonTranscribeFullAccess --role-name cci-access-role$ENV_TYPE
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/ComprehendFullAccess --role-name cci-access-role$ENV_TYPE
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSBatchFullAccess --role-name cci-access-role$ENV_TYPE
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSLambdaExecute --role-name cci-access-role$ENV_TYPE
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess --role-name cci-access-role$ENV_TYPE
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess --role-name cci-access-role$ENV_TYPE
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole --role-name cci-access-role$ENV_TYPE
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole --role-name cci-access-role$ENV_TYPE

sleep 30s
aws iam create-policy --policy-name cci-dynamodb-access-policy$ENV_TYPE --description "CCI DynamoDB fine grained access for $ENVIRONMENT_CHOICE" --policy-document file://$WORKSPACE/Jenkins-Build/CCI_Specific_Iam_policy.json
aws iam attach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/cci-dynamodb-access-policy$ENV_TYPE --role-name cci-access-role$ENV_TYPE
sleep 30s

echo "### CREATE s3 BUCKETS ###" 

aws s3 mb s3://cci-files-audio$ENV_TYPE
aws s3 mb s3://cci-files-comprehend$ENV_TYPE
aws s3 mb s3://cci-files-deid$ENV_TYPE
aws s3 mb s3://cci-files-temp$ENV_TYPE
aws s3 mb s3://cci-files-transcribe$ENV_TYPE
aws s3 mb s3://cci-misc$ENV_TYPE
sleep 20s

echo "### ATTACH BUCKET POLICIES"

sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cci-files-audio-s3bucketpolicy.json
aws s3api put-bucket-policy --bucket cci-files-audio$ENV_TYPE --policy file://$WORKSPACE/Jenkins-Build/cci-files-audio-s3bucketpolicy.json

sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cci-files-comprehend-s3bucketpolicy.json
aws s3api put-bucket-policy --bucket cci-files-comprehend$ENV_TYPE --policy file://$WORKSPACE/Jenkins-Build/cci-files-comprehend-s3bucketpolicy.json

sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cci-files-deid-s3bucketpolicy.json
aws s3api put-bucket-policy --bucket cci-files-deid$ENV_TYPE --policy file://$WORKSPACE/Jenkins-Build/cci-files-deid-s3bucketpolicy.json

sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cci-files-temp-s3bucketpolicy.json
aws s3api put-bucket-policy --bucket cci-files-temp$ENV_TYPE --policy file://$WORKSPACE/Jenkins-Build/cci-files-temp-s3bucketpolicy.json

sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cci-files-transcribe-s3bucketpolicy.json
aws s3api put-bucket-policy --bucket cci-files-transcribe$ENV_TYPE --policy file://$WORKSPACE/Jenkins-Build/cci-files-transcribe-s3bucketpolicy.json

echo "###### RDS CREATION #######"
echo "###### RDS db Cluster creation  #######"

#aws rds create-db-cluster \
#--db-cluster-identifier cci-db$ENV_TYPE \
#--engine aurora-mysql \
#--engine-version 5.7.12 \
#--master-username root \
#--master-user-password rootroot \
#--vpc-security-group-ids $RDS_SECURITYGROUPID \
#--storage-encrypted \
#--preferred-backup-window "10:43-11:13" \
#--db-subnet-group-name $RDS_SUBNETGROUP_NAME
#sleep 100s

#echo "###### RDS db instance creation  #######"
#aws rds create-db-instance \
#--db-instance-identifier cci-db$ENV_TYPE \
#--db-cluster-identifier cci-db$ENV_TYPE \
#--db-instance-class db.t2.small \
#--engine aurora-mysql \
#--monitoring-interval 60 \
#--availability-zone $RDS_AVAILABILITYZONE \
#--storage-type aurora \
#--monitoring-role-arn arn:aws:iam::$ACCOUNT_ID:role/$IAM_ROLE 

echo "#### CREATE ECR ###"

aws ecr create-repository --repository-name cci-comprehend$ENV_TYPE
aws ecr create-repository --repository-name cci-pipeline-driver$ENV_TYPE
aws ecr create-repository --repository-name cci-box-to-s3$ENV_TYPE

echo "### CREATE BATCH  ###"

#Replacing Variables for box to s3-Compute Environment
sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cci-crawl-compute.json
sed -i 's/SUBNETID1_TOBE_REPLACED/'$SUBNETID1'/g' $WORKSPACE/Jenkins-Build/cci-crawl-compute.json
sed -i 's/SUBNETID2_TOBE_REPLACED/'$SUBNETID2'/g' $WORKSPACE/Jenkins-Build/cci-crawl-compute.json
sed -i 's/SECURITYGROUPID_TOBE_REPLACED/'$SECURITYGROUPID'/g' $WORKSPACE/Jenkins-Build/cci-crawl-compute.json
sed -i 's/ACCOUNTID_TOBE_REPLACED/'$ACCOUNT_ID'/g' $WORKSPACE/Jenkins-Build/cci-crawl-compute.json

#Replacing Variables for comprehend-Compute Environment
sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cci-comprehend-compute.json
sed -i 's/SUBNETID1_TOBE_REPLACED/'$SUBNETID1'/g' $WORKSPACE/Jenkins-Build/cci-comprehend-compute.json
sed -i 's/SUBNETID2_TOBE_REPLACED/'$SUBNETID2'/g' $WORKSPACE/Jenkins-Build/cci-comprehend-compute.json
sed -i 's/SECURITYGROUPID_TOBE_REPLACED/'$SECURITYGROUPID'/g' $WORKSPACE/Jenkins-Build/cci-comprehend-compute.json
sed -i 's/ACCOUNTID_TOBE_REPLACED/'$ACCOUNT_ID'/g' $WORKSPACE/Jenkins-Build/cci-comprehend-compute.json

#Replacing Variables for pipeline driver-Compute Environment
sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cci-driver-compute.json
sed -i 's/SUBNETID1_TOBE_REPLACED/'$SUBNETID1'/g' $WORKSPACE/Jenkins-Build/cci-driver-compute.json 
sed -i 's/SUBNETID2_TOBE_REPLACED/'$SUBNETID2'/g' $WORKSPACE/Jenkins-Build/cci-driver-compute.json 
sed -i 's/SECURITYGROUPID_TOBE_REPLACED/'$SECURITYGROUPID'/g' $WORKSPACE/Jenkins-Build/cci-driver-compute.json 
sed -i 's/ACCOUNTID_TOBE_REPLACED/'$ACCOUNT_ID'/g' $WORKSPACE/Jenkins-Build/cci-driver-compute.json 
sleep 45s

echo "#### Create Batch - Compute Environment ####"
#Compute Environment for crawl
aws batch create-compute-environment --cli-input-json file://$WORKSPACE/Jenkins-Build/cci-crawl-compute.json
#Compute Environment for comprehend
aws batch create-compute-environment --cli-input-json file://$WORKSPACE/Jenkins-Build/cci-comprehend-compute.json
#Compute Environment for pipeline driver
aws batch create-compute-environment --cli-input-json file://$WORKSPACE/Jenkins-Build/cci-driver-compute.json 
#Delay 
sleep 30s

echo "#### Create Batch- Job Queues for box to s3 ####"
aws batch create-job-queue \
--job-queue-name cci-box-crawl-queue$ENV_TYPE \
--state ENABLED \
--priority 10 \
--compute-environment-order order=1,computeEnvironment=cci-crawl-compute$ENV_TYPE

echo "#### Create Batch- Job Queues for comprehend ###"
aws batch create-job-queue \
--job-queue-name cci-comprehend-queue$ENV_TYPE \
--state ENABLED \
--priority 10 \
--compute-environment-order order=1,computeEnvironment=cci-comprehend-compute$ENV_TYPE

echo "#### Create Batch- Job Queues for pipeline driver ####"
aws batch create-job-queue \
--job-queue-name cci-pipeline-driver-queue$ENV_TYPE \
--state ENABLED \
--priority 10 \
--compute-environment-order order=1,computeEnvironment=cci-driver-compute$ENV_TYPE

sleep 15s
echo "### REGISTERING JOB DEFINITION ###"
#aws batch register-job-definition --job-definition-name cci-box-crawl$ENV_TYPE --type container --container-properties '{ "image": "'$ECR_ACCOUNT'/cci-box-to-s3'$ENV_TYPE':latest", "vcpus": 2, "memory": 1000, "command": [ "sleep", "30"]}'
#aws batch register-job-definition --job-definition-name cci-pipeline-driver$ENV_TYPE --type container --container-properties '{ "image": "'$ECR_ACCOUNT'/cci-pipeline-driver'$ENV_TYPE':latest", "vcpus": 2, "memory": 1000, "command": [ "sleep", "30"]}'
#aws batch register-job-definition --job-definition-name cci-comprehend$ENV_TYPE --type container --container-properties '{ "image": "'$ECR_ACCOUNT'/cci-comprehend'$ENV_TYPE':latest", "vcpus": 2, "memory": 1000, "command": [ "sleep", "30"]}'
sleep 20s

echo "### LAMBDA CREATION ###"
echo "### Create lambda function for submit request ####"
aws lambda create-function \
--function-name submit-request-plain$ENV_TYPE \
--code S3Bucket=cci-lambda-sources,S3Key=sample_lambda.zip \
--role arn:aws:iam::$ACCOUNT_ID:role/$IAM_ROLE \
--handler submit_request_plain.lambda_handler \
--runtime python3.6 \
--timeout 300 \
--memory-size 1024

echo "### Create lambda function for de identify ###"
aws lambda create-function \
--function-name de-identify-plain$ENV_TYPE \
--code S3Bucket=cci-lambda-sources,S3Key=sample_lambda.zip \
--role arn:aws:iam::$ACCOUNT_ID:role/$IAM_ROLE \
--handler de_identify.lambda_handler \
--runtime python3.6 \
--timeout 300 \
--memory-size 1024
sleep 35s

echo "### Create lambda function for box-token-refresh ####"
aws lambda create-function \
--function-name box-token-refresh$ENV_TYPE \
--code S3Bucket=cci-lambda-sources,S3Key=sample_lambda.zip \
--role arn:aws:iam::$ACCOUNT_ID:role/$IAM_ROLE \
--handler box_token_refresh.lambda_handler \
--runtime python3.6 \
--timeout 300 \
--memory-size 1024

#Obtaining ARN of box-token-refresh lambda function
BOX_TOKEN_REFRESH_LAMBDA_ARN=$(aws lambda list-functions --query "Functions[?FunctionName==\`box-token-refresh$ENV_TYPE\`].FunctionArn" --output text )

#Creating Cloudwatch Scheduled event rule
aws events put-rule \
--name cci-box-token-refresh$ENV_TYPE \
--schedule-expression 'cron(0 9 1 * ? *)'
#Obtaining ARN of Scheduled event rule
SCHEDULED_EVENT_ARN=$(aws events list-rules --query "Rules[?Name==\`cci-box-token-refresh$ENV_TYPE\`].Arn" --output text )
echo $SCHEDULED_EVENT_ARN
#Adding permission to trigger box token refresh lambda
aws lambda add-permission \
--function-name box-token-refresh$ENV_TYPE \
--statement-id cci-scheduled-event$ENVIRONMENT_CHOICE \
--action 'lambda:InvokeFunction' \
--principal events.amazonaws.com \
--source-arn $SCHEDULED_EVENT_ARN
#Setting target for rule
aws events put-targets \
--rule cci-box-token-refresh$ENV_TYPE \
--targets "Id"="1","Arn"=$BOX_TOKEN_REFRESH_LAMBDA_ARN


echo "### API GATEWAY CREATION ###"
echo "#### API Gateway configuration for submit request ####"
#Getting submit request lambda function
SUBMIT_REQUEST_LAMBDA_ARN=$(aws lambda list-functions --query "Functions[?FunctionName==\`submit-request-plain$ENV_TYPE\`].FunctionArn" --output text )
#Create API Gateway for submit request
SUBMIT_REQUEST_API_ID=$(aws apigateway get-rest-apis --query "items[?name==\`submit-request-plain$ENV_TYPE\`].id" --output text)

# API Gateway existance check to avoid duplicate 
if [ -z "$SUBMIT_REQUEST_API_ID" ]
then
      echo "CREATING SUBMIT REQUEST"
      aws apigateway create-rest-api --name submit-request-plain$ENV_TYPE --description "Api for submit request"
else
      echo "SKIPPING THE API GATEWAY CREATION AS SUBMIT REQUEST AAPI ALREADY EXISTS"
fi

#Getting API ID for submit request API Gateway
SUBMIT_REQUEST_API_ID=$(aws apigateway get-rest-apis --query "items[?name==\`submit-request-plain$ENV_TYPE\`].id" --output text)
#Getting Resource id for submit request
SUBMIT_REQUEST_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id ${SUBMIT_REQUEST_API_ID} --query "items[0].id" --output text)
sleep 35s
echo "### Creating POST method for submit request ###"
aws apigateway put-method \
--rest-api-id ${SUBMIT_REQUEST_API_ID} \
--resource-id ${SUBMIT_REQUEST_RESOURCE_ID} \
--http-method POST \
--request-parameters "method.request.header.api_key=true" \
--authorization-type NONE
sleep 35s
echo "###  Configuring POST method for submit request ###"
aws apigateway put-integration \
--rest-api-id ${SUBMIT_REQUEST_API_ID} \
--resource-id ${SUBMIT_REQUEST_RESOURCE_ID} \
--http-method POST \
--type AWS_PROXY \
--integration-http-method POST \
--uri arn:aws:apigateway:$AWS_DEFAULT_REGION:lambda:path/2015-03-31/functions/${SUBMIT_REQUEST_LAMBDA_ARN}/invocations
sleep 45s
echo "###  Configuring POST method response ###"
aws apigateway put-method-response \
--rest-api-id ${SUBMIT_REQUEST_API_ID} \
--resource-id ${SUBMIT_REQUEST_RESOURCE_ID} \
--http-method POST \
--status-code 200 \
--response-models '{"application/json":"Empty"}'
sleep 35s
echo "###  Deploying API Gateway ###"
aws apigateway create-deployment \
--rest-api-id ${SUBMIT_REQUEST_API_ID} \
--stage-name $ENVIRONMENT_CHOICE
sleep 35s
echo "###  Setting Trigger ###"
SUBMIT_REQUEST_API_ARN=$(echo ${SUBMIT_REQUEST_LAMBDA_ARN} | sed -e 's/lambda/execute-api/' -e "s/function:submit-request-plain$ENV_TYPE/${SUBMIT_REQUEST_API_ID}/")

echo "###  Adding Permission ###"
aws lambda add-permission \
--function-name submit-request-plain$ENV_TYPE \
--statement-id cci-apigateway$ENVIRONMENT_CHOICE \
--action lambda:InvokeFunction \
--principal apigateway.amazonaws.com \
--source-arn "${SUBMIT_REQUEST_API_ARN}/*/POST/"
sleep 45s

echo "### API Gateway configuration for de-identify ###"

echo "### Getting de-identify lambda function ###"
DE_IDENTIFY_LAMBDA_ARN=$(aws lambda list-functions --query "Functions[?FunctionName==\`de-identify-plain$ENV_TYPE\`].FunctionArn" --output text )
echo $DE_IDENTIFY_LAMBDA_ARN

echo "### Create API Gateway for de-identify ####"
DE_IDENTIFY_API_ID=$(aws apigateway get-rest-apis --query "items[?name==\`de-identify-plain$ENV_TYPE\`].id" --output text)
if [ -z "$DE_IDENTIFY_API_ID" ]
then
      echo "CREATING DE_IDENTIFY_API"
      aws apigateway create-rest-api --name de-identify-plain$ENV_TYPE --description "Api for de-identify"
else
      echo "SKIPPING THE API GATEWAY CREATION AS DE_IDENTIFY_API  ALREADY EXISTS"
fi

#Getting API ID for de-identify API Gateway
DE_IDENTIFY_API_ID=$(aws apigateway get-rest-apis --query "items[?name==\`de-identify-plain$ENV_TYPE\`].id" --output text)
#Getting Resource id for de-identify
DE_IDENTIFY_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id ${DE_IDENTIFY_API_ID} --query "items[0].id" --output text)
sleep 35s

echo "###  Creating POST method for submit request ###"
aws apigateway put-method \
--rest-api-id ${DE_IDENTIFY_API_ID} \
--resource-id ${DE_IDENTIFY_RESOURCE_ID} \
--http-method POST \
--request-parameters "method.request.header.api_key=true" \
--authorization-type NONE
sleep 35s
echo "###  Configuring POST method for submit request DE_IDENTIFY_API_ID ###"
aws apigateway put-integration \
--rest-api-id ${DE_IDENTIFY_API_ID} \
--resource-id ${DE_IDENTIFY_RESOURCE_ID} \
--http-method POST \
--type AWS_PROXY \
--integration-http-method POST \
--uri arn:aws:apigateway:$AWS_DEFAULT_REGION:lambda:path/2015-03-31/functions/${DE_IDENTIFY_LAMBDA_ARN}/invocations
sleep 35s

echo "###  Configuring POST method response DE_IDENTIFY_API_ID ###"
aws apigateway put-method-response \
--rest-api-id ${DE_IDENTIFY_API_ID} \
--resource-id ${DE_IDENTIFY_RESOURCE_ID} \
--http-method POST \
--status-code 200 \
--response-models '{"application/json":"Empty"}'
sleep 35s


echo "### Deploying API Gateway DE_IDENTIFY_API ###"
aws apigateway create-deployment \
--rest-api-id ${DE_IDENTIFY_API_ID} \
--stage-name $ENVIRONMENT_CHOICE
echo "###  Setting Trigger###"
DE_IDENTIFY_API_ARN=$(echo ${DE_IDENTIFY_LAMBDA_ARN} | sed -e 's/lambda/execute-api/' -e "s/function:de-identify-plain$ENV_TYPE/${DE_IDENTIFY_API_ID}/")
echo "### #Adding Permission ###"
aws lambda add-permission \
--function-name de-identify-plain$ENV_TYPE \
--statement-id cci-apigateway$ENVIRONMENT_CHOICE \
--action lambda:InvokeFunction \
--principal apigateway.amazonaws.com \
--source-arn "${DE_IDENTIFY_API_ARN}/*/POST/"

echo "#### DYNAMO DB CREATION ####"
echo "### Create Dynamo DB table for box authentication ###"
aws dynamodb create-table \
--table-name cci-box-auth$ENV_TYPE \
--attribute-definitions AttributeName=id,AttributeType=S \
--key-schema AttributeName=id,KeyType=HASH \
--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
sleep 15s

echo "#### Generating a temp json file with values to put in dynamodb cci-box-auth credentials  ###"
#echo "{	\"id\": {\"S\": \"$BOX_AUTH_ID\"},\"access_token\": {\"S\": \"$BOX_AUTH_ACCESS_TOKEN\"	},	\"refresh_token\": {		\"S\": \"$BOX_AUTH_REFRESH_TOKEN\"	}}" > box_auth_data.json 
aws dynamodb put-item --table-name cci-box-auth$ENV_TYPE --item file://$WORKSPACE/box_auth_data.json
rm -rf $WORKSPACE/box_auth_data.json

echo "### Create Dynamo DB table for requests ####"
aws dynamodb create-table \
--table-name cci-requests$ENV_TYPE \
--attribute-definitions AttributeName=request_id,AttributeType=S \
--key-schema AttributeName=request_id,KeyType=HASH \
--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

echo "###  Create Dynamo DB table for item queue ###"
aws dynamodb create-table \
--table-name cci-item-queue$ENV_TYPE \
--attribute-definitions AttributeName=request_id,AttributeType=S AttributeName=document_id,AttributeType=S \
--key-schema AttributeName=request_id,KeyType=HASH AttributeName=document_id,KeyType=RANGE \
--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
--global-secondary-indexes IndexName=document-id-index,KeySchema=["{AttributeName=document_id,KeyType=HASH}"],Projection="{ProjectionType=ALL}",ProvisionedThroughput="{ReadCapacityUnits=5,WriteCapacityUnits=5}"

echo "#### Autoscaling DynamoDB table ####"
aws application-autoscaling register-scalable-target \
    --service-namespace dynamodb \
    --resource-id "table/cci-item-queue$ENV_TYPE" \
    --scalable-dimension "dynamodb:table:ReadCapacityUnits" \
    --min-capacity 5 \
    --max-capacity 500
aws application-autoscaling register-scalable-target \
    --service-namespace dynamodb \
    --resource-id "table/cci-item-queue$ENV_TYPE" \
    --scalable-dimension "dynamodb:table:WriteCapacityUnits" \
    --min-capacity 5 \
    --max-capacity 500
echo "#### Registering DynamoDB table autoscaling policy ####"
aws application-autoscaling put-scaling-policy \
    --service-namespace dynamodb \
    --resource-id "table/cci-item-queue$ENV_TYPE" \
    --scalable-dimension "dynamodb:table:ReadCapacityUnits" \
    --policy-name "AmgenScalingPolicy" \
    --policy-type "TargetTrackingScaling" \
    --target-tracking-scaling-policy-configuration PredefinedMetricSpecification={PredefinedMetricType=DynamoDBReadCapacityUtilization},ScaleOutCooldown=60,ScaleInCooldown=60,TargetValue=50
echo "####  Autoscaling DynamoDB global secondary index ###"
aws application-autoscaling register-scalable-target \
    --service-namespace dynamodb \
    --resource-id "table/cci-item-queue$ENV_TYPE/index/document-id-index" \
    --scalable-dimension "dynamodb:index:ReadCapacityUnits" \
    --min-capacity 5 \
    --max-capacity 500
aws application-autoscaling register-scalable-target \
    --service-namespace dynamodb \
    --resource-id "table/cci-item-queue$ENV_TYPE/index/document-id-index" \
    --scalable-dimension "dynamodb:index:WriteCapacityUnits" \
    --min-capacity 5 \
    --max-capacity 500
echo "#### #Registering DynamoDB global secondary index autoscaling policy ###"
aws application-autoscaling put-scaling-policy \
    --service-namespace dynamodb \
    --resource-id "table/cci-item-queue$ENV_TYPE/index/document-id-index" \
    --scalable-dimension "dynamodb:index:ReadCapacityUnits" \
    --policy-name "AmgenScalingPolicy" \
    --policy-type "TargetTrackingScaling" \
    --target-tracking-scaling-policy-configuration PredefinedMetricSpecification={PredefinedMetricType=DynamoDBReadCapacityUtilization},ScaleOutCooldown=60,ScaleInCooldown=60,TargetValue=50
    
    echo "## CLOUDWATCH MONITORING ##"
    sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cloudwatch_DBdashboard.json
#sed -i 's/region/'$AWS_DEFAULT_REGION'/g' $WORKSPACE/Jenkins-Build/cloudwatch_DBdashboard.json

aws cloudwatch put-dashboard \
--dashboard-name "CCI_DB_Monitoring$ENV_TYPE" \
--dashboard-body file://$WORKSPACE/Jenkins-Build/cloudwatch_DBdashboard.json

sed -i 's/envtype/'$ENV_TYPE'/g' $WORKSPACE/Jenkins-Build/cloudwatch_dashboard.json
#sed -i 's/region/'$AWS_DEFAULT_REGION'/g' $WORKSPACE/Jenkins-Build/cloudwatch_dashboard.json
aws cloudwatch put-dashboard \
--dashboard-name "CCI_Monitoring$ENV_TYPE" \
--dashboard-body file://$WORKSPACE/Jenkins-Build/cloudwatch_dashboard.json
