#!/bin/bash

# Configuration
CERT_DIR="nginx/certs"
CA_NAME="LocalCA"
DOMAIN="*.local"
CERT_FILE="$CERT_DIR/local.crt"
KEY_FILE="$CERT_DIR/local.key"
CA_CERT="$CERT_DIR/ca.crt"
CA_KEY="$CERT_DIR/ca.key"
CONF_FILE="$CERT_DIR/openssl.cnf"

# Create directories
mkdir -p "$CERT_DIR"

echo "Generating Root CA..."
# Generate CA Key
openssl genrsa -out "$CA_KEY" 4096

# Generate CA Certificate
openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 3650 -out "$CA_CERT" \
    -subj "/C=US/ST=State/L=City/O=Dev/CN=$CA_NAME"

echo "Generating Server Certificate for $DOMAIN..."
# Create configuration file for SAN
cat > "$CONF_FILE" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Dev
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.local
DNS.2 = forgejo.local
DNS.3 = grafana.local
DNS.4 = dex.local
DNS.5 = prometheus.local
DNS.6 = alertmanager.local
EOF

# Generate Server Key
openssl genrsa -out "$KEY_FILE" 2048

# Generate Certificate Signing Request (CSR)
CSR_FILE="$CERT_DIR/local.csr"
openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -config "$CONF_FILE"

# Sign the certificate with our CA
openssl x509 -req -in "$CSR_FILE" -CA "$CA_CERT" -CAkey "$CA_KEY" \
    -CAcreateserial -out "$CERT_FILE" -days 365 -sha256 -extensions v3_req -extfile "$CONF_FILE"

# Cleanup
rm "$CSR_FILE" "$CONF_FILE"

echo "Certificates generated in $CERT_DIR"
