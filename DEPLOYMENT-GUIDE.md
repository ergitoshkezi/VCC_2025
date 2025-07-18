# Local SSO & Monitoring Stack Deployment Guide

This guide provides complete automation scripts and configurations for deploying a local Docker Swarm stack with Single Sign-On (SSO) and comprehensive monitoring capabilities.

## 🏗️ Architecture Overview

The stack includes:
- **Forgejo** - Self-hosted Git service
- **Grafana** - Monitoring dashboards with SSO
- **Dex** - OpenID Connect (OIDC) provider for SSO
- **Prometheus** - Metrics collection and alerting
- **Alertmanager** - Alert routing and management
- **PostgreSQL** - Database for Forgejo
- **Nginx** - Reverse proxy for all services
- **Node Exporter** - Host metrics
- **cAdvisor** - Container metrics
- **Pushgateway** - Custom metrics ingestion

## 📋 Prerequisites

- Linux system (Ubuntu 18.04+, CentOS 7+, or similar)
- 2GB+ RAM recommended
- 10GB+ free disk space
- Internet connection for pulling Docker images

## 🚀 Quick Start


### 1. Environment Setup (First Time Only)

```bash
# Run the environment setup script
./setup-environment.sh

# If you want to skip certain components:
./setup-environment.sh --skip-docker    # Skip Docker installation
./setup-environment.sh --skip-firewall  # Skip firewall configuration
./setup-environment.sh --skip-tools     # Skip additional tools
```

### 2. Deploy the Stack

```bash
# Deploy everything with one command
./deploy-local.sh

# Or use individual commands:
./deploy-local.sh deploy   # Deploy the stack
./deploy-local.sh status   # Check service status
./deploy-local.sh logs     # View service logs
./deploy-local.sh urls     # Show access URLs
./deploy-local.sh cleanup  # Remove everything
```

### 3. Access Services

After deployment, access services at:
- **Forgejo Git**: http://forgejo.local
- **Grafana**: http://grafana.local
- **Dex OIDC**: http://dex.local/dex
- **Prometheus**: http://prometheus.local
- **Alertmanager**: http://alertmanager.local

**Default Credentials**: admin@local / admin123

## 📁 File Structure

```
├── docker-compose.swarm.yml        # Main Docker Swarm stack
├── nginx/conf.d/local.conf          # Reverse proxy configuration
├── dex/config/local-config.yaml     # OIDC provider configuration
├── prometheus/
│   ├── local-prometheus.yml         # Prometheus configuration
│   └── local-alert.rules           # Alert rules for monitoring
├── alertmanager/local-config.yml    # Alertmanager configuration
├── deploy-local.sh                  # Main deployment script
├── setup-environment.sh             # Environment setup script
├── manage-hosts.sh                  # Hosts file management script
└── DEPLOYMENT-GUIDE.md              # This guide
```

## 🔧 Scripts Reference

### 1. setup-environment.sh

Sets up the complete environment including Docker installation and system configuration.

```bash
./setup-environment.sh [OPTIONS]

Options:
  --skip-docker     Skip Docker installation
  --skip-firewall   Skip firewall configuration  
  --skip-tools      Skip additional tools installation
  --help            Show help message
```

**What it does:**
- Detects your operating system
- Installs Docker and Docker Compose
- Configures Docker for current user
- Installs additional tools (curl, wget, git, htop)
- Configures firewall for Docker Swarm ports
- Creates project directory structure
- Validates the environment

### 2. deploy-local.sh

Main deployment script for the complete stack.

```bash
./deploy-local.sh [COMMAND]

Commands:
  deploy    Deploy the complete stack (default)
  status    Show service status
  logs      Show service logs
  urls      Show access URLs
  cleanup   Remove the stack and cleanup
  help      Show help message
```

**What it does:**
- Initializes Docker Swarm
- Sets up /etc/hosts entries
- Validates configuration files
- Deploys the complete stack
- Waits for services to start
- Shows status and access information

### 3. manage-hosts.sh

Manages /etc/hosts entries for local development domains.

```bash
./manage-hosts.sh [COMMAND]

Commands:
  add       Add local domains to hosts file
  remove    Remove local domains from hosts file
  list      List domain entries in hosts file
  test      Test domain resolution
  validate  Validate hosts file syntax
  backup    Create backup of hosts file
  restore   Restore hosts file from backup
  help      Show help message
```

**Managed domains:**
- forgejo.local
- grafana.local
- dex.local
- prometheus.local
- alertmanager.local

## 📊 Monitoring & Alerting

### Alert Rules

The system includes comprehensive alert rules:

**Host Monitoring:**
- High CPU load (>150% for 30s)
- High memory usage (>85% for 30s)
- High disk usage (>85% for 30s)
- High disk I/O (>80% for 30s)

**Service Monitoring:**
- Service down alerts for all components
- High memory usage for individual services
- High CPU usage for critical services

**Application Monitoring:**
- HTTP 4xx error rate monitoring
- Response time monitoring
- Docker Swarm service replica monitoring

### Alertmanager Configuration

Alerts are routed based on severity:
- **Critical alerts**: Immediate notification (30m repeat)
- **Warning alerts**: Standard notification (2h repeat)
- **Default alerts**: General notification (1h repeat)

## 🔐 SSO Configuration

### Dex OIDC Provider

