#!/bin/bash

# Configurable Variables with environment variable overrides or defaults
CONFIG_FILE="${CONFIG_FILE:-/etc/sysconfig/qemu-morello.conf}"
BUFFER_MEM_MB="${BUFFER_MEM_MB:-1024}"  # Memory buffer in MB reserved for the system, default 1024 MB
MIN_CPU_THREADS="${MIN_CPU_THREADS:-1}"   # Minimum number of CPU threads for QEMU, default 1
CPU_DEDUCTION="${CPU_DEDUCTION:-2}"     # Number of CPUs to reserve for the host, default 2
KEY_VAULT_NAME="${KEY_VAULT_NAME:-YourKeyVaultName}"  # Default Key Vault name for Azure
SECRET_NAME="${SECRET_NAME:-GitHubPAT}"               # Default secret name for both Azure and AWS
GITHUB_ORG="${GITHUB_ORG:-YourGithubOrg}"             # Default GitHub Organization
SECRET_SOURCE="${SECRET_SOURCE:-azure}"  # Source of the secret: 'azure' or 'aws'

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

# Function to fetch GitHub PAT from Azure Key Vault or AWS Secrets Manager
fetch_github_pat() {
    check_cli_tools  # Ensure CLI tools are available

    local pat=""
    if [ "$SECRET_SOURCE" == "azure" ]; then
        pat=$(az keyvault secret show --name "$SECRET_NAME" --vault-name "$KEY_VAULT_NAME" --query value -o tsv)
    elif [ "$SECRET_SOURCE" == "aws" ]; then
        pat=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query 'SecretString' --output text)
    else
        handle_error "Invalid SECRET_SOURCE specified. Must be 'azure' or 'aws'."
    fi

    if [[ -z "$pat" ]]; then
        handle_error "Failed to fetch GitHub PAT from $SECRET_SOURCE."
    else
        log "GitHub PAT fetched successfully from $SECRET_SOURCE."
    fi

    echo "$pat"
}

# Main execution
log "Updating QEMU Morello service configuration..."
write_config
# Fetch GitHub PAT and write to a secure location in the smbshare subdirectory
mkdir -p /etc/qemu-morello/smbshare
PAT=$(fetch_github_pat)
echo "$PAT" > /etc/qemu-morello/smbshare/github_pat.secret
echo "$GITHUB_ORG" > /etc/qemu-morello/smbshare/github_org.txt  # Output the GitHub Org to a file
chmod 600 /etc/qemu-morello/smbshare/github_pat.secret
chmod 600 /etc/qemu-morello/smbshare/github_org.txt
chown -R cheri:cheri /etc/qemu-morello/smbshare
log "GitHub PAT and Org stored securely in smbshare directory."
