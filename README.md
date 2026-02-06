# BMI Health Tracker - 3-Tier Docker Application

A full-stack BMI and health metrics tracker built with React, Express, and PostgreSQL, fully containerized with Docker for deployment on AWS EC2.

## 🎯 Features

- **BMI Calculator** - Calculate Body Mass Index with WHO categories
- **BMR Calculator** - Basal Metabolic Rate using Mifflin-St Jeor equation
- **Caloric Needs** - Daily calorie requirements based on activity level
- **Health Tracking** - Store and track measurements over time
- **Trend Visualization** - 30-day BMI trend charts
- **Responsive UI** - Modern gradient design, mobile-friendly

## 🏗️ Architecture

**3-Tier Application:**

```
User Browser
    ↓ HTTP:80 / HTTPS:443
┌─────────────────────────────────────┐
│   Frontend (React + Vite)           │
│   - nginx:alpine                    │
│   - Exposed Port: 80                │
└──────────────┬──────────────────────┘
               │ Internal: HTTP:3000
               │ Nginx proxies /api requests
┌──────────────▼──────────────────────┐
│   Backend (Node.js + Express)       │
│   - node:18-alpine                  │
│   - Internal Port: 3000             │
└──────────────┬──────────────────────┘
               │ Internal: PostgreSQL:5432
┌──────────────▼──────────────────────┐
│   Database (PostgreSQL)             │
│   - postgres:15-alpine              │
│   - Internal Port: 5432             │
│   - Persistent volume               │
└─────────────────────────────────────┘

All containers on Docker network: bmi-health-network
Only Frontend port 80 is exposed to the host
```

## 📋 Technology Stack

### Frontend
- React 18
- Vite 5
- Chart.js
- Axios
- Modern CSS with gradients and animations

### Backend
- Node.js 18
- Express 4
- PostgreSQL client (pg)
- REST API architecture

### Database
- PostgreSQL 15
- Persistent Docker volume
- SQL migrations for schema management

### DevOps
- Docker (pure Docker, no docker-compose)
- Nginx for static file serving and reverse proxy
- AWS EC2 deployment ready
- Let's Encrypt SSL/TLS support
- Application Load Balancer integration

## 🚀 Quick Start

### Prerequisites

- Fresh Ubuntu 22.04 LTS EC2 instance
- SSH access to the instance
- Port 80 open in Security Group
- Git installed (or script will install it)

### Automated Deployment

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>

# Clone repository
git clone https://github.com/sarowar-alam/3-tier-docker-ubuntu.git
cd 3-tier-docker-ubuntu/deployDocker

# Run automated deployment
chmod +x full-deploy.sh
./full-deploy.sh
```

**That's it!** The script will:
1. Install Docker and Git
2. Configure environment
3. Deploy all containers
4. Verify deployment

Access your application at: `http://<EC2-PUBLIC-IP>`

### Manual Deployment

See detailed step-by-step instructions: [deployDocker/MANUAL_DEPLOYMENT.md](deployDocker/MANUAL_DEPLOYMENT.md)

## 📁 Project Structure

```
3-tier-app-docker/
├── backend/
│   ├── Dockerfile              # Backend container image
│   ├── .dockerignore           # Docker build exclusions
│   ├── .env.example            # Backend environment template
│   ├── package.json            # Node.js dependencies
│   ├── migrations/             # Database schema migrations
│   │   ├── 001_create_measurements.sql
│   │   └── 002_add_measurement_date.sql
│   └── src/
│       ├── server.js           # Express server entry point
│       ├── routes.js           # API endpoints
│       ├── db.js               # PostgreSQL connection
│       └── calculations.js     # BMI/BMR calculations
├── frontend/
│   ├── Dockerfile              # Frontend multi-stage build
│   ├── .dockerignore           # Docker build exclusions
│   ├── nginx.conf              # Nginx configuration
│   ├── package.json            # React dependencies
│   ├── vite.config.js          # Vite configuration
│   ├── index.html              # HTML shell
│   └── src/
│       ├── main.jsx            # React entry point
│       ├── App.jsx             # Main application component
│       ├── api.js              # Axios HTTP client
│       ├── index.css           # Global styles
│       └── components/
│           ├── MeasurementForm.jsx
│           └── TrendChart.jsx
├── database/
│   └── setup-database.sh       # Legacy setup (not used in Docker)
└── deployDocker/               # 🚀 Docker deployment files
    ├── README.md               # Deployment documentation
    ├── MANUAL_DEPLOYMENT.md    # Step-by-step manual guide
    ├── HTTPS_SETUP.md          # SSL/TLS configuration guide
    ├── .env.example            # Environment variables template
    ├── full-deploy.sh          # Complete automated deployment
    ├── setup-ubuntu.sh         # Docker and Git installation
    ├── deploy-docker.sh        # Deploy all containers
    ├── stop-containers.sh      # Stop containers
    ├── restart-containers.sh   # Restart containers
    ├── backup-database.sh      # Backup database
    ├── cleanup-all.sh          # Remove everything
    ├── logs.sh                 # View container logs
    └── export-cert-to-acm.sh   # Export SSL cert to AWS ACM
```

## 🔧 Configuration

### Environment Variables

Create `deployDocker/.env` from `deployDocker/.env.example`:

