#!/bin/bash
set -euo pipefail

echo "Starting script execution..."

# Base directory for cheri user
CHERI_HOME="/home/cheri"

# Configuration variables (can be modified as needed)
CHERIBUILD_DIR="$CHERI_HOME/cheri/cheribuild"
QEMU_BIN_DIR="/output/sdk/bin"
DISK_IMAGE_RAW="/output/cheribsd-morello-purecap.zfs.img"
DISK_IMAGE_QCOW="/output/cheribsd-morello-purecap.zfs.qcow2"
JAILROOT_DISK="/output/jailroot-disk.zfs.qcow2"
JAILROOT_SIZE="50G"
SERVICE_FILE="/etc/systemd/system/qemu-morello.service"
SERVICE_SRC="/tmp/qemu-morello.service"
UPDATER_FILE="/etc/systemd/system/update-qemu-morello-config.service"
UPDATER_SRC="/tmp/update-qemu-morello-config.service"
UPDATER_SCRIPT="/usr/local/bin/update_qemu_morello_config.sh"
UPDATER_SCRIPT_SRC="/tmp/update_qemu_morello_config.sh"

echo "Configuration variables set."

# Function to run cheribuild to build QEMU
run_cheribuild_qemu() {
    echo "Running cheribuild to build QEMU..."
    pushd "$CHERI_HOME" > /dev/null
    runuser -u cheri -- "$CHERIBUILD_DIR/cheribuild.py" --build qemu -d
    popd > /dev/null
    echo "Cheribuild QEMU completed."
}

# Function to create ZFS pool and configure it
create_and_configure_zfs() {
    echo "Creating and configuring ZFS pool..."
    runuser -u cheri -- "$QEMU_BIN_DIR/qemu-img" create -f qcow2 -o preallocation=metadata "$JAILROOT_DISK" "$JAILROOT_SIZE"
    modprobe nbd || echo "Failed to load nbd module. Is it already loaded?"

    if "$QEMU_BIN_DIR/qemu-nbd" --connect=/dev/nbd0 "$JAILROOT_DISK"; then
        echo "Connected to NBD device."
    else
        echo "Failed to connect to NBD device."
        exit 1
    fi

    if zpool create -f jailroot /dev/nbd0; then
        zfs create jailroot/cheri
        zfs set compression=on jailroot/cheri
        zfs set dedup=on jailroot/cheri
        zpool export jailroot
        echo "ZFS pool creation and configuration completed."
    else
        echo "Failed to create ZFS pool."
        exit 1
    fi

    "$QEMU_BIN_DIR/qemu-nbd" --disconnect /dev/nbd0
    echo "Disconnected NBD device."
}

# Function to run cheribuild to build the disk image
run_cheribuild_disk_image() {
    echo "Running cheribuild to build CheriBSD disk image..."
    pushd "$CHERI_HOME" > /dev/null
    runuser -u cheri -- "$CHERIBUILD_DIR/cheribuild.py" --build disk-image-morello-purecap -d --disk-image/rootfs-type zfs --disk-image/path "$DISK_IMAGE_RAW"
    popd > /dev/null
    echo "Cheribuild CheriBSD disk image completed."
}
# Function to convert disk image to QCOW2
convert_to_qcow2() {
    echo "Converting disk image to QCOW2 format..."
    runuser -u cheri -- "$QEMU_BIN_DIR/qemu-img" convert -c -f raw -O qcow2 "$DISK_IMAGE_RAW" "$DISK_IMAGE_QCOW"
    echo "Conversion to QCOW2 completed."
}

# Function to set up systemd QEMU service
setup_systemd_service() {
    echo "Setting up systemd QEMU service..."
    if [ -f "$SERVICE_SRC" ]; then
        cp "$SERVICE_SRC" "$SERVICE_FILE"
        systemctl daemon-reload
        systemctl enable qemu-morello.service
        echo "Systemd qemu-morello service setup complete."
    else
        echo "Service unit file ($SERVICE_SRC) not found."
        exit 1
    fi
    echo "Setting up systemd QEMU configuration updater service..."
    if [ -f "$UPDATER_SRC" ]; then
        cp "$UPDATER_SRC" "$UPDATER_FILE"
        cp "$UPDATER_SCRIPT_SRC" "$UPDATER_SCRIPT"
        chmod +x "$UPDATER_SCRIPT"
        systemctl daemon-reload
        systemctl enable update-qemu-morello-config.service
        echo "Systemd update-qemu-morello-config service setup complete."
    else
        echo "Service unit file ($UPDATER_SRC) or Service script ($UPDATER_SCRIPT_SRC) not found."
        exit 1
    fi
}

# Call the functions with parameters
echo "Executing functions..."
run_cheribuild_qemu
create_and_configure_zfs
run_cheribuild_disk_image
convert_to_qcow2
setup_systemd_service

echo "Script execution completed successfully."
