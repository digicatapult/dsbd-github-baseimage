#!/bin/bash

# Configurable Variables
CONFIG_FILE="/etc/sysconfig/qemu-morello.conf"
BUFFER_MEM_MB=1024  # Memory buffer in MB reserved for the system
MIN_CPU_THREADS=1     # Minimum number of CPU threads for QEMU
CPU_DEDUCTION=2     # Number of CPUs to reserve for the host

# Logging function
log() {
    echo "[$(date --rfc-3339=seconds)] $1"
}

# Error handling function
handle_error() {
    log "Error: $1"
    exit 1
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

# Main execution
log "Updating QEMU Morello service configuration..."
write_config
