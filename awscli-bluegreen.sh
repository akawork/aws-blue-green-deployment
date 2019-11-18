MICROSERVICE=${1?:Error: please define which microservice (product/order/frontend) to set up on aws}
if [[ $MICROSERVICE =~ ^(product|order|frontend)$ ]]; then
	echo "======Loading setting for $MICROSERVICE service======"
	# cat bluegreendemo-setting.txt >> input.txt
	source bluegreendemo-setting.sh $MICROSERVICE
	if [ $READCHECK=="None" ] || [ ! -s input.txt ]; then
		echo "Create Infrastructure Stack failed"
		exit 1
	fi
	# Configuring task def file
	echo "======Creating Task Definition JSON setting for $MICROSERVICE service======"
	./taskdef.sh $TASKNAME $ServiceIMAGE $TASKROLE $EXECUTIONROLE $PORT $PORTPROTOCOL $RDSEndpoint $DBUsername $DBPassword $AWSLOGGROUP $AWSREGION $MICROSERVICE $TASKDEFFILE $PRODUCTENDPOINT
	echo "=========Creating Task Definition for $MICROSERVICE on AWS========="
	# create task definition for product service by cli
	aws ecs register-task-definition --cli-input-json file://$TASKDEFFILE.json --region $AWSREGION
	# Get task def ARN
	TASKDEFARN=$(aws ecs describe-task-definition --task-definition $TASKNAME --region $AWSREGION --query "taskDefinition.taskDefinitionArn" --output text)
	# Remove the revision to get the latest task def revision
	TASKDEFARN=${TASKDEFARN%:*}
	echo "======Setting ECS Service for $MICROSERVICE service======"
	# Configuring ecs service
	./ecsservice.sh $CLUSTERNAME $SERVICENAME $TASKNAME $TARGETGROUP1 $PORT $SERVICEDISCOVERYARN $PUBLICIPOPTION $SERVICESG $SUBNET1 $SUBNET2 $TASKDEFARN $AWSREGION $ECSServiceFilename
	echo "=========Creating ECS Service for $MICROSERVICE service on AWS========="
	# create ecs service for product service
	aws ecs create-service --cli-input-json file://ecs-service-$ECSServiceFilename.json --region $AWSREGION
	# Register ecs service as a scaling target
	aws application-autoscaling register-scalable-target --service-namespace ecs --scalable-dimension ecs:service:DesiredCount --resource-id service/$CLUSTERNAME/$SERVICENAME --min-capacity 1 --max-capacity 2 --role-arn $AUTOSCALEROLE --region $AWSREGION
	# CPU Scaling policy
	aws application-autoscaling put-scaling-policy --service-namespace ecs --scalable-dimension ecs:service:DesiredCount --resource-id service/$CLUSTERNAME/$SERVICENAME --policy-name $MICROSERVICE-service-cpu-scaling-policy --policy-type TargetTrackingScaling --target-tracking-scaling-policy-configuration file://scaleCPUpolicyconfig.json --region $AWSREGION
	# Memory Scaling policy
	aws application-autoscaling put-scaling-policy --service-namespace ecs --scalable-dimension ecs:service:DesiredCount --resource-id service/$CLUSTERNAME/$SERVICENAME --policy-name $MICROSERVICE-service-memory-scaling-policy --policy-type TargetTrackingScaling --target-tracking-scaling-policy-configuration file://scaleMEMpolicyconfig.json --region $AWSREGION
	echo "======Update Appspec and Task Def file in AWS CodeCommit for $MICROSERVICE service======"
	# Clone source for Update appspec and taskdef file in service repo
	if [ -d "$SOURCE" ]; then 
		# check if it is symlink
		if [ -L "$SOURCE" ]; then
			echo "Invalid link"
			exit 1
		else
			rm -rf $SOURCE/*
		fi
	else
		mkdir $SOURCE
	fi
	cd $SOURCE
	git clone $GITURL
	cd $SOURCEFOLDER
	git checkout $GITBRANCH
	cp -R ../../$TASKDEFFILE.json $TASKDEFFILE.json
	cp -R ../../appspec$ECSServiceFilename.yaml appspec$ECSServiceFilename.yaml
	git add appspec$ECSServiceFilename.yaml $TASKDEFFILE.json
	git commit -m "Update appspec and task definition"
	git push origin $GITBRANCH
	cd $SCRIPTDIR
	rm -rf $SOURCE/*
	# Create deployment repo for version control deployment
	DeploymentGitURL=$(aws codecommit get-repository --repository-name Demo.DevOps.Deployment --region $AWSREGION --query "repositoryMetadata.cloneUrlHttp" --output text)
	if [ -z $DeploymentGitURL ]; then
		echo "======Creating CodeCommit Repository for Version Deployment======"
		DeploymentGitURL=$(aws codecommit create-repository --repository-name Demo.DevOps.Deployment --region $AWSREGION --query "repositoryMetadata.cloneUrlHttp" --output text)
		DeploymentGitURL=$(echo $DeploymentGitURL | sed -E 's~https://~~g')
		DeploymentGitURL=https://$GITUSERNAME:$GITPASSWORD@$DeploymentGitURL
		cd $SOURCE
		git clone $DeploymentGitURL
		cd Demo.DevOps.Deployment
		echo "This repo is for version control deployment of Demo DevOps service" > readme.md
		git add readme.md
		git commit -m "First commit"
		git push origin master
		cd $SCRIPTDIR
		rm -rf $SOURCE/*
	fi
	DeploymentBranch=$(aws codecommit get-branch --repository-name Demo.DevOps.Deployment --branch-name $MICROSERVICE --region $AWSREGION --query "branch.branchName" --output text)
	if [ -z $DeploymentBranch ]; then
		echo "=======Creating Deployment branch for $MICROSERVICE service========"
		COMMITID=$(aws codecommit get-branch --repository-name Demo.DevOps.Deployment --branch-name master --region $AWSREGION --query "branch.commitId" --output text)
		aws codecommit create-branch --repository-name Demo.DevOps.Deployment --branch-name $MICROSERVICE --commit-id $COMMITID --region $AWSREGION
	fi
	echo "=====Uploading Task Def and Appspec files for version control deployment===="
	cd $SOURCE
	DeploymentGitURL=$(echo $DeploymentGitURL | sed -E 's~https://~~g')
	DeploymentGitURL=https://$GITUSERNAME:$GITPASSWORD@$DeploymentGitURL
	git clone $DeploymentGitURL
	cd Demo.DevOps.Deployment
	git checkout $MICROSERVICE
	cp -R ../../$TASKDEFFILE.json $TASKDEFFILE.json
	cp -R ../../appspec$ECSServiceFilename.yaml appspec$ECSServiceFilename.yaml
	git add $TASKDEFFILE.json appspec$ECSServiceFilename.yaml
	git commit -m "Upload appspec and task definition for version deployment"
	git push origin $MICROSERVICE
	cd $SCRIPTDIR
	rm -rf $SOURCE/*
	echo "=========Creating Deployment Application for $MICROSERVICE service on AWS========="
	# create deployment application
	aws deploy create-application --application-name $APPDEPLOYNAME --compute-platform ECS --region $AWSREGION
	echo "======Setting Blue/Green Deployment Group for $MICROSERVICE service======"
	# Configuring deployment group
	./deploymentgroup.sh $APPDEPLOYNAME $GROUPDEPLOYNAME $TARGETGROUP1 $TARGETGROUP2 $PORT $SERVICEROLE $CLUSTERNAME $SERVICENAME $LOADBALANCER $AWSREGION $DEPLOYGROUPFILENAME
	echo "=========Creating Deployment Group for $MICROSERVICE service on AWS========="
	# Create deployment group
	aws deploy create-deployment-group --cli-input-json file://$DEPLOYGROUPFILENAME.json --region $AWSREGION
	echo "=========Creating Application AutoScaling for ECS Service==========="
	rm -rf $SCRIPTDIR/$DEPLOYGROUPFILENAME.json
	rm -rf $SCRIPTDIR/$TASKDEFFILE.json
	rm -rf $SCRIPTDIR/ecs-service-$ECSServiceFilename.json
	rm -rf $SCRIPTDIR/appspec$ECSServiceFilename.yaml
else
	echo "this script only support 3 microservices (product/order/frontend)"
fi
