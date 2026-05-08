#!/bin/bash
# TravelEase AWS Infrastructure Setup
# 100% free tier - run this once

set -e  # Exit on any error
echo "🚀 Setting up TravelEase AWS Infrastructure..."

# ─── VARIABLES ───────────────────────────────────────────────
AWS_REGION="us-east-1"
PROJECT="travelease"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"

# ─── STEP 1: VPC ─────────────────────────────────────────────
echo "📦 Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $AWS_REGION \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 create-tags --resources $VPC_ID \
  --tags Key=Name,Value=$PROJECT-vpc Key=Project,Value=$PROJECT

# Enable DNS hostnames (required for RDS)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support

echo "✅ VPC created: $VPC_ID"

# ─── STEP 2: SUBNETS ─────────────────────────────────────────
echo "🔗 Creating subnets..."
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone ${AWS_REGION}a \
  --query 'Subnet.SubnetId' \
  --output text)

PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone ${AWS_REGION}b \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags --resources $PUBLIC_SUBNET_ID \
  --tags Key=Name,Value=$PROJECT-public-subnet
aws ec2 create-tags --resources $PRIVATE_SUBNET_ID \
  --tags Key=Name,Value=$PROJECT-private-subnet

echo "✅ Public subnet: $PUBLIC_SUBNET_ID"
echo "✅ Private subnet: $PRIVATE_SUBNET_ID"

# ─── STEP 3: INTERNET GATEWAY ────────────────────────────────
echo "🌐 Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID

aws ec2 create-tags --resources $IGW_ID \
  --tags Key=Name,Value=$PROJECT-igw

echo "✅ Internet Gateway: $IGW_ID"

# ─── STEP 4: ROUTE TABLES ────────────────────────────────────
echo "🗺️ Configuring route tables..."
PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Route all internet traffic through IGW
aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table \
  --route-table-id $PUBLIC_RT_ID \
  --subnet-id $PUBLIC_SUBNET_ID

aws ec2 create-tags --resources $PUBLIC_RT_ID \
  --tags Key=Name,Value=$PROJECT-public-rt

echo "✅ Route tables configured"

# ─── STEP 5: SECURITY GROUPS ─────────────────────────────────
echo "🔒 Creating security groups..."

# Web security group (public facing)
WEB_SG_ID=$(aws ec2 create-security-group \
  --group-name $PROJECT-web-sg \
  --description "Allow HTTP, HTTPS, SSH" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow HTTPS (443) from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG_ID \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

# Allow HTTP (80) - redirects to HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# Allow SSH from your IP only (more secure)
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG_ID \
  --protocol tcp --port 22 --cidr $MY_IP/32

echo "✅ Web security group: $WEB_SG_ID (SSH locked to $MY_IP)"

# App security group (private - only accepts traffic from web SG)
APP_SG_ID=$(aws ec2 create-security-group \
  --group-name $PROJECT-app-sg \
  --description "Allow traffic from web tier only" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $APP_SG_ID \
  --protocol tcp --port 3001-3003 \
  --source-group $WEB_SG_ID

echo "✅ App security group: $APP_SG_ID"

# DB security group (only accepts traffic from app SG)
DB_SG_ID=$(aws ec2 create-security-group \
  --group-name $PROJECT-db-sg \
  --description "Allow PostgreSQL from app tier only" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $DB_SG_ID \
  --protocol tcp --port 5432 \
  --source-group $APP_SG_ID

echo "✅ DB security group: $DB_SG_ID"

# ─── STEP 6: ECR REPOSITORIES ────────────────────────────────
echo "🐳 Creating ECR repositories..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

for SERVICE in auth-service flight-service hotel-service; do
  aws ecr create-repository \
    --repository-name $PROJECT/$SERVICE \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    --query 'repository.repositoryUri' \
    --output text
  echo "✅ ECR repo created: $PROJECT/$SERVICE"
done

# ─── STEP 7: S3 BUCKET (Frontend) ────────────────────────────
echo "🪣 Creating S3 bucket for frontend..."
BUCKET_NAME="$PROJECT-frontend-$(date +%s)"

aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $AWS_REGION

# Enable static website hosting
aws s3 website s3://$BUCKET_NAME \
  --index-document index.html \
  --error-document index.html

# Block public access for CloudFront-only access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✅ S3 bucket: $BUCKET_NAME"

# ─── STEP 8: RDS SUBNET GROUP ────────────────────────────────
echo "🗄️ Creating RDS subnet group..."

# RDS needs a second AZ subnet
PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.3.0/24 \
  --availability-zone ${AWS_REGION}c \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags --resources $PRIVATE_SUBNET_2_ID \
  --tags Key=Name,Value=$PROJECT-private-subnet-2

aws rds create-db-subnet-group \
  --db-subnet-group-name $PROJECT-db-subnet-group \
  --db-subnet-group-description "TravelEase DB subnet group" \
  --subnet-ids $PRIVATE_SUBNET_ID $PRIVATE_SUBNET_2_ID

echo "✅ RDS subnet group created"

# ─── STEP 9: RDS POSTGRESQL (Free tier) ──────────────────────
echo "🗄️ Creating RDS PostgreSQL (free tier)..."

aws rds create-db-instance \
  --db-instance-identifier $PROJECT-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username travelease_admin \
  --master-user-password TravelEase@2025 \
  --allocated-storage 20 \
  --db-name travelease \
  --vpc-security-group-ids $DB_SG_ID \
  --db-subnet-group-name $PROJECT-db-subnet-group \
  --backup-retention-period 7 \
  --no-multi-az \
  --no-publicly-accessible \
  --storage-type gp2

echo "✅ RDS creating (takes ~5 mins)..."

# ─── STEP 10: SAVE ALL IDs ────────────────────────────────────
cat > ~/travelease/infrastructure/aws-resources.env << ENVEOF
# Auto-generated by setup-aws.sh — DO NOT commit to git
AWS_REGION=$AWS_REGION
VPC_ID=$VPC_ID
PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID
PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID
IGW_ID=$IGW_ID
WEB_SG_ID=$WEB_SG_ID
APP_SG_ID=$APP_SG_ID
DB_SG_ID=$DB_SG_ID
S3_BUCKET=$BUCKET_NAME
ACCOUNT_ID=$ACCOUNT_ID
ECR_REGISTRY=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
ENVEOF

echo ""
echo "✅ ════════════════════════════════════════"
echo "✅  TravelEase AWS Infrastructure Ready!"
echo "✅ ════════════════════════════════════════"
echo ""
cat ~/travelease/infrastructure/aws-resources.env
