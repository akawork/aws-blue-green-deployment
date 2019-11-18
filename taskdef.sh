TASKNAME=${1?:Error: task name is required}
ECRIMAGE=${2?:Error: ECR image id is required}
TASKROLE=${3:-arn:aws:iam::729713917879:role/ecsTaskExecutionRole}
EXECUTIONROLE=${4:-arn:aws:iam::729713917879:role/ecsTaskExecutionRole}
PORT=${5?:Error: PORT is required}
PORTPROTOCOL=${6?:Error: PORT Protocol is required}
DBENDPOINT=${7?:Error: DB endpoint is required}
DBUSERNAME=${8?:Error: DB username is required}
DBPASSWORD=${9?:Error: DB password is required}
AWSLOGGROUP=${10?:Error: Log group name is required}
AWSREGION=${11?:Error: AWS region is required}
MICROSERVICE=${12?:Error: defining microservice is required}
TASKDEFFILE=${13?:Error: task def filename is required}
PRODUCTENDPOINT=${14:-}

if [[ $MICROSERVICE =~ ^(product|order|frontend)$ ]]; then
	if [ $MICROSERVICE == "product" ]; then
		TASKENVIRONMENT='"environment":[{"name":"DB_HOST","value":"'"$DBENDPOINT"'"},{"name":"DB_USERNAME","value":"'"$DBUSERNAME"'"},{"name":"DB_PASSWORD","value":"'"$DBPASSWORD"'"}],'
	elif [ $MICROSERVICE == "order" ]; then
		TASKENVIRONMENT='"environment":[{"name":"DB_HOST","value":"'"$DBENDPOINT"'"},{"name":"DB_USERNAME","value":"'"$DBUSERNAME"'"},{"name":"DB_PASSWORD","value":"'"$DBPASSWORD"'"},{"name":"PRODUCT_ENDPOINT","value":"'"$PRODUCTENDPOINT"'"}],'
	else
		TASKENVIRONMENT=""
	fi
	if [[ $PORT =~ ^(9002|9001|80|443)$ ]]; then
		sed "s~TASKNAME~$(printf $TASKNAME)~g;s~TASKROLE~$(printf $TASKROLE)~g;s~EXECUTIONROLE~$(printf $EXECUTIONROLE)~g;s~ECRIMAGE~$(printf $ECRIMAGE)~g;s~PORT~$(printf $PORT)~g;s~TASKENVIRONMENT~$TASKENVIRONMENT~g;s~AWSLOGGROUP~$(printf $AWSLOGGROUP)~g;s~AWSREGION~$(printf $AWSREGION)~g;s~PortProtocol~$(printf $PORTPROTOCOL)~g;" taskdef.json > $TASKDEFFILE.json
	else
		echo "Port $PORT is not support in this project"
	fi
else
	echo "Thic script only support 3 microservices (product|order|frontend)"
fi


