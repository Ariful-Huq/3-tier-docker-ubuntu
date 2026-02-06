# Docker Deployment Guide

Complete deployment guide for BMI Health Tracker on AWS EC2 Ubuntu using pure Docker (no docker-compose).

## 📋 Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
# Clone repository
git clone https://github.com/sarowar-alam/3-tier-docker-ubuntu.git
cd 3-tier-docker-ubuntu/deploy

# Run full automated deployment
chmod +x full-deploy.sh
./full-deploy.sh
```

### Option 2: Manual Step-by-Step

```bash
# 1. Install Docker and Git
chmod +x setup-ubuntu.sh
./setup-ubuntu.sh

# 2. Configure environment
cp .env.example .env
nano .env  # Edit with your values

# 3. Deploy containers
chmod +x deploy-docker.sh
./deploy-docker.sh
```

## 📁 Files Overview

### Deployment Scripts

| Script | Purpose |
|--------|---------|
| `full-deploy.sh` | Complete automated deployment (setup + deploy) |
| `setup-ubuntu.sh` | Install Docker and Git on fresh Ubuntu |
| `deploy-docker.sh` | Deploy all Docker containers |
| `stop-containers.sh` | Stop and remove containers (preserves data) |
| `restart-containers.sh` | Restart all containers |
| `backup-database.sh` | Backup PostgreSQL database to SQL file |
| `cleanup-all.sh` | Remove everything including data volumes |
| `logs.sh` | View container logs interactively |

### HTTPS & SSL

| File | Purpose |
|------|---------|
| `export-cert-to-acm.sh` | Export Let's Encrypt certificates to AWS ACM |
| `HTTPS_SETUP.md` | Complete guide for SSL/HTTPS with ALB and Certbot |

### Configuration

| File | Purpose |
|------|---------|
| `.env.example` | Template for environment variables |
| `.env` | Your actual configuration (create from .env.example) |

### Documentation

| File | Purpose |
|------|---------|
| `MANUAL_DEPLOYMENT.md` | Detailed step-by-step manual deployment guide |
| `HTTPS_SETUP.md` | SSL/TLS setup with Certbot, ACM, and ELB |
| `README.md` | This file |

## 🚀 Deployment Methods

### Method 1: Full Automation

**Best for:** Quick deployment on fresh EC2 instance

```bash
cd 3-tier-with-docker/deploy
./full-deploy.sh
```

**What it does:**
1. Installs Docker and Git if needed
2. Prompts for environment configuration
3. Creates `.env` file automatically
4. Deploys all containers
5. Verifies deployment
6. Shows access URLs

### Method 2: Individual Steps

**Best for:** Manual control and learning

```bash
# Step 1: Setup
./setup-ubuntu.sh

# Step 2: Configure
cp .env.example .env
nano .env

# Step 3: Deploy
./deploy-docker.sh
```

### Method 3: Manual Docker Commands

**Best for:** Understanding Docker internals

See [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md) for complete manual steps with Docker commands.

## ⚙️ Configuration

### Required Environment Variables

Edit `.env` with your values:

```bash
# Database Configuration
POSTGRES_DB=bmi_health_db
POSTGRES_USER=bmi_user
POSTGRES_PASSWORD=your_strong_password  # Change this!

# Backend Configuration
DATABASE_URL=postgresql://bmi_user:your_password@postgres-db:5432/bmi_health_db
PORT=3000
NODE_ENV=production

# CORS Configuration
FRONTEND_URL=http://your-ec2-ip
```

### Container Configuration

Default container names (configurable in `.env`):

- **Database**: `postgres-db` (PostgreSQL 15 Alpine)
- **Backend**: `backend-api` (Node.js 18 Alpine)
- **Frontend**: `frontend-web` (Nginx Alpine)

### Network & Storage

- **Network**: `bmi-health-network` (Docker bridge network)
- **Volume**: `postgres-data` (Persistent database storage)

## 🔧 Management Commands

### View Logs

```bash
./logs.sh  # Interactive menu
# Or directly:
docker logs backend-api
docker logs frontend-web
docker logs postgres-db
```

### Stop Containers

```bash
./stop-containers.sh  # Stops and removes containers (data preserved)
```

### Restart Containers

```bash
./restart-containers.sh  # Stop and redeploy with existing data
```

### Backup Database

```bash
./backup-database.sh  # Creates timestamped SQL dump in backups/
```

### Complete Cleanup

```bash
./cleanup-all.sh  # ⚠️ Removes everything including data!
```

## 🔒 HTTPS Setup

To enable HTTPS with SSL/TLS certificates:

1. **Follow HTTPS Setup Guide**:
   ```bash
   cat HTTPS_SETUP.md
   ```

2. **Generate Certificate**:
   ```bash
   # Install Certbot
   sudo apt-get install -y certbot
   
   # Generate certificate
   sudo certbot certonly --standalone -d bmi.ostaddevops.click
   ```

3. **Export to AWS ACM**:
   ```bash
   chmod +x export-cert-to-acm.sh
   sudo ./export-cert-to-acm.sh
   ```

4. **Configure ALB**: Follow steps in [HTTPS_SETUP.md](HTTPS_SETUP.md)

## 📊 Monitoring

### Check Container Status

```bash
docker ps
docker stats
```

### Verify Health

```bash
curl http://localhost/health
# Expected: {"status":"ok"}
```

### Check Database

```bash
docker exec -it postgres-db psql -U bmi_user -d bmi_health_db
# In PostgreSQL:
\dt                           # List tables
SELECT COUNT(*) FROM measurements;
\q                            # Exit
```

### View Resource Usage

```bash
docker stats
docker system df
```

## 🐛 Troubleshooting

### Containers Not Starting

```bash
# Check logs
docker logs <container-name>

