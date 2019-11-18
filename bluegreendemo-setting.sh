MICROSERVICE=${1?:Error: please define which microservice (product/order/frontend) to set up on aws}

if [[ $MICROSERVICE =~ ^(product|order|frontend)$ ]]; then
	#Configurable variables
	source config.sh
	GITUSERNAME=$GITUSERNAME
	GITPASSWORD=$GITPASSWORD
	# Get Outputs from AWS CloudFormation
	aws cloudformation describe-stacks --stack-name $CFINFRASTACKNAME --region $AWSREGION --query "Stacks[0].Outputs[*].[OutputKey,OutputValue]" --output text > input.txt
	sed -i 's/\t/=/g' input.txt
	# Import CloudFormation Outputs
	source input.txt
	READCHECK=$(cat input.txt)
	#Common Variables
	AWSACCOUNTID=$(aws sts get-caller-identity --region $AWSREGION --query "Account" --output text)
	CLUSTERNAME=cloud-$ENV_TYPE-demo-cluster
	# Role for deployment
	TASKROLE=arn:aws:iam::$AWSACCOUNTID:role/ECSTASKS-cloud-$ENV_TYPE-demo-taskexecution-role-$AWSREGION
	EXECUTIONROLE=arn:aws:iam::$AWSACCOUNTID:role/ECSTASKS-cloud-$ENV_TYPE-demo-taskexecution-role-$AWSREGION
	SERVICEROLE=arn:aws:iam::$AWSACCOUNTID:role/CodeDeploy-cloud-$ENV_TYPE-demo-ECS-role-$AWSREGION
	AUTOSCALEROLE=arn:aws:iam::$AWSACCOUNTID:role/ApplicationAutoscaling-cloud-$ENV_TYPE-demo-role-$AWSREGION
	TASKNAME=cloud-$ENV_TYPE-demo-$MICROSERVICE-service
	APPDEPLOYNAME=AppECS-cloud-$ENV_TYPE-demo-$MICROSERVICE-service
	GROUPDEPLOYNAME=DgpECS-cloud-$ENV_TYPE-demo-$MICROSERVICE-service
	SERVICENAME=$ENV_TYPE-$MICROSERVICE-service
	AWSLOGGROUP=/aws/ecs/cloud-$ENV_TYPE-demo-$MICROSERVICE-service
	# Deployment group setting
	DEPLOYGROUPFILENAME=deployment-group-$MICROSERVICE-service
	if [ $MICROSERVICE == "product" ]; then
		GITURL=$(aws codecommit get-repository --repository-name $PRODUCTSERVICEREPONAME --region $AWSREGION --query "repositoryMetadata.cloneUrlHttp" --output text)
		GITURL=$(echo $GITURL | sed -E 's~https://~~g')
		GITURL=https://$GITUSERNAME:$GITPASSWORD@$GITURL
		SOURCEFOLDER=$PRODUCTSERVICEREPONAME
		#======Setting for Product service======
		# Common setting for Product Service
		PORT=9002
		PORTPROTOCOL=tcp
		# Task def setting
		ServiceIMAGE=$AWSACCOUNTID.dkr.ecr.$AWSREGION.amazonaws.com/cloud-$ENV_TYPE-demo-product-service
		TASKDEFFILE=taskdefproductservice-$ENV_TYPE
		# ECS service setting
		ECSServiceFilename=productservice-$ENV_TYPE
		PUBLICIPOPTION=DISABLED
		TARGETGROUP1=$ProductServiceTG1
		TARGETGROUP2=$ProductServiceTG2
		SERVICEDISCOVERYARN=$ProductServiceDiscoveryARN
		SERVICESG=$ProductServiceSG
		SUBNET1=$DemoSubnetPrivate1
		SUBNET2=$DemoSubnetPrivate2
		LOADBALANCER=$NLBName
		PRODUCTENDPOINT=""
	elif [ $MICROSERVICE == "order" ]; then
		GITURL=$(aws codecommit get-repository --repository-name $ORDERSERVICEREPONAME --region $AWSREGION --query "repositoryMetadata.cloneUrlHttp" --output text)
		GITURL=$(echo $GITURL | sed -E 's~https://~~g')
		GITURL=https://$GITUSERNAME:$GITPASSWORD@$GITURL
		SOURCEFOLDER=$ORDERSERVICEREPONAME
		PORT=9001
		PORTPROTOCOL=tcp
		# Task def setting
		ServiceIMAGE=$AWSACCOUNTID.dkr.ecr.$AWSREGION.amazonaws.com/cloud-$ENV_TYPE-demo-order-service
		TASKDEFFILE=taskdeforderservice-$ENV_TYPE
		# ECS service setting
		ECSServiceFilename=orderservice-$ENV_TYPE
		PUBLICIPOPTION=DISABLED
		PRODUCTENDPOINT=http://$ENV_TYPE-product-service.local:9002/api/v1
		TARGETGROUP1=$OrderServiceTG1
		TARGETGROUP2=$OrderServiceTG2
		SERVICEDISCOVERYARN=$OrderServiceDiscoveryARN
		SERVICESG=$OrderServiceSG
		SUBNET1=$DemoSubnetPrivate1
		SUBNET2=$DemoSubnetPrivate2
		LOADBALANCER=$NLBName
	elif [ $MICROSERVICE == "frontend" ]; then
		GITURL=$(aws codecommit get-repository --repository-name $FRONTENDSERVICEREPONAME --region $AWSREGION --query "repositoryMetadata.cloneUrlHttp" --output text)
		GITURL=$(echo $GITURL | sed -E 's~https://~~g')
		GITURL=https://$GITUSERNAME:$GITPASSWORD@$GITURL
		SOURCEFOLDER=$FRONTENDSERVICEREPONAME
		PORT=80
		PORTPROTOCOL=tcp
		# Task def setting
		ServiceIMAGE=$AWSACCOUNTID.dkr.ecr.$AWSREGION.amazonaws.com/cloud-$ENV_TYPE-demo-frontend-service
		TASKDEFFILE=taskdeffrontendservice-$ENV_TYPE
		# ECS service setting
		ECSServiceFilename=frontendservice-$ENV_TYPE
		PUBLICIPOPTION=ENABLED
		TARGETGROUP1=$FrontendServiceTG1
		TARGETGROUP2=$FrontendServiceTG2
		SERVICEDISCOVERYARN=$FrontendServiceDiscoveryARN
		SERVICESG=$FrontendServiceSG
		SUBNET1=$DemoSubnetPublic1
		SUBNET2=$DemoSubnetPublic2
		LOADBALANCER=$ALBName
		PRODUCTENDPOINT=""
	else
		echo "this script only support 3 microservices (product/order/frontend)"
	fi
else
	echo "this script only support 3 microservices (product/order/frontend)"
fi



