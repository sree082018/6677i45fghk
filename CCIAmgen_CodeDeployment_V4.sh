#!/bin/bash

#########################################################################################
## AMGEN Call Center Insights - Code Deployment Script 									#
# Creates and deploys the docker images for batches from the latest code from gitlab and#
# also bundles the latest code for lambdas functions and updates them using aws cli		#
## Authors : rtaduri@amgen.com, cprakash@amgen.com, aatlygom@amgen.com 					#
#########################################################################################

export PATH=/home/ubuntu/.local/bin:$PATH

# VARIABLES ASSIGNMENT 
# Environment check
if [ $ENVIRONMENT_CHOICE = "prod" ]
then
   echo "PRODCUTION"
   ENV_TYPE=""
else
    echo "NON-PRODUCTION"
    ENV_TYPE="-$ENVIRONMENT_CHOICE"
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text )
ECR_ACCOUNT="$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"

# Getting the latest Revisions of Job definitions
BOX_CRAWL_JOB_DEFINITION_REVISION=$(aws batch describe-job-definitions --status ACTIVE --query "jobDefinitions[?jobDefinitionName==\`cci-box-crawl$ENV_TYPE\`].revision"  |jq 'max_by(.)')
echo $BOX_CRAWL_JOB_DEFINITION_REVISION
COMPREHEND_JOB_DEFINITION_REVISION=$(aws batch describe-job-definitions --status ACTIVE --query "jobDefinitions[?jobDefinitionName==\`cci-comprehend$ENV_TYPE\`].revision" |jq 'max_by(.)')
echo $COMPREHEND_JOB_DEFINITION_REVISION
PIPE_DRIVER_JOB_DEFINITION_REVISION=$(aws batch describe-job-definitions --status ACTIVE --query "jobDefinitions[?jobDefinitionName==\`cci-pipeline-driver$ENV_TYPE\`].revision" |jq 'max_by(.)')
echo $PIPE_DRIVER_JOB_DEFINITION_REVISION


#Transferring files from gitlab to s3 bucket
aws s3 cp $WORKSPACE/cci-misc-files/products.txt s3://cci-misc$ENV_TYPE/products.txt
aws s3 cp $WORKSPACE/cci-misc-files/reserved_words.txt s3://cci-misc$ENV_TYPE/reserved_words.txt

#Saving AWS ECR login credentials
sudo chmod -R 775 $WORKSPACE
AWS_ECR_LOGIN_DOCKER="aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION"
${AWS_ECR_LOGIN_DOCKER} > credentilas.sh
sh  credentilas.sh
sudo apt-get install zip -y

# Cleaning the docker images specific to the environment from jenkins job
docker rmi --force $ECR_ACCOUNT/cci-box-to-s3$ENV_TYPE:latest
docker rmi --force $ECR_ACCOUNT/cci-pipeline-driver$ENV_TYPE:latest
docker rmi --force $ECR_ACCOUNT/cci-comprehend$ENV_TYPE:latest

echo "update box to s3 docker image"
#Configuring environmental variable for box to s3
cd $WORKSPACE/box_to_s3
cp "$CCIEnv" $WORKSPACE/box_to_s3/.env
echo "\nS3_BUCKET='cci-files-audio$ENV_TYPE'" >> $WORKSPACE/box_to_s3/.env
echo "BOX_AUTH_TABLE='cci-box-auth$ENV_TYPE'" >> $WORKSPACE/box_to_s3/.env
echo "QUEUE_TABLE='cci-item-queue$ENV_TYPE'" >> $WORKSPACE/box_to_s3/.env
echo "REQ_TABLE='cci-requests$ENV_TYPE'" >> $WORKSPACE/box_to_s3/.env
echo "DRIVER_JOB_QUEUE='cci-pipeline-driver-queue$ENV_TYPE'" >> $WORKSPACE/box_to_s3/.env
echo "DRIVER_JOB_DEFINITION='cci-pipeline-driver$ENV_TYPE:$PIPE_DRIVER_JOB_DEFINITION_REVISION'" >> $WORKSPACE/box_to_s3/.env
cat $WORKSPACE/box_to_s3/.env  
cp $WORKSPACE/mail_helper/send_email.py $WORKSPACE/box_to_s3/utils/send_email.py
#Buiding docker image for box to s3
sudo docker build -t  cci-box-to-s3$ENV_TYPE:latest .
#Tagging docker image for box to s3
sudo docker tag cci-box-to-s3$ENV_TYPE:latest $ECR_ACCOUNT/cci-box-to-s3$ENV_TYPE:latest
#Pushing docker image for box to s3
docker push $ECR_ACCOUNT/cci-box-to-s3$ENV_TYPE:latest


