#!/bin/bash

# Configurable Variables with environment variable overrides or defaults
CONFIG_FILE="${CONFIG_FILE:-/etc/sysconfig/qemu-morello.conf}"
BUFFER_MEM_MB="${BUFFER_MEM_MB:-2048}"  # Memory buffer in MB reserved for the system, default 2048 MB
MIN_CPU_THREADS="${MIN_CPU_THREADS:-1}"   # Minimum number of CPU threads for QEMU, default 1
CPU_DEDUCTION="${CPU_DEDUCTION:-2}"     # Number of CPUs to reserve for the host, default 2
KEY_VAULT_NAME="${KEY_VAULT_NAME:-YourKeyVaultName}"  # Default Key Vault name for Azure
SECRET_NAME="${SECRET_NAME:-GitHubPAT}"               # Default secret name for both Azure and AWS
GITHUB_ORG="${GITHUB_ORG:-YourGithubOrg}"             # Default GitHub Organization
SECRET_SOURCE="${SECRET_SOURCE:-azure}"  # Source of the secret: 'azure' or 'aws'
RELEASE_PIPELINE="${RELEASE_PIPELINE:-0}"  # Enable a release pipeline for jail images (pots), default 0
RELEASE_NAME="${RELEASE_NAME:-sibling}"  # Set the name of upstream pots
RELEASE_VERSION="${RELEASE_VERSION:-1.0.0}"  # Set their release version

# Logging function
log() {
    echo "[$(date --rfc-3339=seconds)] $1"
}

# Error handling function
handle_error() {
    log "Error: $1"
    exit 1
}

# Function to check if CLI tools are installed
check_cli_tools() {
    if [ "$SECRET_SOURCE" == "azure" ]; then
        if ! command -v az &> /dev/null; then
            handle_error "Azure CLI (az) could not be found. Please install it to proceed."
        fi
    elif [ "$SECRET_SOURCE" == "aws" ]; then
        if ! command -v aws &> /dev/null; then
            handle_error "AWS CLI (aws) could not be found. Please install it to proceed."
        fi
    fi
}

# Function to get the total number of CPU sockets
get_cpu_sockets() {
    lscpu | awk -F: '/Socket\(s\):/ {print $2}' | xargs
}

# Function to get the adjusted number of CPU threads for QEMU
get_cpu_threads_for_qemu() {
    local total_threads=$(nproc --all)
    local threads_for_qemu=$((total_threads > CPU_DEDUCTION ? total_threads - CPU_DEDUCTION : MIN_CPU_THREADS))
    echo "$threads_for_qemu"
}

# Function to get the adjusted memory for QEMU
get_memory_for_qemu() {
    local total_mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    local mem_for_qemu=$((total_mem_mb > BUFFER_MEM_MB ? total_mem_mb - BUFFER_MEM_MB : total_mem_mb))
    echo "${mem_for_qemu}M"
}

# Function to write configuration to the config file
write_config() {
    local cpu_sockets=$(get_cpu_sockets) || handle_error "Failed to get CPU sockets."
    local cpu_threads=$(get_cpu_threads_for_qemu) || handle_error "Failed to calculate CPU threads for QEMU."
    local memory=$(get_memory_for_qemu) || handle_error "Failed to calculate memory for QEMU."

    echo "QEMU_SMP=cores=1,threads=${cpu_threads},sockets=${cpu_sockets}" > "$CONFIG_FILE" || handle_error "Failed to write CPU configuration to $CONFIG_FILE."
    echo "QEMU_MEM=${memory}" >> "$CONFIG_FILE" || handle_error "Failed to write memory configuration to $CONFIG_FILE."

    log "QEMU Morello service configuration updated successfully."
}

# Function to Login using an Azure Managed Identity
handle_azure_login() {
    # Login using Managed Identity
    az login --identity --allow-no-subscriptions
    if [ $? -ne 0 ]; then
        handle_error "Azure login failed."
    fi
}

# Function to fetch GitHub PAT from Azure Key Vault or AWS Secrets Manager
fetch_github_pat() {
    check_cli_tools  # Ensure CLI tools are available

    local pat=""
    if [ "$SECRET_SOURCE" == "azure" ]; then
        handle_azure_login
        if pat=$(az keyvault secret show --name "$SECRET_NAME" --vault-name "$KEY_VAULT_NAME" --query value -o tsv 2>/dev/null); then
            log "GitHub PAT fetched successfully from Azure."
        else
            handle_error "Failed to fetch GitHub PAT from Azure."
            return 1
        fi
    elif [ "$SECRET_SOURCE" == "aws" ]; then
        if pat=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query 'SecretString' --output text 2>/dev/null); then
            log "GitHub PAT fetched successfully from AWS."
        else
            handle_error "Failed to fetch GitHub PAT from AWS."
            return 1
        fi
    else
        handle_error "Invalid SECRET_SOURCE specified. Must be 'azure' or 'aws'."
        return 1
    fi

    # Assuming at this point $pat is not empty and contains the valid token
    echo "$pat" > /etc/qemu-morello/smbshare/github_pat.secret
    log "GitHub PAT written to /etc/qemu-morello/smbshare/github_pat.secret"
}

setup_pipeline() {
    pipeline=/etc/qemu-morello/smbshare/pipeline.txt
    echo RELEASE_PIPELINE="${RELEASE_PIPELINE}" > "$pipeline"
    echo RELEASE_NAME="${RELEASE_NAME}" >> "$pipeline"
    echo RELEASE_VERSION="${RELEASE_VERSION}" >> "$pipeline"
    chmod 600 "$pipeline"
    if [ "${RELEASE_PIPELINE}" -ne 0 ]; then
        log "A pipeline has been configured to release pots"
    fi
}

# Main execution
log "Updating QEMU Morello service configuration..."
write_config
# Fetch GitHub PAT and write to a secure location in the smbshare subdirectory
mkdir -p /etc/qemu-morello/smbshare
fetch_github_pat
echo "$GITHUB_ORG" > /etc/qemu-morello/smbshare/github_org.txt  # Output the GitHub Org to a file
chmod 600 /etc/qemu-morello/smbshare/github_pat.secret
chmod 600 /etc/qemu-morello/smbshare/github_org.txt
chown -R cheri:cheri /etc/qemu-morello/smbshare
log "GitHub PAT and Org stored securely in smbshare directory."
setup_pipeline