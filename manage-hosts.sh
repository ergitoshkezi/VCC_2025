#!/bin/bash

# Hosts File Management Script for Local SSO & Monitoring Stack
# Author: DevOps Team
# Description: Manages /etc/hosts entries for local development domains

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HOSTS_FILE="/etc/hosts"
BACKUP_DIR="$HOME/.hosts-backups"

# Local domains for the SSO stack
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

# Function to check if we need sudo
check_permissions() {
    if [ ! -w "$HOSTS_FILE" ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            print_error "Cannot write to $HOSTS_FILE and sudo is not available"
            exit 1
        fi
        SUDO="sudo"
        print_warning "Need sudo privileges to modify $HOSTS_FILE"
    else
        SUDO=""
    fi
}

# Function to create backup
create_backup() {
    print_step "Creating backup of hosts file..."
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Create backup with timestamp
    local backup_file="$BACKUP_DIR/hosts.backup.$(date +%Y%m%d_%H%M%S)"
    $SUDO cp "$HOSTS_FILE" "$backup_file"
    
    print_status "Backup created: $backup_file"
}

# Function to add domains to hosts file
add_domains() {
    print_step "Adding local domains to hosts file..."
    
    create_backup
    
    local added_count=0
    for domain in "${DOMAINS[@]}"; do
        if ! grep -q "$domain" "$HOSTS_FILE"; then
            echo "127.0.0.1   $domain" | $SUDO tee -a "$HOSTS_FILE" > /dev/null
            print_status "Added $domain"
            ((added_count++))
        else
            print_status "$domain already exists"
        fi
    done
    
    if [ $added_count -gt 0 ]; then
        print_status "Added $added_count new domain(s) to hosts file"
    else
        print_status "All domains already exist in hosts file"
    fi
}

# Function to remove domains from hosts file
remove_domains() {
    print_step "Removing local domains from hosts file..."
    
    create_backup
    
    local removed_count=0
    for domain in "${DOMAINS[@]}"; do
        if grep -q "$domain" "$HOSTS_FILE"; then
            $SUDO sed -i "/$domain/d" "$HOSTS_FILE"
            print_status "Removed $domain"
            ((removed_count++))
        else
            print_status "$domain not found"
        fi
    done
    
    if [ $removed_count -gt 0 ]; then
        print_status "Removed $removed_count domain(s) from hosts file"
    else
        print_status "No domains found to remove"
    fi
}

# Function to list domains in hosts file
list_domains() {
    print_step "Checking domain entries in hosts file..."
    
    echo -e "${BLUE}Domain Status:${NC}"
    for domain in "${DOMAINS[@]}"; do
        if grep -q "$domain" "$HOSTS_FILE"; then
            local ip=$(grep "$domain" "$HOSTS_FILE" | awk '{print $1}' | head -1)
            echo -e "  ✅ $domain -> $ip"
        else
            echo -e "  ❌ $domain (not found)"
        fi
    done
    echo
    
    # Show all local domain entries
    if grep -q "\.local" "$HOSTS_FILE"; then
        echo -e "${BLUE}All .local entries:${NC}"
        grep "\.local" "$HOSTS_FILE" | sed 's/^/  /'
    else
        echo -e "${YELLOW}No .local domains found in hosts file${NC}"
    fi
}

# Function to validate hosts file
validate_hosts() {
    print_step "Validating hosts file..."
    
    # Check if file exists and is readable
    if [ ! -f "$HOSTS_FILE" ]; then
        print_error "Hosts file $HOSTS_FILE does not exist"
        return 1
    fi
    
    if [ ! -r "$HOSTS_FILE" ]; then
        print_error "Cannot read hosts file $HOSTS_FILE"
        return 1
    fi
    
    # Check for syntax issues
    local line_num=0
    local errors=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Check basic format (IP and hostname)
        if ! echo "$line" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+[a-zA-Z0-9.-]+'; then
            print_warning "Line $line_num may have syntax issues: $line"
            ((errors++))
        fi
    done < "$HOSTS_FILE"
    
    if [ $errors -eq 0 ]; then
        print_status "Hosts file validation passed"
    else
        print_warning "Found $errors potential syntax issues"
    fi
}

# Function to restore from backup
restore_backup() {
    print_step "Restoring hosts file from backup..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory $BACKUP_DIR does not exist"
        exit 1
    fi
    
    # List available backups
    local backups=($(ls -1t "$BACKUP_DIR"/hosts.backup.* 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        print_error "No backup files found in $BACKUP_DIR"
        exit 1
    fi
    
    echo -e "${BLUE}Available backups:${NC}"
    for i in "${!backups[@]}"; do
        local backup_file="${backups[$i]}"
        local backup_date=$(basename "$backup_file" | sed 's/hosts.backup.//')
        local formatted_date=$(echo "$backup_date" | sed 's/_/ /')
        echo "  $((i+1)). $formatted_date"
    done
    
    read -p "Select backup to restore (1-${#backups[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#backups[@]} ]; then
        local selected_backup="${backups[$((choice-1))]}"
        $SUDO cp "$selected_backup" "$HOSTS_FILE"
        print_status "Restored hosts file from backup: $selected_backup"
    else
        print_error "Invalid choice"
        exit 1
    fi
}

# Function to test domain resolution
test_domains() {
    print_step "Testing domain resolution..."
    
    for domain in "${DOMAINS[@]}"; do
        if command -v nslookup >/dev/null 2>&1; then
            local result=$(nslookup "$domain" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
            if [ "$result" = "127.0.0.1" ]; then
                echo -e "  ✅ $domain -> $result"
            else
                echo -e "  ❌ $domain -> ${result:-'unresolved'}"
            fi
        elif command -v dig >/dev/null 2>&1; then
            local result=$(dig +short "$domain" 2>/dev/null)
            if [ "$result" = "127.0.0.1" ]; then
                echo -e "  ✅ $domain -> $result"
            else
                echo -e "  ❌ $domain -> ${result:-'unresolved'}"
            fi
        else
            print_warning "Neither nslookup nor dig available for testing"
            break
        fi
    done
}

# Function to show help
show_help() {
    echo "Hosts File Management Script for Local SSO & Monitoring Stack"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  add       Add local domains to hosts file"
    echo "  remove    Remove local domains from hosts file"
    echo "  list      List domain entries in hosts file"
    echo "  test      Test domain resolution"
    echo "  validate  Validate hosts file syntax"
    echo "  backup    Create backup of hosts file"
    echo "  restore   Restore hosts file from backup"
    echo "  help      Show this help message"
    echo
    echo "Managed domains:"
    for domain in "${DOMAINS[@]}"; do
        echo "  - $domain"
    done
    echo
    echo "Examples:"
    echo "  $0 add      # Add all local domains"
    echo "  $0 list     # Show current domain status"
    echo "  $0 test     # Test if domains resolve correctly"
    echo "  $0 remove   # Remove all local domains"
}

# Main function
main() {
    local command=${1:-help}
    
    # Check permissions early for commands that need to modify hosts file
    case $command in
        add|remove|restore)
            check_permissions
            ;;
    esac
    
    case $command in
        add)
            add_domains
            ;;
        remove)
            remove_domains
            ;;
        list)
            list_domains
            ;;
        test)
            test_domains
            ;;
        validate)
            validate_hosts
            ;;
        backup)
            check_permissions
            create_backup
            ;;
        restore)
            restore_backup
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