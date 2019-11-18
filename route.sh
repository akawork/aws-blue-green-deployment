#!/bin/bash
echo "=====================Installation Started======================"
source config.sh
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