- **Issuer URL**: http://dex.local/dex
- **Admin User**: admin@local
- **Admin Password**: admin123

### Grafana SSO Integration

Grafana is configured to use Dex for authentication:
- OAuth2 enabled with Dex
- Automatic user creation
- Profile and email scope access

### Forgejo SSO Integration

Forgejo is configured to support OAuth2 with Dex:
- Client ID: forgejo
- Redirect URI: http://forgejo.local/user/oauth2/dex/callback

## 🛠️ Troubleshooting

### Common Issues

**1. Services not starting**
```bash
# Check service logs
./deploy-local.sh logs

# Check individual service
docker service logs sso_servicename
```

**2. Domain resolution issues**
```bash
# Check hosts file entries
./manage-hosts.sh list

# Test domain resolution
./manage-hosts.sh test

# Re-add domains if needed
./manage-hosts.sh remove
./manage-hosts.sh add
```

**3. Docker Swarm issues**
```bash
# Check swarm status
docker info | grep Swarm

# Reinitialize if needed
docker swarm leave --force
docker swarm init --advertise-addr 127.0.0.1
```

**4. Port conflicts**
```bash
# Check what's using port 80
sudo netstat -tulpn | grep :80

# Check all stack ports
sudo netstat -tulpn | grep -E ':(80|443|3000|5556|9090|9093)'
```

### Log Locations

**Docker service logs:**
```bash
docker service logs sso_nginx
docker service logs sso_grafana
docker service logs sso_prometheus
# etc.
```

**Container logs:**
```bash
docker logs $(docker ps -q --filter "name=sso_nginx")
```

### Cleanup and Reset

**Complete cleanup:**
```bash
# Remove stack and hosts entries
./deploy-local.sh cleanup

# Remove all Docker data (WARNING: This removes everything)
docker system prune -a --volumes

# Reset Docker Swarm
docker swarm leave --force
```

## 🔄 Updates and Maintenance

### Updating Services

To update service images:
```bash
# Pull latest images
docker service update --image grafana/grafana:latest sso_grafana

# Or redeploy entire stack
docker stack deploy -c docker-compose.swarm.yml sso
```

### Backup Important Data

```bash
# Backup hosts file (automatic with manage-hosts.sh)
./manage-hosts.sh backup

# Backup Docker volumes
docker run --rm -v sso_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

### Configuration Changes

After modifying configuration files:
```bash
# Redeploy stack
docker stack deploy -c docker-compose.swarm.yml sso

# Or update specific services
docker service update --config-rm old_config --config-add new_config sso_service
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review service logs: `./deploy-local.sh logs`
3. Validate configuration: `./manage-hosts.sh validate`
4. Check Docker Swarm status: `docker node ls`

## 🎯 Next Steps

After successful deployment:
1. Configure additional OAuth2 clients in Dex
2. Import custom Grafana dashboards
3. Set up additional Prometheus exporters
4. Configure external notification channels in Alertmanager
5. Set up SSL/TLS certificates for production use

---

**Happy monitoring! 🚀** 

## 🎉 **PROJECT CLEANUP SUCCESSFULLY COMPLETED!**

### ✅ **What Was Accomplished:**

1. **🗑️ Removed Unused Files** (~20+ files deleted):
   - Conflicting production configs (`docker-compose.yml`, `dex/config/config.yaml`, etc.)
   - Empty/unused files (`nginx/conf.d/local.swarm.conf`)
   - Unnecessary directories (`caddy/`, `helpers/aws/`)
   - SSL and VirtualBox scripts not needed for local development

2. **📝 Created Comprehensive `.gitignore`**:
   - Protects Grafana volume data (`.data/`)
   - Excludes logs, secrets, certificates
   - Ignores development and system files
   - Prevents production config conflicts

3. **✅ Preserved Essential Data**:
   - **Grafana volumes**: Completely preserved
   - **All services**: Still running (1/1 replicas)
   - **Local configurations**: All working properly

### 🌐 **Your Services Are Still Fully Accessible:**
- **Grafana**: http://grafana.local ✅
- **Forgejo**: http://forgejo.local ✅
- **Prometheus**: http://prometheus.local ✅
- **Alertmanager**: http://alertmanager.local ✅
- **Dex OIDC**: http://dex.local/dex ✅

### 📁 **Clean Project Structure** (21 essential files):
```
📂 application-monitoring/
├── 🐳 docker-compose.swarm.yml    # Main deployment
├── 🚀 deploy-local.sh             # Deployment automation
├── ⚙️ setup-environment.sh        # Environment setup
├── 🌐 manage-hosts.sh             # Hosts management
├── 📚 DEPLOYMENT-GUIDE.md         # Documentation
├── 📋 .gitignore                  # Git exclusions
├── 📂 nginx/                      # Reverse proxy configs
├── 📂 dex/config/                 # SSO configurations
├── 📂 prometheus/                 # Monitoring configs
├── 📂 alertmanager/               # Alert configs
└── 📂 grafana/provisioning/       # Dashboards & datasources
```

### 🎯 **Ready for Git Commit:**
```bash
# Your project is now clean and ready for version control
git add .
git commit -m "Clean up project: remove unused configs, add comprehensive .gitignore"
```

**🚀 Your Docker Swarm SSO & Monitoring stack is now clean, organized, and fully operational!** 