```bash
# Database
POSTGRES_DB=bmi_health_db
POSTGRES_USER=bmi_user
POSTGRES_PASSWORD=your_strong_password_here

# Backend
DATABASE_URL=postgresql://bmi_user:password@postgres-db:5432/bmi_health_db
PORT=3000
NODE_ENV=production
FRONTEND_URL=http://your-ec2-ip

# Containers
CONTAINER_DB=postgres-db
CONTAINER_BACKEND=backend-api
CONTAINER_FRONTEND=frontend-web
NETWORK_NAME=bmi-health-network
VOLUME_NAME=postgres-data
```

### AWS Security Group

**Inbound Rules:**

| Type | Port | Source | Description |
|------|------|--------|-------------|
| HTTP | 80 | 0.0.0.0/0 | Public access |
| SSH | 22 | Your IP | Management |

For HTTPS with ALB, see [deployDocker/HTTPS_SETUP.md](deployDocker/HTTPS_SETUP.md)

## 📚 Documentation

- **[Deployment Guide](deployDocker/README.md)** - Complete deployment documentation
- **[Manual Deployment](deployDocker/MANUAL_DEPLOYMENT.md)** - Step-by-step manual instructions
- **[HTTPS Setup](deployDocker/HTTPS_SETUP.md)** - SSL/TLS with Certbot, ACM, and ELB

## 🛠️ Management Commands

```bash
cd deployDocker

# View logs
./logs.sh

# Stop containers (preserves data)
./stop-containers.sh

# Restart containers
./restart-containers.sh

# Backup database
./backup-database.sh

# Remove everything (including data)
./cleanup-all.sh
```

## 🔒 HTTPS Setup

Enable HTTPS with Let's Encrypt and AWS ALB:

1. Generate certificate with Certbot
2. Export to AWS Certificate Manager
3. Configure Application Load Balancer
4. Update Route53 DNS

**Full guide:** [deployDocker/HTTPS_SETUP.md](deployDocker/HTTPS_SETUP.md)

**Domain:** bmi.ostaddevops.click

## 📊 API Endpoints

### Health Check
```
GET /health
Response: {"status":"ok"}
```

### Create Measurement
```
POST /api/measurements
Body: {
  "weightKg": 70,
  "heightCm": 175,
  "age": 30,
  "sex": "male",
  "activity": "moderate",
  "measurementDate": "2026-02-06"
}
Response: {
  "id": 1,
  "bmi": 22.9,
  "bmiCategory": "Normal weight",
  "bmr": 1650,
  "dailyCalories": 2558,
  ...
}
```

### Get All Measurements
```
GET /api/measurements
Response: [...]
```

### Get 30-Day Trends
```
GET /api/measurements/trends
Response: [
  {"date": "2026-02-06", "avgBmi": 22.9},
  ...
]
```

## 🐛 Troubleshooting

### Containers Not Starting

```bash
docker logs <container-name>
docker ps -a
```

### Database Connection Failed

```bash
docker exec postgres-db pg_isready -U bmi_user
docker exec backend-api ping postgres-db
```

### Application Not Accessible

1. Check Security Group (port 80 open)
2. Verify containers running: `docker ps`
3. Test health endpoint: `curl http://localhost/health`
4. Check logs: `./logs.sh`

### Permission Denied

```bash
sudo usermod -aG docker $USER
newgrp docker
```

**More troubleshooting:** [deployDocker/MANUAL_DEPLOYMENT.md](deployDocker/MANUAL_DEPLOYMENT.md)

## 🔄 Data Persistence

Database data is stored in Docker volume `postgres-data`:

- **Preserved** when containers are stopped/removed
- **Deleted** only with `docker volume rm postgres-data`
- **Backed up** with `./backup-database.sh`

## 📈 Performance

### Recommended EC2 Instance Types

- **Testing**: t2.micro (1 vCPU, 1GB RAM)
- **Light Production**: t2.small (1 vCPU, 2GB RAM)
- **Production**: t3.medium+ (2+ vCPU, 4GB+ RAM)

### Resource Usage

- **Frontend**: ~50MB RAM (nginx)
- **Backend**: ~100-200MB RAM (Node.js)
- **Database**: ~200-500MB RAM (PostgreSQL)

## 🔐 Security

- ✅ Environment variables for secrets
- ✅ Database password authentication
- ✅ Parameterized SQL queries (SQL injection prevention)
- ✅ CORS configuration
- ✅ Docker network isolation
- ✅ HTTPS support with Let's Encrypt
- ✅ Regular automated backups

## 🧪 Testing

### Health Check

```bash
curl http://localhost/health
# Expected: {"status":"ok"}
```

### API Test

```bash
# Get measurements
curl http://localhost/api/measurements

# Create measurement
curl -X POST http://localhost/api/measurements \
  -H "Content-Type: application/json" \
  -d '{"weightKg":70,"heightCm":175,"age":30,"sex":"male","activity":"moderate"}'
```

### Database Test

```bash
docker exec -it postgres-db psql -U bmi_user -d bmi_health_db
# In PostgreSQL:
SELECT COUNT(*) FROM measurements;
\q
```

## 📝 Development

### Local Development

```bash
# Backend
cd backend
npm install
npm run dev  # Runs on port 3000

# Frontend
cd frontend
npm install
npm run dev  # Runs on port 5173
```

### Building Docker Images

```bash
# Backend
cd backend
docker build -t bmi-backend:latest .

# Frontend
cd frontend
docker build -t bmi-frontend:latest .
```

## 📞 Support

- **GitHub Repository**: https://github.com/sarowar-alam/3-tier-docker-ubuntu
- **Documentation**: See `deployDocker/` directory
- **Issues**: Check container logs with `./logs.sh`

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---

**Live URL (once deployed):** https://bmi.ostaddevops.click
