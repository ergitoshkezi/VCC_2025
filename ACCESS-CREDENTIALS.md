# 🔐 Service Access Credentials & URLs

## 📋 Complete Access Information

### 🌐 Web Services

| Service | URL | Username | Password | Authentication Type |
|---------|-----|----------|----------|-------------------|
| **🔐 Dex OIDC** | http://dex.local/dex | admin@local | admin123 | Direct Login |
| **📊 Grafana** | **http://grafana.local** | admin@local | admin123 | **Domain OAuth2 (Fixed)** |
| **🔧 Forgejo** | http://forgejo.local | admin@local | admin123 | Dex SSO / Direct Setup |
| **📈 Prometheus** | http://prometheus.local | - | - | No Authentication |
| **🚨 Alertmanager** | http://alertmanager.local | - | - | No Authentication |

---

## 🚀 Quick Access Guide

### 1️⃣ **Grafana (Monitoring Dashboards) - Domain OAuth2! 🎉**
```
🔗 URL: http://grafana.local
📋 Steps:
1. Open URL in browser
2. Click "Sign in with Dex"
3. Redirected to: http://dex.local/dex/auth
4. Enter: admin@local / admin123
5. Redirected back to Grafana dashboard
6. Access granted to all dashboards!
```

### 2️⃣ **Forgejo (Git Repository)**
```
🔗 URL: http://forgejo.local
📋 Steps:
Option A (First Time Setup):
1. Complete initial administrator setup
2. Create your admin account

Option B (SSO Login):
1. Look for OAuth2/SSO login option
2. Use Dex credentials: admin@local / admin123
```

### 3️⃣ **Dex (SSO Provider)**
```
🔗 URL: http://dex.local/dex
📋 Direct Access:
- Username: admin@local
- Password: admin123
- Note: Usually accessed via other services
```

### 4️⃣ **Prometheus (Metrics)**
```
🔗 URL: http://prometheus.local
📋 Access: Direct (no login required)
- View metrics and queries
- Read-only interface
```

### 5️⃣ **Alertmanager (Alerts)**
```
🔗 URL: http://alertmanager.local
📋 Access: Direct (no login required)
- View active alerts
- Manage alert routing
```

---

## 🔧 Database Access (if needed)

### PostgreSQL (Forgejo Database)
```
Host: postgres (Docker internal)
Database: forgejo
Username: forgejo
Password: GVVX0pp3Z4UKo
Port: 5432
```

---

## 🎯 Testing Commands

```bash
# Test all services
curl -s -I http://grafana.local
curl -s -I http://forgejo.local
curl -s -I http://prometheus.local
curl -s -I http://alertmanager.local
curl -s -I http://dex.local/dex

# Check service status
./deploy-local.sh status

# View service logs
./deploy-local.sh logs
```

---

## 🔐 Security Notes

- **Default Credentials**: Change in production environment
- **SSO Integration**: Dex provides centralized authentication
- **Local Development**: These credentials are for local development only
- **Data Protection**: All data volumes are preserved in `.data/` directory

---

## 🆘 Troubleshooting

### Service Not Accessible
```bash
# Check if services are running
./deploy-local.sh status

# Check hosts file
./manage-hosts.sh list

# Test domain resolution
./manage-hosts.sh test
```

### Authentication Issues
```bash
# Check Dex configuration
cat dex/config/local-config.yaml

# View Dex logs
docker service logs sso_dex

# View Grafana logs
docker service logs sso_grafana
```

---

**📅 Last Updated**: $(date)  
**🎯 Environment**: Local Development  
**🔧 Stack**: Docker Swarm SSO & Monitoring 