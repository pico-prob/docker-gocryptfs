#!/bin/bash
set -e

function sigterm_handler {
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
  echo "sending SIGHUP to child pid"
  if [[ -n "${child_pid:-}" ]]; then
    kill -SIGHUP "$child_pid" 2>/dev/null || true
    wait "$child_pid" || true
  fi
}

function fuse_unmount {
  echo "Unmounting: fusermount $UNMOUNT_OPTIONS $DEC_PATH at: $(date +%Y.%m.%d-%T)"
  fusermount $UNMOUNT_OPTIONS "$DEC_PATH" || true
  rmdir "$DEC_PATH" 2>/dev/null || true
}

trap sigterm_handler SIGINT SIGTERM
trap sighup_handler SIGHUP

mkdir -p "$ENC_PATH" "$DEC_PATH"

if [ -f "/pwd_file" ]; then
  cp /pwd_file "$PWD_FILE"
fi

if [ ! -f "${ENC_PATH}/gocryptfs.conf" ]; then
  gocryptfs -init -passfile "$PWD_FILE" "$ENC_PATH"
fi

gocryptfs $MOUNT_OPTIONS -fg -passfile "$PWD_FILE" "$ENC_PATH" "$DEC_PATH" & child_pid=$!

wait "$child_pid"

echo "gocryptfs crashed at: $(date +%Y.%m.%d-%T)"
fuse_unmount

exit $?