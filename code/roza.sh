#!/bin/bash

# Variables
LOCAL_DIR="i2c"
ARCHIVE="i2c.tar.gz"
REMOTE_HOST="uta@192.168.1.68"
REMOTE_DIR="~"   # Change if needed

# Step 1: Compress the folder
echo "Compressing $LOCAL_DIR -> $ARCHIVE"
tar -czf "$ARCHIVE" "$LOCAL_DIR"

# Step 2: Copy the archive to the remote host
echo "Copying $ARCHIVE to $REMOTE_HOST:$REMOTE_DIR"
scp "$ARCHIVE" "$REMOTE_HOST":"$REMOTE_DIR"

# Step 3: Extract the archive on the remote host
echo "Extracting $ARCHIVE on $REMOTE_HOST"
ssh "$REMOTE_HOST" "tar -xzf $REMOTE_DIR/$ARCHIVE -C $REMOTE_DIR"

# Step 4: Remove the tarball on the remote host
echo "Deleting $ARCHIVE on $REMOTE_HOST"
ssh "$REMOTE_HOST" "rm -f $REMOTE_DIR/$ARCHIVE"

# Step 5: Compile on the remote host
echo "Compiling on $REMOTE_HOST"
ssh "$REMOTE_HOST" "cd $REMOTE_DIR/$LOCAL_DIR/general && make -B"
ssh "$REMOTE_HOST" "cd $REMOTE_DIR/$LOCAL_DIR/kernbase && make -B"
ssh "$REMOTE_HOST" "cd $REMOTE_DIR/$LOCAL_DIR/kernex && make -B"
ssh "$REMOTE_HOST" "cd $REMOTE_DIR/$LOCAL_DIR/user && make -B"