# Check status
docker ps -a

# Restart specific container
docker restart <container-name>
```

### Database Connection Issues

```bash
# Test database
docker exec postgres-db pg_isready -U bmi_user

# Check network
docker network inspect bmi-health-network

# Test connection from backend
docker exec backend-api ping postgres-db
```

### Application Not Accessible

**Check:**
1. AWS Security Group has port 80 open
2. Containers are running: `docker ps`
3. Health endpoint works: `curl http://localhost/health`
4. Frontend is accessible: `curl http://localhost/`

### Permission Denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes
newgrp docker
# Or logout and login again
```

## 📦 Architecture

```
Internet (Port 80)
    ↓
Frontend Container (nginx:alpine)
  - Serves React static files
  - Proxies /api to backend
    ↓
Backend Container (node:18-alpine)
  - REST API (Express)
  - Business logic
    ↓
Database Container (postgres:15-alpine)
  - PostgreSQL with persistent volume
  - Data stored in: postgres-data volume
```

## 🔄 Data Persistence

### Volume Location

Database data is stored in Docker volume `postgres-data`:

```bash
# Inspect volume
docker volume inspect postgres-data

# Check size
docker system df -v
```

### Backup Strategy

**Automatic backups:**

```bash
# Setup cron job
crontab -e

# Add daily backup at 2 AM
0 2 * * * /home/ubuntu/3-tier-with-docker/deploy/backup-database.sh
```

**Manual backup:**

```bash
./backup-database.sh
# Creates: backups/bmi_health_db_backup_YYYYMMDD_HHMMSS.sql
```

**Restore backup:**

```bash
docker exec -i postgres-db psql -U bmi_user -d bmi_health_db < backups/backup_file.sql
```

## 🌐 AWS Security Group Requirements

### For HTTP (Port 80)

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| HTTP | TCP | 80 | 0.0.0.0/0 | Public access |
| SSH | TCP | 22 | Your IP | Management |

### For HTTPS with ALB

EC2 Security Group:
- HTTP (80) from ALB security group only

ALB Security Group:
- HTTP (80) from 0.0.0.0/0
- HTTPS (443) from 0.0.0.0/0

## 📈 Performance Recommendations

### EC2 Instance Types

- **Minimum**: t2.micro (1 vCPU, 1GB RAM) - for testing
- **Recommended**: t2.small (1 vCPU, 2GB RAM) - for light production
- **Production**: t3.medium+ (2+ vCPU, 4GB+ RAM)

### Resource Limits

Containers use default Docker resource limits. To set limits:

```bash
docker run -d \
  --name backend-api \
  --memory="512m" \
  --cpus="0.5" \
  ...
```

## 🔐 Security Best Practices

1. ✅ **Change default passwords** in `.env`
2. ✅ **Restrict Security Groups** (only necessary ports)
3. ✅ **Enable HTTPS** with SSL certificates
4. ✅ **Regular backups** (automated cron jobs)
5. ✅ **Keep Docker updated**: `sudo apt-get update && sudo apt-get upgrade docker-ce`
6. ✅ **Monitor logs** for suspicious activity
7. ✅ **Use IAM roles** instead of AWS credentials on EC2
8. ✅ **Rotate database passwords** periodically

## 📝 Common Tasks

### Update Application Code

```bash
# Pull latest code
cd ~/3-tier-with-docker
git pull

# Rebuild and restart
cd deploy
./restart-containers.sh
```

### Scale Backend

```bash
# Run additional backend instances
docker run -d \
  --name backend-api-2 \
  --network bmi-health-network \
  --env-file .env \
  bmi-backend:latest
```

### View Container Details

```bash
# Inspect container
docker inspect backend-api

# View environment variables
docker exec backend-api env

# Check resource usage
docker stats backend-api
```

## 🆘 Support

### Logs Location

- Container logs: `docker logs <container-name>`
- Deployment logs: Terminal output during deployment
- Database backups: `deploy/backups/`

### Debug Mode

Enable verbose logging:

```bash
# Backend logs
docker logs -f backend-api

# Frontend logs
docker logs -f frontend-web

# Database logs
docker logs -f postgres-db
```

### Get Help

1. Check logs: `./logs.sh`
2. Review documentation: `MANUAL_DEPLOYMENT.md`
3. Verify configuration: `cat .env`
4. Test connectivity: `curl http://localhost/health`

## 📚 Additional Resources

- [Manual Deployment Guide](MANUAL_DEPLOYMENT.md) - Step-by-step manual instructions
- [HTTPS Setup Guide](HTTPS_SETUP.md) - SSL/TLS configuration
- [GitHub Repository](https://github.com/sarowar-alam/3-tier-docker-ubuntu)
- [Docker Documentation](https://docs.docker.com/)
- [AWS EC2 Guide](https://docs.aws.amazon.com/ec2/)

## ✅ Deployment Checklist

- [ ] EC2 instance created and running
- [ ] Security Group configured (port 80 open)
- [ ] SSH access working
- [ ] Git repository cloned
- [ ] Docker and Git installed
- [ ] `.env` file created and configured
- [ ] Containers deployed successfully
- [ ] Application accessible via browser
- [ ] Health check endpoint working
- [ ] Database backup tested
- [ ] (Optional) HTTPS configured with ALB

---

**Need help?** Check [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md) for detailed instructions or [HTTPS_SETUP.md](HTTPS_SETUP.md) for SSL configuration.

**Repository:** https://github.com/sarowar-alam/3-tier-docker-ubuntu
