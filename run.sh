#!/bin/bash
set -e

ENC_PATH=/encrypted
DEC_PATH=/decrypted

# REMOVED: No longer enumerate subfolders; we mount the whole /encrypted at once.
# ENC_FOLDERS=`find ${ENC_PATH} ! -path ${ENC_PATH} -maxdepth 1 -type d`

function sigterm_handler {
  echo "sending SIGTERM to child pid"
  # CHANGED: Stop using an array of PIDs; we manage a single gocryptfs process now.
  # NEW: Guard against empty PID and wait for graceful shutdown.
  if [[ -n "${child_pid:-}" ]]; then
    kill -SIGTERM "$child_pid" 2>/dev/null || true
    wait "$child_pid" || true
  fi
  fuse_unmount
  echo "exiting container now"
  exit $?
}

function sighup_handler {
  echo "sending SIGHUP to child pid"
  # CHANGED: Use the single child PID instead of an array of PIDs.
  if [[ -n "${child_pid:-}" ]]; then
    kill -SIGHUP "$child_pid" 2>/dev/null || true
    # CHANGED: Wait for the child to react to SIGHUP (best-effort).
    wait "$child_pid" || true
  fi
}

function fuse_unmount {
  # CHANGED: Unmount only the single decrypted mount point instead of iterating subfolders.
  echo "Unmounting: fusermount $UNMOUNT_OPTIONS $DEC_PATH at: $(date +%Y.%m.%d-%T)"
  fusermount $UNMOUNT_OPTIONS "$DEC_PATH" || true
  # CHANGED: Remove the single decrypted directory after unmount (best-effort).
  rmdir "$DEC_PATH" 2>/dev/null || true

  # REMOVED: Per-subfolder unmount loop is no longer needed.
  # DEC_FOLDERS=`find ${DEC_PATH} ! -path ${DEC_PATH} -maxdepth 1 -type d`
  # for DEC_FOLDER in $DEC_FOLDERS; do
  #   echo "Unmounting: fusermount $UNMOUNT_OPTIONS $DEC_FOLDER at: $(date +%Y.%m.%d-%T)"
  #   fusermount $UNMOUNT_OPTIONS $DEC_FOLDER
  #   rmdir $DEC_FOLDER
  # done
}

trap sigterm_handler SIGINT SIGTERM
trap sighup_handler SIGHUP

# REMOVED: No pids array needed; we only track a single child process.
# unset pids

# REMOVED: The loop mounting each subfolder has been replaced by a single mount of /encrypted -> /decrypted.
# for ENC_FOLDER in $ENC_FOLDERS; do
#   DEC_FOLDER=`echo "$ENC_FOLDER" | sed "s|^${ENC_PATH}|${DEC_PATH}|g"`
#   mkdir -p $DEC_FOLDER
#   if [ ! -f "${ENC_FOLDER}/gocryptfs.conf" ]; then
#     gocryptfs -init -extpass 'printenv PASSWD' $ENC_FOLDER
#   fi
#   gocryptfs $MOUNT_OPTIONS -fg -extpass 'printenv PASSWD' $ENC_FOLDER $DEC_FOLDER & pids+=($!)
# done
# wait "${pids[@]}"

# NEW: Ensure the single decrypted mount point exists.
mkdir -p "$DEC_PATH"

# CHANGED: Initialize gocryptfs in /encrypted if it hasn't been set up yet.
if [ ! -f "${ENC_PATH}/gocryptfs.conf" ]; then
  gocryptfs -init -passfile '/pwd_file' "$ENC_PATH"
fi

# CHANGED: Start a single foreground gocryptfs process and capture its PID.
gocryptfs $MOUNT_OPTIONS -fg -passfile '/pwd_file' "$ENC_PATH" "$DEC_PATH" & child_pid=$!

# CHANGED: Wait for the single gocryptfs process to exit.
wait "$child_pid"

echo "gocryptfs crashed at: $(date +%Y.%m.%d-%T)"
fuse_unmount

exit $?