echo "update pipeline driver docker image"
#Configuring environmental variable for pipeline driver
cd $WORKSPACE/pipeline_driver
cp "$CCIEnv" $WORKSPACE/pipeline_driver/.env
echo "\nS3_BUCKET='test-patient-voice'" >> $WORKSPACE/pipeline_driver/.env
echo "COMPREHEND_JOB_DEFINITION='cci-comprehend$ENV_TYPE:$COMPREHEND_JOB_DEFINITION_REVISION'" >> $WORKSPACE/pipeline_driver/.env
echo "COMPREHEND_QUEUE='cci-comprehend-queue$ENV_TYPE'" >> $WORKSPACE/pipeline_driver/.env
echo "DYNAMODB_TABLE='cci-item-queue$ENV_TYPE'" >> $WORKSPACE/pipeline_driver/.env
echo "S3_TRANSCRIBE_BKT='cci-files-transcribe$ENV_TYPE'" >> $WORKSPACE/pipeline_driver/.env
echo "S3_DEID_BKT='cci-files-deid$ENV_TYPE'" >> $WORKSPACE/pipeline_driver/.env
DE_IDENTIFY_API_ID=$(aws apigateway get-rest-apis --query "items[?name==\`de-identify-plain$ENV_TYPE\`].id" --output text)
echo "DEID_API_URL='https://$DE_IDENTIFY_API_ID.execute-api.$AWS_DEFAULT_REGION.amazonaws.com/$ENVIRONMENT_CHOICE'" >> $WORKSPACE/pipeline_driver/.env
cat $WORKSPACE/pipeline_driver/.env  
cp $WORKSPACE/mail_helper/send_email.py $WORKSPACE/pipeline_driver/utils/send_email.py
#Buiding docker image for pipeline driver
sudo docker build -t  cci-pipeline-driver$ENV_TYPE:latest .
#Tagging docker image for pipeline driver
sudo docker tag cci-pipeline-driver$ENV_TYPE:latest $ECR_ACCOUNT/cci-pipeline-driver$ENV_TYPE:latest
#Pushing docker image for pipeline driver
docker push $ECR_ACCOUNT/cci-pipeline-driver$ENV_TYPE:latest

