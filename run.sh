#!/bin/bash
set -e

function sigterm_handler {
  echo
  echo "sending SIGTERM to child pid"
  if [[ -n "${child_pid:-}" ]]; then
    kill -SIGTERM "$child_pid" 2>/dev/null || true
    wait "$child_pid" || true
  fi
  fuse_unmount
  echo "exiting container now"
  exit $?
}

function sighup_handler {
  echo
  echo "sending SIGHUP to child pid"
  if [[ -n "${child_pid:-}" ]]; then
    kill -SIGHUP "$child_pid" 2>/dev/null || true
    wait "$child_pid" || true
  fi
}

function fuse_unmount {
  echo
  echo "Unmounting: fusermount $UNMOUNT_OPTIONS $DEC_PATH at: $(date +%Y.%m.%d-%T)"
  fusermount $UNMOUNT_OPTIONS "$DEC_PATH" || true
  rmdir "$DEC_PATH" 2>/dev/null || true
}

trap sigterm_handler SIGINT SIGTERM
trap sighup_handler SIGHUP

echo
echo "Starting gocryptfs at: $(date +%Y.%m.%d-%T)"
echo
echo "Parameters:"
echo "MOUNT_OPTIONS: $MOUNT_OPTIONS" 
echo "UNMOUNT_OPTIONS: $UNMOUNT_OPTIONS" 
echo "ENC_PATH: $ENC_PATH" 
echo "DEC_PATH: $DEC_PATH" 
echo "PWD_FILE: $PWD_FILE"
echo
echo "Checks:"
case "$OP_MODE" in
  init_only)
    echo "Operation mode: init_only"
    ;;
  default)
    echo "Operation mode: default"
    ;;
  *)
    echo "Unknown operation mode: $OP_MODE"
    exit 1
    ;;
esac
if [ -f "$PWD_FILE" ]; then
  echo "Password file found at: $PWD_FILE"
else
  echo "Password file missing at: $PWD_FILE"
  exit 1
fi
if [ -d "$ENC_PATH" ]; then
  echo "Encrypted path found at: $ENC_PATH"
else
  echo "Encrypted path missing at: $ENC_PATH"
  echo "Will create path."
  mkdir -p "$ENC_PATH"
fi
if [ -d "$DEC_PATH" ]; then
  echo "Plain path found at: $DEC_PATH"
else
  echo "Plain path missing at: $DEC_PATH"
  echo "Will create path."
  mkdir -p "$DEC_PATH"
fi
if [ ! -f "${ENC_PATH}/gocryptfs.conf" ]; then
  echo "gocryptfs filesystem not found at: ${ENC_PATH}"
  echo
  echo "Will initialize new gocryptfs filesystem."
  gocryptfs -init -passfile "$PWD_FILE" "$ENC_PATH"
  echo
else
  echo "gocryptfs filesystem found at: ${ENC_PATH}"
fi
echo

if [ "$OP_MODE" != "init_only" ]; then
  echo "Mounting gocryptfs filesystem now."
  gocryptfs $MOUNT_OPTIONS -fg -passfile "$PWD_FILE" "$ENC_PATH" "$DEC_PATH" & child_pid=$!
  echo
  wait "$child_pid"

  echo "gocryptfs crashed at: $(date +%Y.%m.%d-%T)"
  fuse_unmount
fi

exit $?