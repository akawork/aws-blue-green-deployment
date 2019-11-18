#!/bin/bash
echo "=====================Installation Started======================"
source config.sh

if [[ $ENV_TYPE =~ ^(dev|staging)$ ]]; then
	cd $SCRIPTDIR
	ProductServiceGitURL=$(aws codecommit get-repository --repository-name $PRODUCTSERVICEREPONAME --region $AWSREGION --query "repositoryMetadata.cloneUrlHttp" --output text)
	OrderServiceGitURL=$(aws codecommit get-repository --repository-name $ORDERSERVICEREPONAME --region $AWSREGION --query "repositoryMetadata.cloneUrlHttp" --output text)
	FrontendServiceGitURL=$(aws codecommit get-repository --repository-name $FRONTENDSERVICEREPONAME --region $AWSREGION --query "repositoryMetadata.cloneUrlHttp" --output text)

	# Create cloudformation stack for aws codebuild project
	aws cloudformation create-stack --stack-name $CFBUILDSTACKNAME --capabilities CAPABILITY_NAMED_IAM --template-body file://cloud-demo-build-project.json --region $AWSREGION --parameters ParameterKey=ProductServiceGitURL,ParameterValue=$ProductServiceGitURL ParameterKey=OrderServiceGitURL,ParameterValue=$OrderServiceGitURL ParameterKey=FrontendServiceGitURL,ParameterValue=$FrontendServiceGitURL ParameterKey=BuildBranch,ParameterValue=$GITBRANCH ParameterKey=EnvironmentType,ParameterValue=$ENV_TYPE
	echo "========Creating CloudFormation Stack for AWS CodeBuild project========="
	# Wait until stack created
	aws cloudformation wait stack-create-complete --stack-name $CFBUILDSTACKNAME --region $AWSREGION

	AWSACCOUNTID=$(aws sts get-caller-identity --region $AWSREGION --query "Account" --output text)
	# Modify and Upload buildspec for 3 service and sonar
	echo "========Update buildspec for new Environment========="
	list_service=(product order frontend sonar)
	for s in "${list_service[@]}"
	do
		if [ -d "$SOURCE" ]; then 
			# check if it is symlink
			if [ -L "$SOURCE" ]; then
				echo "Invalid link"
			else
				rm -rf $SOURCE/*
			fi
		else
			mkdir $SOURCE
		fi
		if [ $s == "product" ]; then
			SOURCEFOLDER=$PRODUCTSERVICEREPONAME
			GITURL=$(echo $ProductServiceGitURL | sed -E 's~https://~~g')
			GITURL=https://$GITUSERNAME:$GITPASSWORD@$GITURL
			ECRIMGURI=$AWSACCOUNTID.dkr.ecr.$AWSREGION.amazonaws.com/cloud-$ENV_TYPE-demo-product-service
			sed "s~PRODUCTSERVICEIMAGEURI~$(printf $ECRIMGURI)~g" $SCRIPTDIR/buildspec/$s/buildspec.yaml > $SCRIPTDIR/buildspec-$ENV_TYPE.yaml
			cd $SOURCE
			git clone $GITURL
			cd $SOURCEFOLDER
			git checkout $GITBRANCH
			cp -R $SCRIPTDIR/buildspec-$ENV_TYPE.yaml productservice/buildspec-$ENV_TYPE.yaml
			git add productservice/buildspec-$ENV_TYPE.yaml
			git commit -m "Update buildspec for product service"
			git push origin $GITBRANCH
			cd $SCRIPTDIR
			rm -rf $SCRIPTDIR/buildspec-$ENV_TYPE.yaml
			rm -rf $SOURCE/*
		elif [ $s == "order" ]; then
			SOURCEFOLDER=$ORDERSERVICEREPONAME
			GITURL=$(echo $OrderServiceGitURL | sed -E 's~https://~~g')
			GITURL=https://$GITUSERNAME:$GITPASSWORD@$GITURL
			ECRIMGURI=$AWSACCOUNTID.dkr.ecr.$AWSREGION.amazonaws.com/cloud-$ENV_TYPE-demo-order-service
			sed "s~ORDERSERVICEIMAGEURI~$(printf $ECRIMGURI)~g" $SCRIPTDIR/buildspec/$s/buildspec.yaml > $SCRIPTDIR/buildspec-$ENV_TYPE.yaml
			cd $SOURCE
			git clone $GITURL
			cd $SOURCEFOLDER
			git checkout $GITBRANCH
			cp -R $SCRIPTDIR/buildspec-$ENV_TYPE.yaml orderservice/buildspec-$ENV_TYPE.yaml
			git add orderservice/buildspec-$ENV_TYPE.yaml
			git commit -m "Update buildspec for order service"
			git push origin $GITBRANCH
			cd $SCRIPTDIR
			rm -rf $SCRIPTDIR/buildspec-$ENV_TYPE.yaml
			rm -rf $SOURCE/*
		elif [ $s == "frontend" ]; then
			SOURCEFOLDER=$FRONTENDSERVICEREPONAME
			GITURL=$(echo $FrontendServiceGitURL | sed -E 's~https://~~g')
			GITURL=https://$GITUSERNAME:$GITPASSWORD@$GITURL
			ECRIMGURI=$AWSACCOUNTID.dkr.ecr.$AWSREGION.amazonaws.com/cloud-$ENV_TYPE-demo-frontend-service
			sed "s~FRONTENDSERVICEIMAGEURI~$(printf $ECRIMGURI)~g" $SCRIPTDIR/buildspec/$s/buildspec.yaml > $SCRIPTDIR/buildspec-$ENV_TYPE.yaml
			cd $SOURCE
			git clone $GITURL
			cd $SOURCEFOLDER
			git checkout $GITBRANCH
			cp -R $SCRIPTDIR/buildspec-$ENV_TYPE.yaml buildspec-$ENV_TYPE.yaml
			git add buildspec-$ENV_TYPE.yaml
			git commit -m "Update buildspec for frontend service"
			git push origin $GITBRANCH
			cd $SCRIPTDIR
			rm -rf $SCRIPTDIR/buildspec-$ENV_TYPE.yaml
			rm -rf $SOURCE/*
		elif [ $s == "sonar" ]; then
			SOURCEFOLDER=$PRODUCTSERVICEREPONAME
			GITURL=$(echo $ProductServiceGitURL | sed -E 's~https://~~g')
			GITURL=https://$GITUSERNAME:$GITPASSWORD@$GITURL
			ECRIMGURI=$AWSACCOUNTID.dkr.ecr.$AWSREGION.amazonaws.com/cloud-demo-sonar-scanner
			sed "s~SONARSCANNERIMAGEURI~$(printf $ECRIMGURI)~g" $SCRIPTDIR/buildspec/$s/sonarimage_buildspec.yaml > $SCRIPTDIR/sonarimage_buildspec.yaml
			cd $SOURCE
			git clone $GITURL
			cd $SOURCEFOLDER
			git checkout $GITBRANCH
			cp -R $SCRIPTDIR/sonarimage_buildspec.yaml DevOps-Cloud-Demo/sonarimage_buildspec.yaml
			git add DevOps-Cloud-Demo/sonarimage_buildspec.yaml
			git commit -m "Update buildspec for sonar scanner"
			git push origin $GITBRANCH
			cd $SCRIPTDIR
			rm -rf $SCRIPTDIR/sonarimage_buildspec.yaml
			rm -rf $SOURCE/*
		else
			echo "this script only support 3 microservices (product/order/frontend)"
		fi
	done

	# Run build for pushing Sonar Scanner Image
	aws codebuild start-build --project-name cloud-demo-sonar-scanner --queued-timeout-in-minutes-override 5 --source-version refs/heads/$GITBRANCH --region $AWSREGION
	# Run build for pushing product service Image
	aws codebuild start-build --project-name cloud-$ENV_TYPE-demo-product-service --queued-timeout-in-minutes-override 5 --source-version refs/heads/$GITBRANCH --region $AWSREGION
	# Run build for pushing order service Image
	aws codebuild start-build --project-name cloud-$ENV_TYPE-demo-order-service --queued-timeout-in-minutes-override 5 --source-version refs/heads/$GITBRANCH --region $AWSREGION
	# Run build for pushing frontend service Image
	aws codebuild start-build --project-name cloud-$ENV_TYPE-demo-frontend-service --queued-timeout-in-minutes-override 5 --source-version refs/heads/$GITBRANCH --region $AWSREGION
	echo "========Running first build for all microservices========="

	cd $SCRIPTDIR
	# Get API Domain Certificate ARN
	# Get API Domain Certificate ARN
	if [[ $ENV_TYPE = "staging" ]]; then
		# Get API Domain Certificate ARN
		APICERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='api.demo.akawork.io'].CertificateArn" --output text)
	elif [[ $ENV_TYPE = "dev" ]]; then
		# Get API Domain Certificate ARN
		APICERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='api2.demo.akawork.io'].CertificateArn" --output text)
	elif [[ $ENV_TYPE = "test" ]]; then
		# Get API Domain Certificate ARN
		APICERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='api3.demo.akawork.io'].CertificateArn" --output text)
	fi
	# Get Application Domain Certificate ARN
	APPCERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='*.demo.akawork.io'].CertificateArn" --output text)

	if [ -z "$APICERTARN" ]; then
		echo "========Import API Certificate to AWS ACM========="
		# Import API Domain Certificate
		if [[ $ENV_TYPE = "staging" ]]; then
			aws acm import-certificate --certificate file://23571448_api.demo.akawork.io.cert --private-key file://23571448_api.demo.akawork.io.key --region $AWSREGION
			APICERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='api.demo.akawork.io'].CertificateArn" --output text)
		elif [[ $ENV_TYPE = "dev" ]]; then
			aws acm import-certificate --certificate file://62297519_api2.demo.akawork.io.cert --private-key file://62297519_api2.demo.akawork.io.key --region $AWSREGION
			APICERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='api2.demo.akawork.io'].CertificateArn" --output text)
		elif [[ $ENV_TYPE = "test" ]]; then
			aws acm import-certificate --certificate file://88646447_api3.demo.akawork.io.cert --private-key file://88646447_api3.demo.akawork.io.key --region $AWSREGION
			APICERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='api3.demo.akawork.io'].CertificateArn" --output text)
		fi
		APICERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='api.demo.akawork.io'].CertificateArn" --output text)
	fi
	if [ -z "$APPCERTARN" ]; then
		echo "========Import Application Certificate to AWS ACM========="
		# Import APP Domain Certificate
		aws acm import-certificate --certificate file://77028414__.demo.akawork.io.cert --private-key file://77028414__.demo.akawork.io.key --region $AWSREGION
		APPCERTARN=$(aws acm list-certificates --region $AWSREGION --query "CertificateSummaryList[?DomainName=='*.demo.akawork.io'].CertificateArn" --output text)
	fi

	# Get bastion image id depend on region
	BastionImageID=$(aws ec2 describe-images --region $AWSREGION --owners amazon --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????-x86_64-gp2' 'Name=state,Values=available' --query Images[0].ImageId --output text)
	# Create cloudformation stack for infrastructure
	echo "========Creating CloudFormation Stack Blue/Green Deployment Infrastructure========="
	aws cloudformation create-stack --stack-name $CFINFRASTACKNAME --capabilities CAPABILITY_NAMED_IAM --template-body file://cloud-demo-bluegreen-infras.json --region $AWSREGION --parameters ParameterKey=KeyPairName,ParameterValue=$KEYPAIRNAME ParameterKey=DatabaseUser,ParameterValue=$DBUsername ParameterKey=DatabasePassword,ParameterValue=$DBPassword ParameterKey=BastionImageID,ParameterValue=$BastionImageID ParameterKey=APICertificateARN,ParameterValue=$APICERTARN ParameterKey=ApplicationCertificateARN,ParameterValue=$APPCERTARN ParameterKey=EnvironmentType,ParameterValue=$ENV_TYPE
	# Wait until stack created
	aws cloudformation wait stack-create-complete --stack-name $CFINFRASTACKNAME --region $AWSREGION

	./awscli-bluegreen.sh product
	./awscli-bluegreen.sh order
	./awscli-bluegreen.sh frontend

	READCHECK=$(cat input.txt)
	# Check if infrastructure cloudformation stack created successfully
	if [ $READCHECK=="None" ] || [ ! -s input.txt ]; then
		echo "Create Infrastructure Stack failed"
		exit 1
	else
		rm -rf $SCRIPTDIR/input.txt 
	fi
	
	if [[ $ENV_TYPE =~ ^(dev|test|staging)$ ]]; then
	cd $SCRIPTDIR
	# Get route 53 hosted zone ID
	ROUTE53DOMAINNAME=demo.akawork.io
	HOSTEDZONEID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='$ROUTE53DOMAINNAME.'].Id" --output text)
	# Get api gateway custom domain name
	if [[ $ENV_TYPE = "staging" ]]; then
		# Get API Domain Certificate ARN
		APITARGETDOMAINNAME=$(aws apigateway get-domain-name --domain-name api.demo.akawork.io --region $AWSREGION --query regionalDomainName --output text)
		APPDOMAINNAME=admin.$ROUTE53DOMAINNAME
		APIROUTE53DOMAIN=api.$ROUTE53DOMAINNAME
	elif [[ $ENV_TYPE = "dev" ]]; then
		# Get API Domain Certificate ARN
		APITARGETDOMAINNAME=$(aws apigateway get-domain-name --domain-name api2.demo.akawork.io --region $AWSREGION --query regionalDomainName --output text)
		APPDOMAINNAME=dev.$ROUTE53DOMAINNAME
		APIROUTE53DOMAIN=api2.$ROUTE53DOMAINNAME
	elif [[ $ENV_TYPE = "test" ]]; then
		# Get API Domain Certificate ARN
		APITARGETDOMAINNAME=$(aws apigateway get-domain-name --domain-name api3.demo.akawork.io --region $AWSREGION --query regionalDomainName --output text)
		APPDOMAINNAME=test.$ROUTE53DOMAINNAME
		APIROUTE53DOMAIN=api3.$ROUTE53DOMAINNAME
	fi
	# Get application load balancer DNS
	ALBDNS=$(aws elbv2 describe-load-balancers --name cloud-$ENV_TYPE-demo-alb --region $AWSREGION --query 'LoadBalancers[*].DNSName' --output text)
	# Get application load balancer HostedZones ID
	ALBHOSTEDZONEID=$(aws elbv2 describe-load-balancers --name cloud-$ENV_TYPE-demo-alb --region $AWSREGION --query 'LoadBalancers[*].CanonicalHostedZoneId' --output text)
	if [ -z $HOSTEDZONEID ]; then
		echo "Please create hosted zone for domain demo.akawork.io. on aws route 53 for this demo"
	else
		if [ -z $APITARGETDOMAINNAME ] || [ -z $ALBDNS ] || [ -z $ALBHOSTEDZONEID ]; then
			echo "Infrastructure is missing some record. Please check the result of infrastructure cloudformation stack"
		else
			sed "s~APIRECORDDOMAINNAME~$APIROUTE53DOMAIN~g;s~APIRECORDTYPE~CNAME~g;s~APIRECORDVALUE~$(printf $APITARGETDOMAINNAME)~g;s~APPRECORDDOMAINNAME~$APPDOMAINNAME~g;s~APPRECORDTYPE~A~g;s~APPHOSTEDZONEDID~$(printf $ALBHOSTEDZONEID)~g;s~APPDNSNAME~$(printf $ALBDNS)~g;" $SCRIPTDIR/recordtemplate.json > $SCRIPTDIR/route53record.json
			echo "====Making change for the Route 53 Hosted Zones records===="
			ROUTE53CHANGERECORDID=$(aws route53 change-resource-record-sets --hosted-zone-id $HOSTEDZONEID --change-batch file://route53record.json --query "ChangeInfo.Id" --output text)
			echo "=======Wait for the change finish successfully======="
			aws route53 wait resource-record-sets-changed --id $ROUTE53CHANGERECORDID
			echo "=======Clear the route 53 record in local======="
			rm -rf $SCRIPTDIR/route53record.json
		fi
	fi
else
	echo "=========The environment $ENV_TYPE is not supported========"
fi

	cd $SCRIPTDIR
	# Create CloudFormation Stack for CICD Pipeline
	echo "========Creating CloudFormation Stack CICD Pipeline========="
	aws cloudformation create-stack --stack-name $CFPIPELINESTACKNAME --capabilities CAPABILITY_NAMED_IAM --template-body file://cloud-demo-pipeline.json --region $AWSREGION --parameters ParameterKey=ProductServiceREPOName,ParameterValue=$PRODUCTSERVICEREPONAME ParameterKey=OrderServiceREPOName,ParameterValue=$ORDERSERVICEREPONAME ParameterKey=FrontendServiceREPOName,ParameterValue=$FRONTENDSERVICEREPONAME ParameterKey=REPOSourceBranch,ParameterValue=$GITBRANCH ParameterKey=REPOSourceBranch,ParameterValue=$GITBRANCH ParameterKey=EnvironmentType,ParameterValue=$ENV_TYPE
	# Wait until stack created
	aws cloudformation wait stack-create-complete --stack-name $CFPIPELINESTACKNAME --region $AWSREGION
	echo "=====================Installation Finished======================"
fi