echo "update comprehend docker image"
#Configuring environmental variable for comprehend
cd $WORKSPACE/comprehend
cp "$CCIEnv" $WORKSPACE/comprehend/.env
echo "\nDYNAMODB_TABLE='cci-item-queue$ENV_TYPE'" >> $WORKSPACE/comprehend/.env
echo "REGION_NAME='$AWS_DEFAULT_REGION'" >> $WORKSPACE/comprehend/.env
echo "TOPIC_S3_OUTPUT='cci-files-temp$ENV_TYPE'" >> $WORKSPACE/comprehend/.env
echo "TRANSCRIBE_S3_OUTPUT='cci-files-transcribe$ENV_TYPE'" >> $WORKSPACE/comprehend/.env
DATA_ACCESS_ROLE_ARN_ID=$(aws iam list-roles --query "Roles[?RoleName==\`cci-access-role$ENV_TYPE\`].Arn" --output text )
echo $DATA_ACCESS_ROLE_ARN_ID
echo "DATA_ACCESS_ROLE_ARN='$DATA_ACCESS_ROLE_ARN_ID'" >> $WORKSPACE/comprehend/.env
echo "COMPREHEND_S3_OUTPUT='cci-files-comprehend$ENV_TYPE'" >> $WORKSPACE/comprehend/.env
echo "DEID_S3_OUTPUT='cci-files-deid$ENV_TYPE'" >> $WORKSPACE/comprehend/.env
echo "MISC_S3_BKT='cci-misc$ENV_TYPE'" >> $WORKSPACE/comprehend/.env
AURORA_HOST_ADDRESS=$(aws rds describe-db-instances --query "DBInstances[?DBInstanceIdentifier==\`cci-db$ENV_TYPE\`].Endpoint.Address" --output text)
echo $AURORA_HOST_ADDRESS
echo "AURORA_HOST_ID='$AURORA_HOST_ADDRESS'" >> $WORKSPACE/comprehend/.env 
echo "AURORA_USER='root'" >> $WORKSPACE/comprehend/.env
echo "AURORA_PASSWORD='rootroot'" >> $WORKSPACE/comprehend/.env
echo "AURORA_PORT='3306'" >> $WORKSPACE/comprehend/.env
echo "AURORA_DB='test'" >> $WORKSPACE/comprehend/.env
cat $WORKSPACE/comprehend/.env  
cp $WORKSPACE/mail_helper/send_email.py $WORKSPACE/comprehend/utils/send_email.py
#Buiding docker image for comprehend
sudo docker build -t  cci-comprehend$ENV_TYPE:latest .
#Tagging docker image for comprehend
sudo docker tag cci-comprehend$ENV_TYPE:latest $ECR_ACCOUNT/cci-comprehend$ENV_TYPE:latest
#Pushing docker image for comprehend
docker push $ECR_ACCOUNT/cci-comprehend$ENV_TYPE:latest

export PATH=/var/lib/jenkins/.local/bin/:$PATH
cd $WORKSPACE/submit_request_plain/
touch $WORKSPACE/submit_request_plain/.env
echo "### Creating Submit Request lambda function zip ###"
# delete the existing env folder
rm -rf $WORKSPACE/submit_request_plain/env
#Installing virtual environemnt package 
pip install virtualenv --user
#Activating virtual environment
virtualenv env 
. env/bin/activate
#Installing required packages
pip install -r requirements.txt
#Moving required python files with installed packages
rm -rf $WORKSPACE/submit_request_plain/dist/
mkdir $WORKSPACE/submit_request_plain/dist/

