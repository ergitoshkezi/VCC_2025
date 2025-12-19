#!/bin/bash

# Local SSO & Monitoring Stack Deployment Script
# Author: DevOps Team
# Description: Automated deployment script for local Docker Swarm stack with SSO and monitoring

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="sso"
COMPOSE_FILE="docker-compose.swarm.yml"
HOSTS_FILE="/etc/hosts"

# Local domains
DOMAINS=(
    "forgejo.local"
    "grafana.local"
    "dex.local"
    "prometheus.local"
    "alertmanager.local"
)

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check requirements
check_requirements() {
    print_step "Checking requirements..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    print_status "All requirements met."
}

# Function to initialize Docker Swarm
init_swarm() {
    print_step "Initializing Docker Swarm..."
    
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        print_status "Docker Swarm is already initialized."
    else
        print_status "Initializing Docker Swarm..."
        docker swarm init --advertise-addr 127.0.0.1
        print_status "Docker Swarm initialized successfully."
    fi
}

# Function to create required directories
create_directories() {
    print_step "Creating required directories..."
    
    # Create directories if they don't exist
    mkdir -p nginx/{conf.d,logs}
    mkdir -p dex/config
    mkdir -p prometheus
    mkdir -p alertmanager
    mkdir -p grafana/provisioning/{dashboards,datasources}
    mkdir -p .data/{postgres,forgejo,grafana,prometheus,alertmanager}
    
    print_status "Directories created successfully."
}

# Function to setup hosts file
setup_hosts() {
    print_step "Setting up /etc/hosts file..."
    
    # Check if we need sudo
    if [ ! -w "$HOSTS_FILE" ]; then
        print_warning "Need sudo privileges to modify /etc/hosts"
        SUDO="sudo"
    else
        SUDO=""
    fi
    
    # Backup original hosts file
    $SUDO cp "$HOSTS_FILE" "${HOSTS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Hosts file backed up."
    
    # Add local domains
    for domain in "${DOMAINS[@]}"; do
        if ! grep -q "$domain" "$HOSTS_FILE"; then
            echo "127.0.0.1   $domain" | $SUDO tee -a "$HOSTS_FILE" > /dev/null
            print_status "Added $domain to hosts file."
        else
            print_status "$domain already exists in hosts file."
        fi
    done
}

# Function to validate configuration files
validate_configs() {
    print_step "Validating configuration files..."
    
    # Check if required files exist
    required_files=(
        "$COMPOSE_FILE"
        "nginx/conf.d/local.conf"
        "dex/config/local-config.yaml"
        "prometheus/local-prometheus.yml"
        "prometheus/local-alert.rules"
        "alertmanager/local-config.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file $file does not exist."
            exit 1
        fi
    done
    
    print_status "All configuration files validated."
}

# Function to deploy the stack
deploy_stack() {
    print_step "Deploying Docker Swarm stack..."
    
    # Deploy the stack
    docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"
    
    print_status "Stack deployment initiated."
}

# Function to wait for services
wait_for_services() {
    print_step "Waiting for services to start..."
    
    local max_wait=300  # 5 minutes
    local wait_time=0
    local check_interval=10
    
    while [ $wait_time -lt $max_wait ]; do
        local running_services=$(docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --format "table {{.Name}}\t{{.Replicas}}" | grep -c "1/1" || true)
        local total_services=$(docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --quiet | wc -l)
        
        if [ "$running_services" -eq "$total_services" ] && [ "$total_services" -gt 0 ]; then
            print_status "All services are running!"
            break
        fi
        
        print_status "Waiting for services... ($running_services/$total_services ready)"
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    if [ $wait_time -ge $max_wait ]; then
        print_warning "Timeout waiting for all services to start. Some services may still be starting up."
    fi
}

# Function to show service status
show_status() {
    print_step "Service Status:"
    docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME"
    echo
    
    print_step "Stack Services:"
    docker stack services "$STACK_NAME"
    echo
}

# Function to show access URLs
show_urls() {
    print_step "Access URLs:"
    echo -e "${GREEN}📋 Service URLs:${NC}"
    echo "  🔧 Forgejo Git:     https://forgejo.local"
    echo "  📊 Grafana:         https://grafana.local"
    echo "  🔐 Dex OIDC:        https://dex.local/dex"
    echo "  📈 Prometheus:      https://prometheus.local"
    echo "  🚨 Alertmanager:    https://alertmanager.local"
    echo
    echo -e "${GREEN}🔑 Default Credentials:${NC}"
    echo "  Dex Login:    admin@local / admin123"
    echo "  Grafana:      Use Dex SSO (admin@local / admin123)"
    echo
}

# Function to show logs
show_logs() {
    print_step "Showing recent logs for all services..."
    docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --format "{{.Name}}" | while read service; do
        echo -e "${BLUE}=== Logs for $service ===${NC}"
        docker service logs --tail 5 "$service" 2>/dev/null || echo "No logs available"
        echo
    done
}

# Function to cleanup
cleanup() {
    print_step "Cleaning up the stack..."
    
    read -p "Are you sure you want to remove the stack? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker stack rm "$STACK_NAME"
        print_status "Stack removed successfully."
        
        read -p "Do you want to remove local domains from /etc/hosts? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for domain in "${DOMAINS[@]}"; do
                if [ ! -w "$HOSTS_FILE" ]; then
                    sudo sed -i "/$domain/d" "$HOSTS_FILE"
                else
                    sed -i "/$domain/d" "$HOSTS_FILE"
                fi
                print_status "Removed $domain from hosts file."
            done
        fi
    else
        print_status "Cleanup cancelled."
    fi
}

# Function to show help
show_help() {
    echo "Local SSO & Monitoring Stack Deployment Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  deploy    Deploy the complete stack (default)"
    echo "  status    Show service status"
    echo "  logs      Show service logs"
    echo "  urls      Show access URLs"
    echo "  cleanup   Remove the stack and cleanup"
    echo "  help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 deploy   # Deploy the stack"
    echo "  $0 status   # Check service status"
    echo "  $0 logs     # View service logs"
    echo "  $0 cleanup  # Remove everything"
}

# Main function
main() {
    local command=${1:-deploy}
    
    case $command in
        deploy)
            print_status "Starting local deployment..."
            check_requirements
            init_swarm
            create_directories
            # Generate certificates
            if [ -f "scripts/generate-certs.sh" ]; then
                print_step "Generating SSL certificates..."
                bash scripts/generate-certs.sh
            fi
            setup_hosts
            validate_configs
            deploy_stack
            wait_for_services
            show_status
            show_urls
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        urls)
            show_urls
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
