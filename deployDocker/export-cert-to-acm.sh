#!/bin/bash

#############################################
# Export Let's Encrypt Certificate to AWS ACM
# Automatically uploads Certbot certificates to ACM
#############################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="bmi.ostaddevops.click"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
REGION="us-east-1"  # ACM region (change if needed)
SSM_PARAM_NAME="/certbot/certificates/$DOMAIN/arn"

echo "=========================================="
echo "Certificate Export to AWS ACM"
echo "=========================================="
echo ""
echo "Domain: $DOMAIN"
echo "Region: $REGION"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (sudo)${NC}"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed!${NC}"
    echo "Install with: curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\" && unzip awscliv2.zip && sudo ./aws/install"
    exit 1
fi

# Check if certificate files exist
if [ ! -d "$CERT_DIR" ]; then
    echo -e "${RED}Error: Certificate directory not found: $CERT_DIR${NC}"
    echo "Run Certbot first: sudo certbot certonly --standalone -d $DOMAIN"
    exit 1
fi

echo "Checking certificate files..."

CERT_FILE="$CERT_DIR/cert.pem"
CHAIN_FILE="$CERT_DIR/chain.pem"
PRIVKEY_FILE="$CERT_DIR/privkey.pem"

if [ ! -f "$CERT_FILE" ]; then
    echo -e "${RED}Error: Certificate file not found: $CERT_FILE${NC}"
    exit 1
fi

if [ ! -f "$CHAIN_FILE" ]; then
    echo -e "${RED}Error: Chain file not found: $CHAIN_FILE${NC}"
    exit 1
fi

if [ ! -f "$PRIVKEY_FILE" ]; then
    echo -e "${RED}Error: Private key file not found: $PRIVKEY_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All certificate files found${NC}"

# Check AWS credentials
echo ""
echo "Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured or invalid!${NC}"
    echo "Configure AWS CLI with: aws configure"
    echo "Or ensure EC2 instance has proper IAM role attached."
    exit 1
fi

echo -e "${GREEN}✓ AWS credentials valid${NC}"

# Read certificate files
echo ""
echo "Reading certificate files..."

CERT_BODY=$(cat "$CERT_FILE")
CERT_CHAIN=$(cat "$CHAIN_FILE")
CERT_KEY=$(cat "$PRIVKEY_FILE")

# Check if certificate already exists in ACM
echo ""
echo "Checking for existing certificate in ACM..."

EXISTING_CERT_ARN=$(aws ssm get-parameter --name "$SSM_PARAM_NAME" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_CERT_ARN" ] && [ "$EXISTING_CERT_ARN" != "None" ]; then
    echo -e "${YELLOW}Found existing certificate: $EXISTING_CERT_ARN${NC}"
    echo "Checking if certificate is still valid in ACM..."
    
    if aws acm describe-certificate --certificate-arn "$EXISTING_CERT_ARN" --region "$REGION" &> /dev/null; then
        echo "Re-importing certificate (updating existing)..."
        
        # Re-import to update certificate
        aws acm import-certificate \
            --certificate fileb://<(echo "$CERT_BODY") \
            --certificate-chain fileb://<(echo "$CERT_CHAIN") \
            --private-key fileb://<(echo "$CERT_KEY") \
            --certificate-arn "$EXISTING_CERT_ARN" \
            --region "$REGION" \
            > /dev/null
        
        CERT_ARN="$EXISTING_CERT_ARN"
        echo -e "${GREEN}✓ Certificate updated in ACM${NC}"
    else
        echo -e "${YELLOW}Existing certificate not found in ACM. Importing as new...${NC}"
        EXISTING_CERT_ARN=""
    fi
fi

# Import new certificate if no existing one
if [ -z "$EXISTING_CERT_ARN" ]; then
    echo "Importing new certificate to ACM..."
    
    IMPORT_OUTPUT=$(aws acm import-certificate \
        --certificate fileb://<(echo "$CERT_BODY") \
        --certificate-chain fileb://<(echo "$CERT_CHAIN") \
        --private-key fileb://<(echo "$CERT_KEY") \
        --tags Key=Domain,Value="$DOMAIN" Key=ManagedBy,Value=Certbot \
        --region "$REGION" \
        --output json)
    
    CERT_ARN=$(echo "$IMPORT_OUTPUT" | grep -oP '"CertificateArn":\s*"\K[^"]+')
    
    echo -e "${GREEN}✓ Certificate imported to ACM${NC}"
fi

# Store certificate ARN in SSM Parameter Store
echo ""
echo "Storing certificate ARN in SSM Parameter Store..."

aws ssm put-parameter \
    --name "$SSM_PARAM_NAME" \
    --value "$CERT_ARN" \
    --type String \
    --overwrite \
    --region "$REGION" \
    --tags Key=Domain,Value="$DOMAIN" \
    > /dev/null

echo -e "${GREEN}✓ Certificate ARN stored in SSM${NC}"

# Get certificate details
echo ""
echo "Certificate Details:"
echo "===================="

CERT_INFO=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$REGION" --output json)

NOT_BEFORE=$(echo "$CERT_INFO" | grep -oP '"NotBefore":\s*"\K[^"]+' | head -1)
NOT_AFTER=$(echo "$CERT_INFO" | grep -oP '"NotAfter":\s*"\K[^"]+' | head -1)
STATUS=$(echo "$CERT_INFO" | grep -oP '"Status":\s*"\K[^"]+' | head -1)

echo "  ARN: $CERT_ARN"
echo "  Domain: $DOMAIN"
echo "  Status: $STATUS"
echo "  Valid From: $NOT_BEFORE"
echo "  Valid Until: $NOT_AFTER"
echo "  Region: $REGION"

# Calculate days until expiry
if command -v date &> /dev/null; then
    EXPIRY_DATE=$(date -d "$NOT_AFTER" +%s 2>/dev/null || echo "")
    CURRENT_DATE=$(date +%s)
    
    if [ -n "$EXPIRY_DATE" ]; then
        DAYS_REMAINING=$(( ($EXPIRY_DATE - $CURRENT_DATE) / 86400 ))
        echo "  Days Remaining: $DAYS_REMAINING"
        
        if [ $DAYS_REMAINING -lt 30 ]; then
            echo -e "  ${YELLOW}⚠️  Certificate expires in less than 30 days!${NC}"
        fi
    fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Certificate Export Complete!${NC}"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Configure Application Load Balancer to use this certificate"
echo "2. Go to: AWS Console → EC2 → Load Balancers"
echo "3. Add HTTPS:443 listener with certificate: $DOMAIN"
echo ""
echo "Certificate ARN (for ALB configuration):"
echo "$CERT_ARN"
echo ""
echo "To retrieve ARN later:"
echo "  aws ssm get-parameter --name $SSM_PARAM_NAME --region $REGION --query 'Parameter.Value' --output text"
echo ""

# Create a helper file with the ARN
echo "$CERT_ARN" > /tmp/acm_certificate_arn.txt
echo "Certificate ARN also saved to: /tmp/acm_certificate_arn.txt"
echo ""
