# Manual Docker Deployment Guide

## BMI Health Tracker - Step-by-Step Deployment on AWS EC2 Ubuntu

This guide walks you through manually deploying the 3-tier BMI Health Tracker application using pure Docker commands (no docker-compose).

---

## Prerequisites

- **AWS EC2 Instance**: Fresh Ubuntu 22.04 LTS or later
- **Security Group**: Port 80 (HTTP) open to the internet (0.0.0.0/0)
- **SSH Access**: Key pair to connect to EC2 instance
- **Git Repository**: https://github.com/ariful-huq/3-tier-docker-ubuntu.git

---

## Part 1: Initial EC2 Setup

### Step 1: Connect to EC2

```bash
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

### Step 2: Update System

```bash
sudo apt-get update -y
sudo apt-get upgrade -y
```

### Step 3: Install Docker

```bash
# Install prerequisites
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes (or logout and login)
newgrp docker

# Verify installation
docker --version
docker info
```

### Step 4: Install Git (if not installed)

```bash
sudo apt-get install -y git
git --version
```

### Step 5: Clone the Repository

```bash
cd ~
git clone https://github.com/ariful-huq/3-tier-docker-ubuntu.git
cd 3-tier-docker-ubuntu
```

---

## Part 2: Configure Environment

### Step 6: Create .env File

```bash
cd ~/3-tier-docker-ubuntu/deployDocker
cp .env.example .env
nano .env  # or use vim
```

**Update these values in .env:**

```bash
# PostgreSQL Database Configuration
POSTGRES_DB=bmi_health_db
POSTGRES_USER=bmi_user
POSTGRES_PASSWORD=YOUR_STRONG_PASSWORD_HERE  # ⚠️ Change this!

# Backend Database Connection
DATABASE_URL=postgresql://bmi_user:YOUR_STRONG_PASSWORD_HERE@postgres-db:5432/bmi_health_db # ⚠️ Change this!

# Backend Server Configuration
PORT=3000
NODE_ENV=production

# CORS Configuration
FRONTEND_URL=http://<YOUR-EC2-PUBLIC-IP>  # ⚠️ Change this! Or use domain name

# Container Names
CONTAINER_DB=postgres-db
CONTAINER_BACKEND=backend-api
CONTAINER_FRONTEND=frontend-web

# Docker Network
NETWORK_NAME=bmi-health-network

# Docker Volume
VOLUME_NAME=postgres-data
```

**Save and exit** (Ctrl+X, then Y, then Enter in nano)

---

## Part 3: Manual Docker Deployment

### Step 7: Create Docker Network

```bash
docker network create bmi-health-network
```

**Verify:**

```bash
docker network ls | grep bmi-health-network
```

---

### Step 8: Create Docker Volume for Database

```bash
docker volume create postgres-data
```

**Verify:**

```bash
docker volume ls | grep postgres-data
```

---

### Step 9: Start PostgreSQL Database Container

```bash
cd ~/3-tier-docker-ubuntu

docker run -d \
  --name postgres-db \
  --network bmi-health-network \
  -e POSTGRES_DB=bmi_health_db \
  -e POSTGRES_USER=bmi_user \
  -e POSTGRES_PASSWORD=YOUR_STRONG_PASSWORD_HERE \
  -v $(pwd)/backend/migrations/001_create_measurements.sql:/docker-entrypoint-initdb.d/001_create_measurements.sql:ro \
  -v $(pwd)/backend/migrations/002_add_measurement_date.sql:/docker-entrypoint-initdb.d/002_add_measurement_date.sql:ro \
  -v postgres-data:/var/lib/postgresql/data \
  --restart unless-stopped \
  postgres:15-alpine
```

**Check if container is running:**

```bash
docker ps | grep postgres-db
```

**View database logs:**

```bash
docker logs postgres-db
```

Look for: `database system is ready to accept connections`

---

### Step 10: Wait for Database to Be Ready

```bash
# Wait 10-15 seconds, then test connection
sleep 15

