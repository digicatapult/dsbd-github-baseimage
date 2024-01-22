#!/bin/bash
set -euo pipefail

# Configuration Variables
CHERI_USER="cheri"
CHERI_HOME="/home/$CHERI_USER"
QEMU_REPO="https://github.com/CTSRD-CHERI/qemu.git"
QEMU_BRANCH="qemu-cheri-bsd-user-mttcg-buildfixessystemmode"
CHERIBUILD_REPO="https://github.com/CTSRD-CHERI/cheribuild.git"
OUTPUT_DIR="/output"
ZFS_GROUP="disk"  # or another appropriate group

# Function to install dependencies including ZFS
install_deps() {
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf automake libtool pkg-config \
    git clang bison cmake mercurial ninja-build samba flex texinfo \
    time libglib2.0-dev libpixman-1-dev libarchive-dev libarchive-tools \
    libbz2-dev libattr1-dev libcap-ng-dev libexpat1-dev libgmp-dev \
    zfsutils-linux  # Add this line to install ZFS utilities
}

# Function to determine paths of ZFS commands
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

# Function to configure sudoers for ZFS commands
configure_sudoers_for_zfs() {
    local paths
    paths=($(determine_zfs_paths))

    local sudo_cmds=""
    for path in "${paths[@]}"; do
        sudo_cmds+="$path *, "
    done

    # Remove trailing comma and space
    sudo_cmds=${sudo_cmds%, }

    echo "$CHERI_USER ALL=(ALL) NOPASSWD: $sudo_cmds" >> /etc/sudoers
}

# Function to create a user, setup directories, and configure ZFS permissions
setup_user_and_zfs_permissions() {
    useradd -m -s /bin/bash "$CHERI_USER"
    mkdir -p "$CHERI_HOME/.config"
    mkdir -p "$CHERI_HOME/cheri"
    mkdir -p "$OUTPUT_DIR"
    cp /tmp/cheribuild.json "$CHERI_HOME/.config/cheribuild.json"
    chown -R "$CHERI_USER:$CHERI_USER" "$CHERI_HOME"
    chown -R "$CHERI_USER:$CHERI_USER" "$OUTPUT_DIR"

    # Add cheri user to the necessary group for ZFS management
    usermod -aG "$ZFS_GROUP" "$CHERI_USER"

    # Configure sudoers for ZFS commands
    configure_sudoers_for_zfs
}

# Function to clone and setup CHERI QEMU as cheri user
install_qemu() {
    runuser -l "$CHERI_USER" -c "git clone -b \"$QEMU_BRANCH\" --single-branch \"$QEMU_REPO\" \"$CHERI_HOME/cheri/qemu\""
    runuser -l "$CHERI_USER" -c "pushd \"$CHERI_HOME/cheri/qemu\" && git apply /tmp/qemu-multicore.patch && git submodule update --init --recursive && popd"
}

# Function to clone and setup Cheribuild as cheri user
install_cheribuild() {
    runuser -l "$CHERI_USER" -c "git clone \"$CHERIBUILD_REPO\" \"$CHERI_HOME/cheri/cheribuild\""
    runuser -l "$CHERI_USER" -c "pushd \"$CHERI_HOME/cheri/cheribuild\" && git apply /tmp/cheribuild-gmp-git.patch && popd"
}

# Main script execution
install_deps
setup_user_and_zfs_permissions
install_qemu
install_cheribuild
