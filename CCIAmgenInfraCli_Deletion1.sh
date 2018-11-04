export PATH=/home/ubuntu/.local/bin:$PATH
export AWS_DEFAULT_REGION="us-west-2"

# Variables value Assignmnet
ENV_TYPE="ENVIRONMENT_TOBE_SUBSTITUED"
ACCOUNT_ID="600405393286"

echo "### INFRA DELETION ###"

echo "### S3 BUCKETS ###"
aws s3api delete-bucket --bucket cci-files-audio-$ENV_TYPE --region us-west-2
aws s3api delete-bucket --bucket cci-files-comprehend-$ENV_TYPE  --region us-west-2
aws s3api delete-bucket --bucket cci-files-deid-$ENV_TYPE --region us-west-2
aws s3api delete-bucket --bucket cci-files-temp-$ENV_TYPE --region us-west-2
aws s3api delete-bucket --bucket cci-files-transcribe-$ENV_TYPE --region us-west-2


echo "###  DISABLING JOB QUEUES ###"
aws batch update-job-queue --job-queue cci-box-to-s3-queue-$ENV_TYPE --state DISABLED
aws batch update-job-queue --job-queue cci-comprehend-queue-$ENV_TYPE --state DISABLED
aws batch update-job-queue --job-queue cci-pipeline-driver-queue-$ENV_TYPE --state DISABLED


echo "### DISABLING JOB COMPUTE ENVIRONMENT ###"
aws batch update-compute-environment --compute-environment cci-crawl-compute-$ENV_TYPE --state DISABLED
aws batch update-compute-environment --compute-environment cci-comprehend-compute-$ENV_TYPE --state DISABLED
aws batch update-compute-environment --compute-environment cci-driver-compute-$ENV_TYPE --state DISABLED
sleep 60s


echo "### JOB QUEUES ###"
aws batch delete-job-queue --job-queue cci-box-to-s3-queue-$ENV_TYPE
aws batch delete-job-queue --job-queue cci-comprehend-queue-$ENV_TYPE
aws batch delete-job-queue --job-queue cci-pipeline-driver-queue-$ENV_TYPE
sleep 10s

echo "###  ECR ###"
aws ecr delete-repository --repository-name cci-comprehend-$ENV_TYPE
aws ecr delete-repository --repository-name cci-box-to-s3-$ENV_TYPE
aws ecr delete-repository --repository-name cci-pipeline-driver-$ENV_TYPE
sleep 30s


echo "###  LAMBDAS ###"
aws lambda delete-function --function-name submit-request-plain-$ENV_TYPE 
aws lambda delete-function --function-name de-identify-plain-$ENV_TYPE


echo "### BATCHES ###"
sleep 60s
aws batch delete-compute-environment --compute-environment cci-crawl-compute-$ENV_TYPE
aws batch delete-compute-environment --compute-environment cci-comprehend-compute-$ENV_TYPE
aws batch delete-compute-environment --compute-environment cci-driver-compute-$ENV_TYPE


echo "###  REST APIS ###" 
echo "### submit request api ###" 
SUBMIT_REQUEST_API_ID=$(aws apigateway get-rest-apis --query "items[?name==\`submit-request-plain-$ENV_TYPE\`].id" --output text)
echo $SUBMIT_REQUEST_API_ID
aws apigateway delete-rest-api --rest-api-id $SUBMIT_REQUEST_API_ID
sleep 60s
echo "###  de identify api ###"
DE_IDENTIFY_API_ID=$(aws apigateway get-rest-apis --query "items[?name==\`de-identify-plain-$ENV_TYPE\`].id" --output text)
aws apigateway delete-rest-api --rest-api-id $DE_IDENTIFY_API_ID 


echo "### DELETE DYNAMO DB TABLE ###"
aws dynamodb delete-table --table-name  cci-box-auth-$ENV_TYPE
aws dynamodb delete-table --table-name  cci-requests-$ENV_TYPE
aws dynamodb delete-table --table-name  cci-item-queue-$ENV_TYPE
sleep 60s

echo "### IAM POLICY DETACHING  ###"
aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --role-name Cci_Access_Role_$ENV_TYPE
aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonTranscribeFullAccess --role-name Cci_Access_Role_$ENV_TYPE
aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/ComprehendFullAccess --role-name Cci_Access_Role_$ENV_TYPE
aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSBatchFullAccess --role-name Cci_Access_Role_$ENV_TYPE
aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSLambdaExecute --role-name Cci_Access_Role_$ENV_TYPE
aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole --role-name Cci_Access_Role_$ENV_TYPE
aws iam detach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/Cci_Access_IamPolicy_$ENV_TYPE --role-name Cci_Access_Role_$ENV_TYPE

echo "### IAM POLICY ###"
sleep 60s
aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/Cci_Access_IamPolicy_$ENV_TYPE

echo "### IAM ROLE ###"
sleep 60s
aws iam delete-role --role-name Cci_Access_Role_$ENV_TYPE
sleep 60s
 echo "END OF DELETION"