# copy all dependencies
cp -rf $WORKSPACE/submit_request_plain/env/lib/python2.7/site-packages/* $WORKSPACE/submit_request_plain/dist/

# create .env file in site-packages
cp "$CCIEnv" $WORKSPACE/submit_request_plain/.env
# add the environment variables to this file
echo "\nDYNAMO_TABLE='cci-requests$ENV_TYPE'" >> $WORKSPACE/submit_request_plain/.env
echo "BOX_JOB_QUEUE='cci-box-crawl-queue$ENV_TYPE'" >> $WORKSPACE/submit_request_plain/.env
echo "BOX_JOB_DEFINITION='cci-box-crawl$ENV_TYPE:$BOX_CRAWL_JOB_DEFINITION_REVISION'" >> $WORKSPACE/submit_request_plain/.env
echo "BOX_AUTH_TABLE='cci-box-auth$ENV_TYPE'" >> $WORKSPACE/submit_request_plain/.env
 
cp $WORKSPACE/submit_request_plain/.env $WORKSPACE/submit_request_plain/dist/

# copy the main python file
cp -rf $WORKSPACE/submit_request_plain/submit_request_plain.py $WORKSPACE/submit_request_plain/dist/
cp $WORKSPACE/mail_helper/send_email.py $WORKSPACE/submit_request_plain/utils/send_email.py
# create a directory for utils
mkdir $WORKSPACE/submit_request_plain/dist/utils/
cp -rf $WORKSPACE/submit_request_plain/utils/* $WORKSPACE/submit_request_plain/dist/utils/ 
#Creating zip bundle for lambda function
cd $WORKSPACE/submit_request_plain/dist/
#zip -r submit_request_plain.zip $WORKSPACE/submit_request_plain/dist/*
zip -r ../submit_request_plain.zip .
#sudo apt-get install zip -y

#Updating zip bundle of lambda function submit request
cd $WORKSPACE/submit_request_plain/
aws lambda  update-function-code \
--function-name submit-request-plain$ENV_TYPE \
--zip-file fileb://submit_request_plain.zip \
--no-dry-run
#Deactivating virtual environment
deactivate

echo "###Updating de-identify lambda function"
cd $WORKSPACE/de_identify_plain/
touch $WORKSPACE/de_identify_plain/.env
#Removing old virtual environmental files
rm -rf $WORKSPACE/de_identify_plain/env
#Activating virtual environment
virtualenv env 
. env/bin/activate
#Installing required packages
pip install -r requirements.txt
#Moving required python files with packages
rm -rf $WORKSPACE/de_identify_plain/dist/
mkdir $WORKSPACE/de_identify_plain/dist/

# copy all dependencies
cp -rf $WORKSPACE/de_identify_plain/env/lib/python2.7/site-packages/* $WORKSPACE/de_identify_plain/dist/

cp "$CCIEnv" $WORKSPACE/de_identify_plain/.env
# no additional environmental variables for this function
cp $WORKSPACE/de_identify_plain/.env $WORKSPACE/de_identify_plain/dist/

cp -rf $WORKSPACE/de_identify_plain/de_identify.py $WORKSPACE/de_identify_plain/dist/
mkdir $WORKSPACE/de_identify_plain/dist/utils
cp -rf $WORKSPACE/de_identify_plain/utils/* $WORKSPACE/de_identify_plain/dist/utils/
#Creating zip bundle for lambda function
cd $WORKSPACE/de_identify_plain/dist/
echo "### Creating De-identify lambda function zip ###"
zip -r ../de_identify_plain.zip .
echo "####  Pushing lambda zip file to s3 ###"
#Updating zip bundle of lambda function de-identify
cd $WORKSPACE/de_identify_plain/
aws lambda  update-function-code \
--function-name de-identify-plain$ENV_TYPE \
--zip-file fileb://de_identify_plain.zip \
--region $AWS_DEFAULT_REGION \
--no-dry-run
#Deactivating virtual environment
deactivate

# box_token_refresh lambda function
echo "###Updating box_token_refresh lambda function"
cd $WORKSPACE/box_token_refresh/
touch $WORKSPACE/box_token_refresh/.env
#Removing old virtual environmental files
rm -rf $WORKSPACE/box_token_refresh/env
#Activating virtual environment
virtualenv env 
. env/bin/activate
#Installing required packages
pip install -r requirement.txt
#Moving required python files with packages
rm -rf $WORKSPACE/box_token_refresh/dist/
mkdir $WORKSPACE/box_token_refresh/dist/

# copy all dependencies
cp -rf $WORKSPACE/box_token_refresh/env/lib/python2.7/site-packages/* $WORKSPACE/box_token_refresh/dist/

cp "$CCIEnv" $WORKSPACE/box_token_refresh/.env
# add the environment variables to this file
echo "\nBOX_AUTH_TABLE='cci-box-auth$ENV_TYPE'" >> $WORKSPACE/box_token_refresh/.env
cp $WORKSPACE/box_token_refresh/.env $WORKSPACE/box_token_refresh/dist/

cp -rf $WORKSPACE/box_token_refresh/box_token_refresh.py $WORKSPACE/box_token_refresh/dist/
# create a directory for utils
mkdir $WORKSPACE/box_token_refresh/dist/utils/
cp -rf $WORKSPACE/box_token_refresh/utils/* $WORKSPACE/box_token_refresh/dist/utils/ 
#Creating zip bundle for lambda function
cd $WORKSPACE/box_token_refresh/dist/
echo "### Creating box_token_refresh lambda function zip ###"
zip -r ../box_token_refresh.zip .
echo "####  Pushing lambda zip file to s3 ###"
#Updating zip bundle of lambda function de-identify
cd $WORKSPACE/box_token_refresh/
aws lambda  update-function-code \
--function-name box-token-refresh$ENV_TYPE \
--zip-file fileb://box_token_refresh.zip \
--region $AWS_DEFAULT_REGION \
--no-dry-run
#Deactivating virtual environment
deactivate

# Deleting the entire workspace/code
#cd $WORKSPACE/
#rm -rf $WORKSPACE/.
