#!/bin/bash 

REGION=ap-south-1

VPC_CIDR=10.0.0.0/16
SUBNET_CIDR=("10.0.1.0/24" "10.0.2.0/24")
PUBLIC_SUBNETS=1
KEY_PAIR=my_key

SUBNET_IDS=() 


function create_vpc(){
    VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query Vpc.VpcId --output text --region=$REGION)
    echo $VPC_CIDR
    echo $VPC_ID
}

function create_subnet(){
    for subnet in ${SUBNET_CIDR[*]}
    do
        SUBNET_IDS+="$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $subnet --output text --query "Subnet.SubnetId" ; echo " " )"
        echo $subnet 
        echo $SUBNET_IDS
    done 
}


function create_igw(){
    IGW=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --region=$REGION --output text)
    echo $IGW

    # Attach IGW to the VPC
    aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW
}

function create_route_table(){
    ROUTE_TABLE=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text)
    echo $ROUTE_TABLE

    #Create route in route table to enable internet access
    aws ec2 create-route --route-table-id $ROUTE_TABLE --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW
}

function create_public_subnets(){
    for ((i=0; i<$PUBLIC_SUBNETS; i++))
    do 
        echo $i
        ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[$i].SubnetId" --output text)
        aws ec2 associate-route-table  --subnet-id $ID --route-table-id $ROUTE_TABLE
        aws ec2 modify-subnet-attribute --subnet-id $ID --map-public-ip-on-launch
        echo $ID
    done 
}

function create_key_pair(){
    aws ec2 create-key-pair --key-name $KEY_PAIR --query "KeyMaterial" --output text > $KEY_PAIR.pem
    chmod 400 $KEY_PAIR.pem
}

function create_sg(){
    SG=$(aws ec2 create-security-group --group-name SSHAccess --description "Security group for SSH access" --vpc-id $VPC_ID --output text)
    aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 22 --cidr 0.0.0.0/0
    echo $SG

}

function create_ec2(){
    for subnet in ${SUBNET_CIDR[*]}
    do
        ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[$i].SubnetId" --output text)

        aws ec2 run-instances --image-id ami-074dc0a6f6c764218 \
        --count 1 --instance-type t2.micro --key-name $KEY_PAIR \
        --security-group-ids $SG --subnet-id $ID
    done 
}


create_vpc
create_subnet
create_igw
create_route_table
create_public_subnets
create_key_pair
create_sg
create_ec2