docker exec postgres-db pg_isready -U bmi_user -d bmi_health_db
```

**Expected output:** `postgres-db:5432 - accepting connections`

---

### Step 11: Verify Database Migrations

```bash
docker exec postgres-db psql -U bmi_user -d bmi_health_db -c "\dt"
```

**Expected output:** Should show `measurements` table

```bash
docker exec postgres-db psql -U bmi_user -d bmi_health_db -c "\d measurements"
```

**Expected output:** Table structure with columns

---

### Step 12: Build Backend Docker Image

```bash
cd ~/3-tier-docker-ubuntu/backend

docker build -t bmi-backend:latest .
```

**Verify image:**

```bash
docker images | grep bmi-backend
```

---

### Step 13: Run Backend Container

```bash
docker run -d \
  --name backend-api \
  --network bmi-health-network \
  -e DATABASE_URL=postgresql://bmi_user:YOUR_STRONG_PASSWORD_HERE@postgres-db:5432/bmi_health_db \
  -e PORT=3000 \
  -e NODE_ENV=production \
  -e FRONTEND_URL=http://<YOUR-EC2-PUBLIC-IP> \
  --restart unless-stopped \
  bmi-backend:latest
```

**Check if container is running:**

```bash
docker ps | grep backend-api
```

**View backend logs:**

```bash
docker logs backend-api
```

Look for: `Server running on port 3000` and `Database connected successfully`

---

### Step 14: Test Backend Health Endpoint

```bash
docker exec backend-api wget -q -O- http://localhost:3000/health
```

**Expected output:** `{"status":"ok"}`

---

### Step 15: Build Frontend Docker Image

```bash
cd ~/3-tier-docker-ubuntu/frontend

docker build -t bmi-frontend:latest .
```

**Note:** This may take 3-5 minutes (npm install + build)

**Verify image:**

```bash
docker images | grep bmi-frontend
```

---

### Step 16: Run Frontend Container

```bash
docker run -d \
  --name frontend-web \
  --network bmi-health-network \
  -p 80:80 \
  --restart unless-stopped \
  bmi-frontend:latest
```

**Check if container is running:**

```bash
docker ps | grep frontend-web
```

**View frontend logs:**

```bash
docker logs frontend-web
```

---

### Step 17: Verify All Containers Are Running

```bash
docker ps --filter "name=postgres-db|backend-api|frontend-web"
```

**Expected output:** All 3 containers with status "Up"

---

### Step 18: Test Application

Open your browser and navigate to:

```
http://<EC2-PUBLIC-IP>
```

**You should see:** BMI Health Tracker application

---

## Part 4: Testing & Verification

### Test API Endpoint Directly (from EC2)

```bash
# Health check
curl http://localhost/health

# Get measurements (should return empty array initially)
curl http://localhost/api/measurements
```

### Test Database Connection

```bash
docker exec -it postgres-db psql -U bmi_user -d bmi_health_db

# In PostgreSQL prompt:
\dt                    # List tables
SELECT COUNT(*) FROM measurements;  # Count records
\q                     # Exit
```

### Check Container Logs

```bash
# Database logs
docker logs --tail 50 postgres-db

# Backend logs
docker logs --tail 50 backend-api

# Frontend logs
docker logs --tail 50 frontend-web

# Follow logs in real-time
docker logs -f backend-api
```

---

## Part 5: Container Management

### Stop All Containers

```bash
docker stop frontend-web backend-api postgres-db
```

### Start All Containers

```bash
docker start postgres-db
sleep 5
docker start backend-api
sleep 3
docker start frontend-web
```

### Restart a Single Container

```bash
docker restart backend-api
```

### Remove Containers (keeps data)

```bash
docker stop frontend-web backend-api postgres-db
docker rm frontend-web backend-api postgres-db
```

**Note:** Data persists in `postgres-data` volume

### Remove Everything Including Data

```bash
docker stop frontend-web backend-api postgres-db
docker rm frontend-web backend-api postgres-db
docker volume rm postgres-data
docker network rm bmi-health-network
docker rmi bmi-frontend:latest bmi-backend:latest
```

---

## Part 6: Data Backup & Restore

### Backup Database

```bash
# Create backup directory
mkdir -p ~/backups

