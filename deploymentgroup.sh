APPNAME=${1?:Error: application name is required}
DEPLOYGROUPNAME=${2?:Error: deployment group name is required}
TGNAME1=${3?:Error: Task def name is required}
TGNAME2=${4?:Error: Target Group ARN is required}
PORT=${5?:Error: PORT is required}
SERVICEROLE=${6:-arn:aws:iam::729713917879:role/CodeDeploy-ECS}
CLUSTERNAME=${7:-cloud-dev-demo-cluster}
SERVICENAME=${8?:Error: service name is required}
#CFSTACKNAME=${9?:Error: CloudFormation stack name is required}
LOADBALANCER=${9?:Error: load balancer name is required}
AWSREGION=${10?:Region is required}
DEPLOYGROUP=${11?:Error: deployment group filename is required}

if [[ $PORT =~ ^(9002|9001|80|443)$ ]]; then
	# Get LBNAME from CloudFormation stack Outputs
	#LBNAME=$(aws cloudformation describe-stacks --stack-name $CFSTACKNAME --region ap-southeast-1 --query "Stacks[0].Outputs[?OutputKey=='$LOADBALANCER'].OutputValue" --output text)
	# Get LBARN by using LBNAME
	LBARN=$(aws elbv2 describe-load-balancers --name $LOADBALANCER --region $AWSREGION --query 'LoadBalancers[*].LoadBalancerArn' --output text)
	# take LB ARN to get listener arn of specific port
	if [ $PORT == 80 ]; then
		LISTENERARN=$(aws elbv2 describe-listeners --load-balancer-arn $LBARN --region $AWSREGION --query "Listeners[*].[Port,ListenerArn]" --output text | grep 443 | awk '{print $2}')
	else
		LISTENERARN=$(aws elbv2 describe-listeners --load-balancer-arn $LBARN --region $AWSREGION --query "Listeners[*].[Port,ListenerArn]" --output text | grep $PORT | awk '{print $2}')
	fi
	sed "s~APPNAME~$(printf $APPNAME)~g;s~DEPLOYGROUPNAME~$(printf $DEPLOYGROUPNAME)~g;s~TGNAME1~$(printf $TGNAME1)~g;s~TGNAME2~$(printf $TGNAME2)~g;s~LISTENERARN~$(printf $LISTENERARN)~g;s~SERVICEROLE~$(printf $SERVICEROLE)~g;s~CLUSTERNAME~$(printf $CLUSTERNAME)~g;s~SERVICENAME~$(printf $SERVICENAME)~g;" deploymentgroup.json > $DEPLOYGROUP.json
else
    echo "Port $PORT is not support in this project"
fi


