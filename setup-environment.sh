#!/bin/bash

# Environment Setup Script for Local SSO & Monitoring Stack
# Author: DevOps Team
# Description: Sets up the environment and installs required dependencies

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# System detection
DISTRO=""
PACKAGE_MANAGER=""

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

# Function to detect the operating system
detect_os() {
    print_step "Detecting operating system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        print_status "Detected OS: $PRETTY_NAME"
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    # Set package manager based on distro
    case $DISTRO in
        ubuntu|debian)
            PACKAGE_MANAGER="apt"
            ;;
        centos|rhel|fedora)
            PACKAGE_MANAGER="yum"
            ;;
        arch)
            PACKAGE_MANAGER="pacman"
            ;;
        *)
            print_warning "Unsupported distribution: $DISTRO"
            print_warning "Manual installation may be required"
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system_requirements() {
    print_step "Checking system requirements..."
    
    # Check available memory (should be at least 2GB)
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$mem_gb" -lt 2 ]; then
        print_warning "System has less than 2GB RAM. Some services may not run properly."
    else
        print_status "Memory check passed: ${mem_gb}GB available"
    fi
    
    # Check available disk space (should be at least 10GB)
    local disk_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_gb" -lt 10 ]; then
        print_warning "Less than 10GB disk space available. Consider freeing up space."
    else
        print_status "Disk space check passed: ${disk_gb}GB available"
    fi
    
    # Check if we're running as root (not recommended)
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root is not recommended for Docker operations"
    fi
}

# Function to install Docker
install_docker() {
    print_step "Installing Docker..."
    
    if command_exists docker; then
        print_status "Docker is already installed"
        docker --version
        return
    fi
    
    case $PACKAGE_MANAGER in
        apt)
            # Update package index
            sudo apt-get update
            
            # Install required packages
            sudo apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Set up the stable repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        yum)
            # Install required packages
            sudo yum install -y yum-utils
            
            # Add Docker repository
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            # Install Docker Engine
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        *)
            print_error "Automatic Docker installation not supported for this OS"
            print_status "Please install Docker manually from https://docs.docker.com/get-docker/"
            exit 1
            ;;
    esac
    
    print_status "Docker installed successfully"
}

# Function to configure Docker
configure_docker() {
    print_step "Configuring Docker..."
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group (if not root)
    if [ "$EUID" -ne 0 ]; then
        sudo usermod -aG docker $USER
        print_status "Added $USER to docker group"
        print_warning "Please log out and log back in for group changes to take effect"
    fi
    
    # Test Docker installation
    if sudo docker run hello-world >/dev/null 2>&1; then
        print_status "Docker is working correctly"
    else
        print_error "Docker installation test failed"
        exit 1
    fi
}

# Function to install additional tools
install_tools() {
    print_step "Installing additional tools..."
    
    case $PACKAGE_MANAGER in
        apt)
            sudo apt-get update
            sudo apt-get install -y curl wget git htop net-tools
            ;;
        yum)
            sudo yum install -y curl wget git htop net-tools
            ;;
        *)
            print_warning "Cannot install additional tools automatically"
            ;;
    esac
    
    print_status "Additional tools installed"
}

# Function to configure firewall
configure_firewall() {
    print_step "Configuring firewall..."
    
    if command_exists ufw; then
        # Ubuntu/Debian with UFW
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw allow 2376/tcp
        sudo ufw allow 2377/tcp
        sudo ufw allow 7946/tcp
        sudo ufw allow 7946/udp
        sudo ufw allow 4789/udp
        print_status "UFW firewall configured for Docker Swarm"
    elif command_exists firewall-cmd; then
        # CentOS/RHEL with firewalld
        sudo firewall-cmd --permanent --add-port=80/tcp
        sudo firewall-cmd --permanent --add-port=443/tcp
        sudo firewall-cmd --permanent --add-port=2376/tcp
        sudo firewall-cmd --permanent --add-port=2377/tcp
        sudo firewall-cmd --permanent --add-port=7946/tcp
        sudo firewall-cmd --permanent --add-port=7946/udp
        sudo firewall-cmd --permanent --add-port=4789/udp
        sudo firewall-cmd --reload
        print_status "Firewalld configured for Docker Swarm"
    else
        print_warning "No supported firewall found. You may need to configure ports manually"
    fi
}

# Function to create project structure
create_project_structure() {
    print_step "Creating project structure..."
    
    # Create required directories
    mkdir -p {nginx/{conf.d,logs},dex/config,prometheus,alertmanager,grafana/provisioning/{dashboards,datasources}}
    mkdir -p .data/{postgres,forgejo,grafana,prometheus,alertmanager}
    mkdir -p scripts logs
    
    # Set appropriate permissions
    chmod 755 nginx/logs
    chmod 755 .data/*
    
    print_status "Project structure created"
}

# Function to validate environment
validate_environment() {
    print_step "Validating environment..."
    
    # Check Docker
    if ! command_exists docker; then
        print_error "Docker is not available"
        return 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        return 1
    fi
    
    # Check Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        print_warning "Docker Compose plugin not available"
    fi
    
    # Check required ports
    local required_ports=(80 443)
    for port in "${required_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port is already in use"
        fi
    done
    
    print_status "Environment validation completed"
}

# Function to show next steps
show_next_steps() {
    print_step "Setup completed!"
    echo
    echo -e "${GREEN}✅ Next Steps:${NC}"
    echo "1. If you were added to the docker group, please log out and log back in"
    echo "2. Run the deployment script: ./deploy-local.sh"
    echo "3. Access services at the URLs provided by the deployment script"
    echo
    echo -e "${GREEN}📋 Available Scripts:${NC}"
    echo "  ./deploy-local.sh deploy  - Deploy the complete stack"
    echo "  ./deploy-local.sh status  - Check service status"
    echo "  ./deploy-local.sh logs    - View service logs"
    echo "  ./deploy-local.sh cleanup - Remove the stack"
    echo
}

# Function to show help
show_help() {
    echo "Environment Setup Script for Local SSO & Monitoring Stack"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --skip-docker     Skip Docker installation"
    echo "  --skip-firewall   Skip firewall configuration"
    echo "  --skip-tools      Skip additional tools installation"
    echo "  --help            Show this help message"
    echo
    echo "This script will:"
    echo "  - Detect your operating system"
    echo "  - Install Docker and Docker Compose"
    echo "  - Configure Docker for the current user"
    echo "  - Install additional tools"
    echo "  - Configure firewall for Docker Swarm"
    echo "  - Create project directory structure"
    echo "  - Validate the environment"
}

# Main function
main() {
    local skip_docker=false
    local skip_firewall=false
    local skip_tools=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-docker)
                skip_docker=true
                shift
                ;;
            --skip-firewall)
                skip_firewall=true
                shift
                ;;
            --skip-tools)
                skip_tools=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_status "Starting environment setup..."
    
    detect_os
    check_system_requirements
    
    if [ "$skip_docker" = false ]; then
        install_docker
        configure_docker
    else
        print_status "Skipping Docker installation"
    fi
    
    if [ "$skip_tools" = false ]; then
        install_tools
    else
        print_status "Skipping additional tools installation"
    fi
    
    if [ "$skip_firewall" = false ]; then
        configure_firewall
    else
        print_status "Skipping firewall configuration"
    fi
    
    create_project_structure
    validate_environment
    show_next_steps
}

# Run main function with all arguments
main "$@" 