# Dump database
docker exec postgres-db pg_dump -U bmi_user -d bmi_health_db > ~/backups/bmi_backup_$(date +%Y%m%d_%H%M%S).sql

# Verify backup
ls -lh ~/backups/
```

### Restore Database

```bash
# Stop backend to prevent connections
docker stop backend-api

# Restore from backup
docker exec -i postgres-db psql -U bmi_user -d bmi_health_db < ~/backups/bmi_backup_YYYYMMDD_HHMMSS.sql

# Start backend
docker start backend-api
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker ps -a | grep <container-name>

# View full logs
docker logs <container-name>

# Inspect container
docker inspect <container-name>
```

### Database Connection Failed

```bash
# Test database connectivity from backend
docker exec backend-api ping postgres-db

# Test PostgreSQL
docker exec postgres-db pg_isready -U bmi_user

# Check environment variables
docker exec backend-api env | grep DATABASE_URL
```

### Frontend Can't Reach Backend

```bash
# Check if all containers are on same network
docker network inspect bmi-health-network

# Test backend from frontend container
docker exec frontend-web ping backend-api

# Test API endpoint from frontend
docker exec frontend-web wget -q -O- http://backend-api:3000/health
```

### Port 80 Not Accessible

```bash
# Check if nginx is listening
docker exec frontend-web netstat -tlnp | grep :80

# Check AWS Security Group:
# - Port 80 must be open (0.0.0.0/0)

# Check if port is bound
sudo netstat -tlnp | grep :80
```

### View Network Configuration

```bash
docker network inspect bmi-health-network
```

### Check Volume Contents

```bash
# List files in database volume
docker run --rm -v postgres-data:/data alpine ls -la /data
```

---

## Performance Monitoring

### Check Resource Usage

```bash
# CPU and memory usage
docker stats

# Disk usage
docker system df

# Volume size
docker volume inspect postgres-data | grep Mountpoint
# Then: sudo du -sh <mountpoint-path>
```

### Check Container Health

```bash
# Container uptime
docker ps --format "table {{.Names}}\t{{.Status}}"

# Restart count
docker inspect --format='{{.RestartCount}}' backend-api
```

---

## Next Steps

- **Enable HTTPS**: See [HTTPS_SETUP.md](HTTPS_SETUP.md) for SSL/TLS configuration with Certbot, ACM, and ELB
- **Set up monitoring**: Consider CloudWatch logs or Prometheus
- **Configure backups**: Set up automated database backups with cron jobs
- **Domain setup**: Point your domain (bmi.ostaddevops.click) to the EC2 instance

---

## Quick Reference Commands

```bash
# View all containers
docker ps -a

# View all images
docker images

# View all networks
docker network ls

# View all volumes
docker volume ls

# Clean up unused resources
docker system prune -a

# Export container logs
docker logs backend-api > backend.log 2>&1

# Execute command in container
docker exec -it backend-api sh

# Copy file from container
docker cp backend-api:/app/package.json ./

# View container processes
docker top backend-api
```

---

## Support

For issues or questions:
- Check container logs: `docker logs <container-name>`
- Review GitHub repository: https://github.com/sarowar-alam/3-tier-docker-ubuntu
- Verify AWS Security Group settings
- Ensure EC2 instance has sufficient resources (t2.micro minimum)

---

**Deployment Complete!** 🎉

Your BMI Health Tracker is now running in Docker containers on AWS EC2 with persistent data storage.

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
