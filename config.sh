# Input environment type (dev/staging)
ENV_TYPE=staging
# GIT credential username
GITUSERNAME=
# GIT credential password
GITPASSWORD=
# Repository Name of Product Service
PRODUCTSERVICEREPONAME=
# Repository Name of Order Service
ORDERSERVICEREPONAME=
# Repository Name of Frontend Service
FRONTENDSERVICEREPONAME=
# Branch of source code corresponding with the environment (develop-dev/master-staging)
GITBRANCH=
# Database username
DBUsername=
# Database password
DBPassword=
# Directory contain the script file to run
SCRIPTDIR=
# Folder storing source file
SOURCE=$SCRIPTDIR/source
# Name of the AWS Cloudformation CodeBuild Stack
CFBUILDSTACKNAME=cloud-$ENV_TYPE
# Name of the AWS Cloudformation Infrastructure Stack
CFINFRASTACKNAME=cloud-$ENV_TYPE
# Name of the AWS Cloudformation CICD Pipeline Stack
CFPIPELINESTACKNAME=cloud-$ENV_TYPE
# AWS Region
AWSREGION=
# Key pair name
KEYPAIRNAME=