#!/bin/bash 

#Specify required region to deploy resources
REGION=ap-south-1

#Mention VPC CIDR range
VPC_CIDR=10.0.0.0/16

#Provide Name to identify VPC
VPC_NAME=vpc_from_cli

#Mention subnte CIDR ranges to deploy
SUBNET_CIDR=("10.0.1.0/24" "10.0.2.0/24")

#Specify the availability zone of subnets in the corresponding order
AVAILABILITY_ZONE=("ap-south-1a" "ap-south-1b")

#Add names of subnets
SUBNET_NAME=("web-public" "db-private")

#Specify number of piublic subnets
PUBLIC_SUBNET_COUNT=1

#Name of key pair; If using existing keypair, refer to the function call `create_key_pair` in the bottom of the script
KEY_PAIR=my_new_key

# specify Internet gateway name
IGW_NAME=IgwFromCli

#Route table name tag
ROUTE_TABLE_NAME=RouteTableFromCli

#Mention Security Group Name
SECURITY_GROUP_NAME=SgFromCli

#Add ports to open in security group
INGRESS_PORT=("22" "80" "443" "3306")

#AMI id 
AMI_ID=ami-074dc0a6f6c764218

#Name tags for EC2 instances, names of instances with public IP should be first 
EC2_NAME=("WebServer" "DBServer")

#Name tag for EC2 root volume
VOL_NAME=rootVol-ec2FromCli

#Program will collect the data, avoid inserting data inside the array
SUBNET_IDS=() 

#Calculate number of subnets
SUBNET_COUNT=${#SUBNET_CIDR[@]}


#Create VPC in specified region
function create_vpc(){
    echo "Creating VPC $VPC_NAME"
    VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query Vpc.VpcId --output text --region=$REGION \
        --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value="'"$VPC_NAME"'"}]')
    echo "VPC $VPC_NAME created"
}

#Create subnets
function create_subnet(){
    echo "Creating Subnets"
    for ((i=0; i < $SUBNET_COUNT; i++))
        do
        echo "Creating subnet ${SUBNET_NAME[$i]}"
        SUBNET_IDS[$i]=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${SUBNET_CIDR[$i]} \
            --output text --query "Subnet.SubnetId" --availability-zone ${AVAILABILITY_ZONE[$i]} \
            --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value="'"${SUBNET_NAME[$i]}"'"}]')
        echo "Subnet ${SUBNET_NAME[$i]} Created "
        done 
    echo "Subnets created"
}

#Create Internet Gateway and attach to VPC 
function create_igw(){
    echo "Creating Internet Gateway"
    IGW=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --region=$REGION --output text \
        --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value="'"$IGW_NAME"'"}]')
    echo "Created Internet Gateway $IGW_NAME"

    # Attach IGW to the VPC
    echo "Attaching Internet Gateway to the VPC"
    aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW
    echo "Attached Internet Gateway $IGW_NAME to the VPC $VPC_NAME"
}

#Create a route table to avail internet access for subnets
function create_route_table(){
    echo "Creating Route table"
    ROUTE_TABLE=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text \
        --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value="'"$ROUTE_TABLE_NAME"'"}]')
    echo "Route table created"
    #Create route in route table to enable internet access
    aws ec2 create-route --route-table-id $ROUTE_TABLE --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW
    echo "Created route table entry for internet access"
}

#Create public subnets
function create_public_subnets(){
    echo "Creating public subnet[s]"
    for ((i=0; i<$PUBLIC_SUBNET_COUNT; i++))
        do 
        aws ec2 associate-route-table  --subnet-id ${SUBNET_IDS[$i]} --route-table-id $ROUTE_TABLE
        aws ec2 modify-subnet-attribute --subnet-id ${SUBNET_IDS[$i]} --map-public-ip-on-launch
        done 
    echo "Public subnet[s] created"
}

#Create key pair and set pem file permissions
function create_key_pair(){
    echo "Creating Key Pair"
    aws ec2 create-key-pair --key-name $KEY_PAIR --query "KeyMaterial" --output text > $KEY_PAIR.pem
    chmod 400 $KEY_PAIR.pem
    echo "Created key-pair: $KEY_PAIR.pem"
}

#Create security group
function create_sg(){
    echo "Creating Security Groups"
    SG_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME \
        --description $SECURITY_GROUP_NAME \
        --vpc-id $VPC_ID --output text --query GroupId \
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value="'"$SECURITY_GROUP_NAME"'"}]')
    echo "Security Group $SECURITY_GROUP_NAME created"
}

#Add rules to security group
function add_sg_rules(){
    echo "Adding rules to Security Group"
    for port in ${INGRESS_PORT[@]}
        do 
        aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port $port --cidr 0.0.0.0/0
        done
    echo "Rules added to Security Group"
}

#Create EC2 instance
function create_ec2(){
    echo "Creating EC2 instances"
    for ((i=0; i < $SUBNET_COUNT; i++))
        do
        echo "Creating EC2 instance ${EC2_NAME[$i]}"
        aws ec2 run-instances --image-id $AMI_ID \
        --count 1 --instance-type t2.micro --key-name $KEY_PAIR \
        --security-group-ids $SG_ID --subnet-id ${SUBNET_IDS[$i]} \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="'"${EC2_NAME[$i]}"'"}]' \
        'ResourceType=volume,Tags=[{Key=Name,Value="'"$VOL_NAME"'"}]'
        echo "EC2 instance ${EC2_NAME[$i]} created"
        done 
    echo "EC2 instance creation complete"
}



#DEPLOYMENT starts here:

# Create a key pair and save it to KEY_PAIR.pem file. Comment the below line if you are using existing key pairs. 
create_key_pair

create_vpc
create_subnet
create_igw
create_route_table
create_public_subnets
create_sg
add_sg_rules
create_ec2



