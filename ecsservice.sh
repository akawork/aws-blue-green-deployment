CLUSTERNAME=${1?:Error: cluster name is required}
SERVICENAME=${2?:Error: service name is required}
TASKNAME=${3?:Error: task name is required}
TGNAME=${4?:Error: target group arn is required}
PORT=${5?:Error: port is required}
DISCOVERYSERVICEARN=${6?:Error: discovery service arn is required}
PUBLICIPOPTION=${7?:Error: PublicIP option is required}
SERVICESG=${8?:Error: security group is required}
SERVICESUBNET1=${9?:Error: subnet 1 is required}
SERVICESUBNET2=${10?:Error: subnet 2 is required}
TASKDEFARN=${11?:Error: Task Definition ARN is required}
AWSREGION=${12?:Region is required}
ECSSERVICEFILE=${13?:Error: ecs service filename is required}

if [[ $PORT =~ ^(9002|9001|80|443)$ ]]; then
	#aws elbv2 describe-target-groups --names $ProductServiceTG1
	TGARN=$(aws elbv2 describe-target-groups --names $TGNAME --region $AWSREGION --query "TargetGroups[*].TargetGroupArn" --output text)
	sed "s~CLUSTERNAME~$(printf $CLUSTERNAME)~g;s~SERVICENAME~$(printf $SERVICENAME)~g;s~TASKNAME~$(printf $TASKNAME)~g;s~TGARN~$(printf $TGARN)~g;s~PORT~$(printf $PORT)~g;s~DISCOVERYSERVICEARN~$(printf $DISCOVERYSERVICEARN)~g;s~PUBLICIPOPTION~$(printf $PUBLICIPOPTION)~g;s~SERVICESG~$(printf $SERVICESG)~g;s~SERVICESUBNET1~$(printf $SERVICESUBNET1)~g;s~SERVICESUBNET2~$(printf $SERVICESUBNET2)~g;" ecsservice.json > ecs-service-$ECSSERVICEFILE.json
	sed "s~TASKDEFARN~$(printf $TASKDEFARN)~g;s~TASKNAME~$(printf $TASKNAME)~g;s~PORT~$(printf $PORT)~g;s~SERVICESG~$(printf $SERVICESG)~g;s~SERVICESUBNET1~$(printf $SERVICESUBNET1)~g;s~SERVICESUBNET2~$(printf $SERVICESUBNET2)~g;s~PUBLICIPOPTION~$(printf $PUBLICIPOPTION)~g;" appspec.yaml > appspec$ECSSERVICEFILE.yaml
else
    echo "Port $PORT is not support in this project"
fi