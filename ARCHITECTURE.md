# System Architecture & Service Interconnections

This document outlines the architecture of the Application Monitoring and SSO Stack. It details how services interact, communicate, and depend on one another.

## Visual Diagram

The following Mermaid graph illustrates the traffic flow (Ingress), authentication (SSO), data persistence, and the monitoring pipeline.

```mermaid
graph TD
    %% ==========================================
    %% 1. USERS & INGRESS
    %% ==========================================
    User((User / Browser))
    
    subgraph Gateway [Ingress Layer]
        Nginx[Nginx Reverse Proxy<br/>Ports: 80, 443]
    end

    %% User Interactions
    User -- "https://forgejo..." --> Nginx
    User -- "https://grafana..." --> Nginx
    User -- "https://dex..." --> Nginx
    User -- "https://prometheus..." --> Nginx

    %% ==========================================
    %% 2. AUTHENTICATION (SSO)
    %% ==========================================
    subgraph Auth [Identity Provider]
        Dex[Dex OIDC Provider<br/>Port: 5556]
    end

    %% ==========================================
    %% 3. APPLICATION STACK
    %% ==========================================
    subgraph AppStack [Application Layer]
        Forgejo[Forgejo Git Service<br/>Port: 3000]
        Postgres[(Postgres Database<br/>Port: 5432)]
    end

    %% ==========================================
    %% 4. MONITORING STACK
    %% ==========================================
    subgraph Monitoring [Observability Pipeline]
        Grafana[Grafana Dashboard<br/>Port: 3000]
        Prometheus[Prometheus Server<br/>Port: 9090]
        Alertmanager[Alertmanager<br/>Port: 9093]
        
        subgraph Exporters [Metrics Sources]
            NodeExp[Node Exporter<br/>Host Hardware]
            cAdvisor[cAdvisor<br/>Container Stats]
            Pushgateway[Pushgateway<br/>Push Metrics]
        end
    end

    %% ==========================================
    %% CONNECTIONS & FLOWS
    %% ==========================================

    %% Nginx Routing (Reverse Proxy)
    %% Nginx terminates SSL (in production) or passes generic traffic
    Nginx -->|Proxy| Dex
    Nginx -->|Proxy| Forgejo
    Nginx -->|Proxy| Grafana
    Nginx -->|Proxy| Prometheus
    Nginx -->|Proxy| Alertmanager

    %% Database Connections
    Forgejo -->|Read/Write Data| Postgres

    %% Authentication Flows (OIDC/OAuth2)
    Forgejo -.->|1. Redirect Login| Dex
    Grafana -.->|1. Redirect Login| Dex
    Dex -.->|2. Verify Credentials| User

    %% Monitoring: Scrape Loop (Pull Model)
    Prometheus -->|Scrape /metrics| NodeExp
    Prometheus -->|Scrape /metrics| cAdvisor
    Prometheus -->|Scrape /metrics| Pushgateway
    Prometheus -->|Scrape /metrics| Forgejo
    Prometheus -->|Scrape /metrics| Alertmanager

    %% Monitoring: Visualization & Alerting
    Grafana -->|Query Datasource| Prometheus
    Prometheus -->|Fire Alerts| Alertmanager

    %% Styling for clarity
    classDef gateway fill:#f9f,stroke:#333,stroke-width:2px;
    classDef auth fill:#f96,stroke:#333,stroke-width:2px;
    classDef app fill:#69b,stroke:#333,stroke-width:2px;
    classDef monitor fill:#6b9,stroke:#333,stroke-width:2px;
    classDef db fill:#eee,stroke:#333,stroke-width:2px,stroke-dasharray: 5 5;
    
    class Nginx gateway;
    class Dex auth;
    class Forgejo app;
    class Postgres db;
    class Grafana,Prometheus,Alertmanager,NodeExp,cAdvisor,Pushgateway monitor;
```

## Service Details

### 1. Gateway (Nginx)
- **Role**: Entry point for all external traffic.
- **Function**: Routes HTTP/HTTPS requests based on domains (`forgejo.local`, `grafana.local`, etc.) to the appropriate internal container.
- **Dependencies**: None (it routes to others).

### 2. Authentication (Dex)
- **Role**: Centralized Identity Provider (IdP).
- **Function**: Handles user login and issues tokens (OIDC).
- **Interactions**:
    - **Forgejo** and **Grafana** connect to Dex to authenticate users.

### 3. Application (Forgejo & Postgres)
- **Forgejo**: Self-hosted Git service.
    - Connects to **Postgres** for data storage.
    - Connects to **Dex** for user login (SSO).
- **Postgres**: Database backend. Only accessible internally by Forgejo.

### 4. Monitoring (Prometheus, Grafana, & Exporters)
- **Prometheus**: Metrics collection engine.
    - **Scrapes** (pulls data) from `Node Exporter`, `cAdvisor`, `Pushgateway`, and other targets every 15s.
    - Sends alert rules to **Alertmanager**.
- **Grafana**: Visualization dashboard.
    - Queries **Prometheus** to display graphs.
    - Uses **Dex** for login.
- **Alertmanager**: Handles alert notifications (e-mail, Slack, etc.) received from Prometheus.
- **Exporters**:
    - **Node Exporter**: Exposes Host OS metrics (CPU, RAM, Disk).
    - **cAdvisor**: Exposes Docker Container metrics.
