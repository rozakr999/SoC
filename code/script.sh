#!/bin/bash

# Variables
LOCAL_DIR="i2c"
ARCHIVE="i2c.tar.gz"
REMOTE_HOST="cpu"
REMOTE_DIR="~"   # Change if needed

# Step 1: Compress the folder
echo "Compressing $LOCAL_DIR -> $ARCHIVE"
tar -czf "$ARCHIVE" "$LOCAL_DIR"

# Step 2: Copy the archive to the remote host
echo "Copying $ARCHIVE to $REMOTE_HOST:$REMOTE_DIR"
scp "$ARCHIVE" "$REMOTE_HOST":"$REMOTE_DIR"

# Step 3: Clean up local archive
echo "Deleting $ARCHIVE on local machine"
rm -f "$ARCHIVE"

# Step 4: SCP Script
scp "remote.sh" "$REMOTE_HOST":"$REMOTE_DIR/remote.sh"

# Step 5: Run Remote Script
ssh "$REMOTE_HOST" "./remote.sh"
