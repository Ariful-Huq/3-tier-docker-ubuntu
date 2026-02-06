# HTTPS Setup with Certbot, AWS ACM, and ELB

## BMI Health Tracker - Complete HTTPS Configuration Guide

This guide covers setting up HTTPS for **bmi.ostaddevops.click** using:
1. **Certbot** on EC2 to generate Let's Encrypt certificates
2. **AWS ACM** (Certificate Manager) to store certificates
3. **Application Load Balancer (ALB)** for SSL termination
4. **Route53** for DNS management

---

## Architecture Overview

```
Internet (HTTPS:443)
    ↓
Application Load Balancer (SSL Termination)
    ↓ (HTTP:80)
EC2 Instance (Docker Containers)
    ↓
Frontend → Backend → Database
```

**Benefits:**
- SSL/TLS termination at ALB (EC2 doesn't handle SSL)
- Easy certificate renewal with auto-sync to ACM
- Scalability (can add more EC2 instances to target group)
- AWS-managed infrastructure

---

## Prerequisites

- ✅ EC2 instance with Docker containers running (HTTP on port 80)
- ✅ Domain name: **bmi.ostaddevops.click**
- ✅ Route53 hosted zone for **ostaddevops.click**
- ✅ IAM role attached to EC2 with ACM permissions

---

## Part 1: Install Certbot on EC2

### Step 1: Connect to EC2

```bash
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

### Step 2: Install Certbot and AWS CLI

```bash
# Update system
sudo apt-get update -y

# Install Certbot
sudo apt-get install -y certbot

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt-get install -y unzip
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Verify installations
certbot --version
aws --version
```

---

## Part 2: Configure EC2 IAM Role for ACM

### Step 3: Create IAM Policy for Certificate Upload

**In AWS Console:**

1. Go to **IAM → Policies → Create Policy**
2. Choose **JSON** tab
3. Paste this policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "acm:ImportCertificate",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "acm:GetCertificate",
                "acm:AddTagsToCertificate"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:AddTagsToResource"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/certbot/*"
        }
    ]
}
```

4. Name: `CertbotACMUploadPolicy`
5. Click **Create policy**

### Step 4: Attach Policy to EC2 Instance Role

1. Go to **EC2 → Instances → Select your instance**
2. **Actions → Security → Modify IAM role**
3. If no role exists, create one:
   - Go to **IAM → Roles → Create Role**
   - Select **AWS Service → EC2**
   - Attach: `CertbotACMUploadPolicy`
   - Name: `EC2-Certbot-ACM-Role`
4. Attach the role to your EC2 instance
5. Reboot instance or wait a few minutes for role to take effect

### Step 5: Verify IAM Role on EC2

```bash
# Check if role is attached
aws sts get-caller-identity

# Test ACM access
aws acm list-certificates --region us-east-1
```

**Note:** ACM certificates for ALB must be in `us-east-1` region (or your ALB region)

---

## Part 3: Generate SSL Certificate with Certbot

### Step 6: Stop Frontend Container (Temporarily)

Certbot needs port 80 for verification:

```bash
cd ~/3-tier-docker-ubuntu/deployDocker
source .env
docker stop $CONTAINER_FRONTEND
```

### Step 7: Generate Certificate

```bash
sudo certbot certonly --standalone \
  --preferred-challenges http \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  -d bmi.ostaddevops.click
```

**Important:** Replace `your-email@example.com` with your actual email.

**Expected output:**

```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/bmi.ostaddevops.click/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/bmi.ostaddevops.click/privkey.pem
```

### Step 8: Verify Certificate Files

```bash
sudo ls -la /etc/letsencrypt/live/bmi.ostaddevops.click/
```

**You should see:**
- `cert.pem` - Certificate
- `chain.pem` - Certificate chain
- `fullchain.pem` - Full certificate chain (cert + chain)
- `privkey.pem` - Private key

### Step 9: Restart Frontend Container

```bash
docker start $CONTAINER_FRONTEND
```

---

## Part 4: Export Certificate to AWS ACM

### Step 10: Run Certificate Export Script

```bash
cd ~/3-tier-docker-ubuntu/deployDocker
chmod +x export-cert-to-acm.sh
sudo ./export-cert-to-acm.sh
```

**The script will:**
1. Read certificate files from Certbot
2. Upload certificate to ACM
3. Store certificate ARN in SSM Parameter Store
4. Tag certificate with domain name

**Expected output:**

```
Exporting certificate for: bmi.ostaddevops.click
Certificate imported to ACM successfully!
Certificate ARN: arn:aws:acm:us-east-1:123456789012:certificate/abc123...
```

### Step 11: Verify Certificate in ACM

**AWS Console:**
1. Go to **AWS Certificate Manager (ACM)**
2. Select region: **us-east-1** (or your region)
3. You should see: **bmi.ostaddevops.click** with status **Issued**

**CLI:**

```bash
aws acm list-certificates --region us-east-1
```

---

## Part 5: Create Application Load Balancer

### Step 12: Create Target Group

**AWS Console:**

1. Go to **EC2 → Target Groups → Create target group**
2. **Choose target type**: Instances
3. **Target group name**: `bmi-health-tg`
4. **Protocol**: HTTP
5. **Port**: 80
6. **VPC**: Select your VPC
7. **Health check settings**:
   - **Protocol**: HTTP
   - **Path**: `/health`
   - **Port**: 80
   - **Healthy threshold**: 2
   - **Unhealthy threshold**: 3
   - **Timeout**: 5 seconds
   - **Interval**: 30 seconds
   - **Success codes**: 200
8. Click **Next**
9. **Register targets**: Select your EC2 instance
10. Click **Include as pending below**
11. Click **Create target group**

### Step 13: Create Application Load Balancer

**AWS Console:**

1. Go to **EC2 → Load Balancers → Create Load Balancer**
2. Select **Application Load Balancer**
3. **Basic configuration**:
   - **Name**: `bmi-health-alb`
   - **Scheme**: Internet-facing
   - **IP address type**: IPv4
4. **Network mapping**:
   - **VPC**: Select your VPC
   - **Mappings**: Select at least 2 availability zones
5. **Security groups**:
   - Create new security group: `bmi-alb-sg`
   - **Inbound rules**:
     - HTTP (80) from 0.0.0.0/0
     - HTTPS (443) from 0.0.0.0/0
6. **Listeners**:
   - **Listener 1**: HTTP:80
     - **Default action**: Redirect to HTTPS:443
   - **Listener 2**: HTTPS:443
     - **Default action**: Forward to `bmi-health-tg`
     - **Security policy**: ELBSecurityPolicy-TLS13-1-2-2021-06
     - **Certificate**: Select `bmi.ostaddevops.click` from ACM
7. Click **Create load balancer**

### Step 14: Configure HTTP to HTTPS Redirect

**After ALB is created:**

1. Go to **Load Balancers → Select `bmi-health-alb`**
2. **Listeners** tab
3. Select **HTTP:80 listener**
4. **Actions → Edit listener**
5. **Default actions**:
   - Remove existing action
   - **Add action → Redirect to...**
   - **Protocol**: HTTPS
   - **Port**: 443
   - **Status code**: 301 - Permanently moved
6. Click **Save**

---

## Part 6: Update EC2 Security Group

### Step 15: Modify EC2 Security Group

**AWS Console:**

1. Go to **EC2 → Instances → Select your instance**
2. **Security** tab → Click on Security Group
3. **Inbound rules → Edit inbound rules**
4. **Remove** existing rule for port 80 from 0.0.0.0/0
5. **Add rule**:
   - **Type**: HTTP
   - **Port**: 80
   - **Source**: Custom → Select `bmi-alb-sg` (ALB security group)
   - **Description**: Allow traffic from ALB only
6. **Keep** SSH rule (port 22) for your management
7. Click **Save rules**

**Result:** EC2 only accepts traffic from ALB, not directly from internet.

---

## Part 7: Configure Route53 DNS

### Step 16: Create/Update DNS Record

**AWS Console:**

1. Go to **Route53 → Hosted zones**
2. Select **ostaddevops.click**
3. Click **Create record**
4. **Record configuration**:
   - **Record name**: `bmi`
   - **Record type**: A - IPv4 address
   - **Alias**: Yes
   - **Route traffic to**: Alias to Application Load Balancer
   - **Region**: Select your region
   - **Load balancer**: Select `bmi-health-alb`
   - **Routing policy**: Simple routing
5. Click **Create records**

### Step 17: Wait for DNS Propagation

```bash
# Check DNS resolution
nslookup bmi.ostaddevops.click

# Or
dig bmi.ostaddevops.click
```

**Wait time:** 5-10 minutes for DNS propagation

---

## Part 8: Test HTTPS Setup

### Step 18: Verify Application

**Browser test:**

1. Open: `https://bmi.ostaddevops.click`
2. Check for:
   - ✅ Padlock icon (secure connection)
   - ✅ Application loads correctly
   - ✅ No certificate warnings
3. Try: `http://bmi.ostaddevops.click`
   - Should redirect to HTTPS

**Certificate verification:**

```bash
# Check certificate details
openssl s_client -connect bmi.ostaddevops.click:443 -servername bmi.ostaddevops.click < /dev/null 2>/dev/null | openssl x509 -noout -text

# Quick check
curl -I https://bmi.ostaddevops.click
```

### Step 19: Test Health Check

```bash
# Health check endpoint (through ALB)
curl https://bmi.ostaddevops.click/health

# Expected: {"status":"ok"}
```

**AWS Console:**
1. Go to **EC2 → Target Groups → bmi-health-tg**
2. **Targets** tab
3. Health status should be **healthy**

---

## Part 9: Certificate Auto-Renewal

### Step 20: Create Renewal Script

```bash
cd ~/3-tier-docker-ubuntu/deployDocker
nano renew-certificate.sh
```

**Content:**

```bash
#!/bin/bash

# Stop frontend for renewal
docker stop frontend-web

# Renew certificate
certbot renew --quiet

# Restart frontend
docker start frontend-web

# Export to ACM
/home/ubuntu/3-tier-docker-ubuntu/deployDocker/export-cert-to-acm.sh

echo "Certificate renewal completed: $(date)"
```

**Make executable:**

```bash
chmod +x renew-certificate.sh
```

### Step 21: Set Up Cron Job for Auto-Renewal

```bash
sudo crontab -e
```

**Add this line (runs every day at 2 AM):**

```cron
0 2 * * * /home/ubuntu/3-tier-docker-ubuntu/deployDocker/renew-certificate.sh >> /var/log/certbot-renewal.log 2>&1
```

**Note:** Certbot only renews certificates within 30 days of expiry.

### Step 22: Test Renewal Process

```bash
# Dry run (doesn't actually renew)
sudo certbot renew --dry-run
```

**Expected:** All renewals succeeded

---

## Part 10: Update Backend CORS Configuration

### Step 23: Update .env File

```bash
cd ~/3-tier-docker-ubuntu/deployDocker
nano .env
```

**Change:**

```bash
FRONTEND_URL=https://bmi.ostaddevops.click
```

**Restart backend:**

```bash
source .env
docker restart $CONTAINER_BACKEND
```

---

## Troubleshooting

### Certificate Not Showing in ACM

```bash
# Check certificate was imported
aws acm list-certificates --region us-east-1

# View export script logs
sudo ./export-cert-to-acm.sh
```

### ALB Health Check Failing

```bash
# Test health endpoint on EC2
curl http://localhost/health

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# View backend logs
docker logs backend-api
```

### DNS Not Resolving

```bash
# Check Route53 record
aws route53 list-resource-record-sets --hosted-zone-id <zone-id> | grep bmi

# Wait for DNS propagation (up to 48 hours, usually 5-10 minutes)
dig bmi.ostaddevops.click

# Clear local DNS cache
sudo systemd-resolve --flush-caches
```

### Certificate Renewal Fails

```bash
# Manual renewal test
sudo certbot renew --dry-run

# Check if port 80 is blocked
docker ps | grep frontend-web

# Stop frontend temporarily for renewal
docker stop frontend-web
sudo certbot renew
docker start frontend-web
```

### ALB Returns 502 Bad Gateway

```bash
# Check if EC2 security group allows ALB
aws ec2 describe-security-groups --group-ids <ec2-sg-id>

# Verify containers are running
docker ps

# Check backend health
docker logs backend-api
curl http://localhost:3000/health
```

---

## Architecture Summary

```
User Browser
    ↓ (HTTPS:443)
Route53: bmi.ostaddevops.click
    ↓
Application Load Balancer
  ├─ HTTPS:443 Listener (ACM Certificate)
  │  └─ Forward to Target Group
  └─ HTTP:80 Listener
     └─ Redirect to HTTPS:443
    ↓ (HTTP:80 - internal)
Target Group
    ↓
EC2 Security Group (allow only from ALB)
    ↓
EC2 Instance
  ├─ Frontend Container (nginx:80)
  ├─ Backend Container (node:3000)
  └─ Database Container (postgres:5432)
```

---

## Cost Considerations

**AWS Resources:**
- **ALB**: ~$16-25/month (plus data transfer)
- **ACM**: Free (AWS-managed certificates)
- **Route53**: ~$0.50/month per hosted zone + queries
- **EC2**: Depends on instance type
- **Data transfer**: Varies by usage

**Let's Encrypt:**
- Free SSL certificates
- 90-day validity (auto-renewed)

---

## Security Best Practices

1. ✅ **SSL/TLS termination at ALB** (EC2 doesn't handle SSL)
2. ✅ **EC2 only accepts traffic from ALB** (security group restriction)
3. ✅ **Strong SSL policy** (TLS 1.3 recommended)
4. ✅ **HTTP to HTTPS redirect** (enforce encryption)
5. ✅ **Regular certificate renewal** (automated with cron)
6. ✅ **Private key security** (never commit to Git)
7. ✅ **IAM role permissions** (least privilege principle)

---

## Maintenance Checklist

- [ ] Monitor certificate expiry (Let's Encrypt emails you)
- [ ] Check cron job logs: `/var/log/certbot-renewal.log`
- [ ] Verify ACM certificate status monthly
- [ ] Test application after certificate renewal
- [ ] Monitor ALB access logs (optional but recommended)
- [ ] Review security group rules quarterly
- [ ] Update Certbot: `sudo apt-get update && sudo apt-get upgrade certbot`

---

## Additional Resources

- **Let's Encrypt**: https://letsencrypt.org/
- **Certbot Documentation**: https://eff-certbot.readthedocs.io/
- **AWS ACM**: https://docs.aws.amazon.com/acm/
- **AWS ALB**: https://docs.aws.amazon.com/elasticloadbalancing/
- **Route53**: https://docs.aws.amazon.com/route53/

---

## Quick Reference Commands

```bash
# List certificates
sudo certbot certificates

# Manual renewal
sudo certbot renew

# Check certificate expiry
echo | openssl s_client -connect bmi.ostaddevops.click:443 2>/dev/null | openssl x509 -noout -dates

# View ACM certificates
aws acm list-certificates --region us-east-1

# Check ALB status
aws elbv2 describe-load-balancers --names bmi-health-alb

# View target health
aws elbv2 describe-target-health --target-group-arn <arn>

# Test HTTPS
curl -I https://bmi.ostaddevops.click
```

---

**HTTPS Setup Complete!** 🔒

Your BMI Health Tracker is now secured with SSL/TLS encryption via AWS Application Load Balancer and Let's Encrypt certificates.

Access your application at: **https://bmi.ostaddevops.click**

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
