#!/bin/bash

# Release engineering pipeline variables with overrides or defaults
RELEASE_PIPELINE="${RELEASE_PIPELINE:-0}"  # Enable a release pipeline for jail images (pots), default 0
RELEASE_NAME="${RELEASE_NAME:-sibling}"  # Set the name of upstream pots
RELEASE_VERSION="${RELEASE_VERSION:-1.0.0}"  # Set their release version
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-YourStorageAccount}"  # Default Azure Storage Account
FILE_SHARE="${FILE_SHARE:-YourFileShare}"  # Default Azure File Share

# Logging function
log() {
    echo "[$(date --rfc-3339=seconds)] $1"
}

# Error handling function
handle_error() {
    log "Error: $1"
    exit 1
}

export_azure_artefacts() {
    pots="${CONFIG_FILE}"/pots
    if [ ! -d "$pots" ]; then
        handle_error "No directory could be found on the guest containing pots."
        return 1
    fi

    if ! command -v inotifywait &> /dev/null; then
        handle_error "Failed to locate inotifywait for monitoring guest behaviour."
        return 1
    fi

    # Use inotifywait to monitor for changes on the guest
    while :; do
        inotifywait -qe delete "$pipeline" &>/dev/null || \
        shasum -a 256 "$pots"/*.xz > "$pots"/SHA256

        if [ "$SECRET_SOURCE" == "azure" ]; then
            az storage copy -s "$pots"/* -d "https://${STORAGE_ACCOUNT}.file.core.windows.net/$FILE_SHARE/$RELEASE_NAME/$RELEASE_VERSION" --recursive && \
            echo "Release artefacts for $RELEASE_NAME, version $RELEASE_VERSION, have been uploaded."
        fi
    done
}

setup_pipeline() {
    pipeline=/etc/qemu-morello/smbshare/pipeline.txt
    echo RELEASE_PIPELINE="${RELEASE_PIPELINE}" > "$pipeline"
    echo RELEASE_NAME="${RELEASE_NAME}" >> "$pipeline"
    echo RELEASE_VERSION="${RELEASE_VERSION}" >> "$pipeline"
    chmod 600 "$pipeline"
    chown -R cheri:cheri /etc/qemu-morello/smbshare

    if [ "${RELEASE_PIPELINE}" -eq 1 ]; then
        log "A pipeline has been configured to release pots via SMB"
        export_azure_artefacts
    fi
}

setup_pipeline
