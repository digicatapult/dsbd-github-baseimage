#!/bin/bash
set -euo pipefail

echo "Starting script execution..."

# Configuration variables
CHERI_USER="cheri"
CHERI_HOME="/home/$CHERI_USER"
OUTPUT_DIR="/output"
ZFS_GROUP="disk"

# Dependencies (can be modified with branch names or commit IDs)
QEMU_REPO="https://github.com/CTSRD-CHERI/qemu.git"
QEMU_BRANCH="qemu-cheri"
CHERIBUILD_REPO="https://github.com/CTSRD-CHERI/cheribuild.git"
CHERIBUILD_BRANCH="main"
CHERIBSD_REPO="https://github.com/CTSRD-CHERI/cheribsd.git"
CHERIBSD_BRANCH="main"

echo "Configuration variables set."

install_deps() {
    echo "Installing dependencies..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf automake libtool pkg-config \
    git clang bison cmake mercurial ninja-build samba flex texinfo \
    time libglib2.0-dev libpixman-1-dev libarchive-dev libarchive-tools \
    libbz2-dev libattr1-dev libcap-ng-dev libexpat1-dev libgmp-dev unzip \
    inotify-tools \
    zfsutils-linux  # Add this line to install ZFS utilities
    echo "Dependencies installation complete."
}

# Additional function to install AWS CLI for ARM64
install_aws_cli() {
    echo "Installing AWS CLI for ARM64..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm awscliv2.zip
    rm -rf aws
    echo "AWS CLI installation complete."
}

# Additional function to install Azure CLI
install_azure_cli() {
    echo "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    echo "Azure CLI installation complete."
}

determine_zfs_paths() {
    local zfs_cmds=("zfs" "zpool" "zdb" "zdump" "ztest")
    local paths=()

    for cmd in "${zfs_cmds[@]}"; do
        local path
        path=$(which "$cmd" 2>/dev/null || true)
        if [[ -n $path ]]; then
            paths+=("$path")
        fi
    done

    echo "${paths[@]}"
}

configure_sudoers_for_zfs() {
    local paths
    mapfile -t paths < <(determine_zfs_paths)

    local sudo_cmds=""
    for path in "${paths[@]}"; do
        sudo_cmds+="$path *, "
    done

    sudo_cmds=${sudo_cmds%, }

    echo "Configuring sudoers for ZFS commands..."
    echo "$CHERI_USER ALL=(ALL) NOPASSWD: $sudo_cmds" >> /etc/sudoers
    echo "Sudoers configuration for ZFS commands complete."
}

setup_user_and_zfs_permissions() {
    echo "Setting up user and ZFS permissions..."
    useradd -m -s /bin/bash "$CHERI_USER"
    mkdir -p "$CHERI_HOME/.config"
    mkdir -p "$CHERI_HOME/cheri"
    mkdir -p "$CHERI_HOME/cheri/extra-files/root/.ssh"
    cp -r /tmp/extra-files/ "$CHERI_HOME/cheri/"
    cat /tmp/dsbd_labs.pub >> "$CHERI_HOME/cheri/extra-files/root/.ssh/authorized_keys"
    mkdir -p "$OUTPUT_DIR"
    cp /tmp/cheribuild.json "$CHERI_HOME/.config/cheribuild.json"
    chown -R "$CHERI_USER:$CHERI_USER" "$CHERI_HOME"
    chown -R "$CHERI_USER:$CHERI_USER" "$OUTPUT_DIR"

    usermod -aG "$ZFS_GROUP" "$CHERI_USER"

    configure_sudoers_for_zfs
    echo "User setup and ZFS permissions configuration complete."
}

install_cheribsd() {
    echo "Checking out CheriBSD..."
    runuser -l "$CHERI_USER" -c "git clone \"$CHERIBSD_REPO\" \"$CHERI_HOME/cheri/cheribsd\""
    if [ ! -z "$CHERIBSD_BRANCH" ]; then
        runuser -l "$CHERI_USER" -c "git -C \"$CHERI_HOME/cheri/cheribsd\" checkout \"$CHERIBSD_BRANCH\""
    fi
    echo "CheriBSD checkout complete."
}

install_qemu() {
    echo "Installing CHERI QEMU..."
    runuser -l "$CHERI_USER" -c "git clone \"$QEMU_REPO\" \"$CHERI_HOME/cheri/qemu\""
    if [ ! -z "$QEMU_BRANCH" ]; then
        runuser -l "$CHERI_USER" -c "git -C \"$CHERI_HOME/cheri/qemu\" checkout \"$QEMU_BRANCH\""
    fi
    runuser -l "$CHERI_USER" -c "git -C \"$CHERI_HOME/cheri/qemu\" submodule sync"
    runuser -l "$CHERI_USER" -c "git -C \"$CHERI_HOME/cheri/qemu\" submodule update --init --recursive"
    echo "CHERI QEMU installation complete."
}

install_cheribuild() {
    echo "Installing Cheribuild..."
    runuser -l "$CHERI_USER" -c "git clone \"$CHERIBUILD_REPO\" \"$CHERI_HOME/cheri/cheribuild\""
    if [ ! -z "$CHERIBUILD_BRANCH" ]; then
        runuser -l "$CHERI_USER" -c "git -C \"$CHERI_HOME/cheri/cheribuild\" checkout \"$CHERIBUILD_BRANCH\""
    fi
    echo "Cheribuild installation complete."
}

# Main script execution
echo "Beginning main script execution..."
install_deps
install_aws_cli
install_azure_cli
setup_user_and_zfs_permissions
install_qemu
install_cheribsd
install_cheribuild
echo "Script execution completed successfully."
