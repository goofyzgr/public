#!/usr/bin/env bash
set -euo pipefail

source configuration.sh
source prepareHost.sh
source installKubespray.sh

mkdir -p logs

declare -A PIDS

for HOST in "${HOSTS[@]}"; do
  LOG_FILE="logs/${HOST}.log"

  configure_host "$HOST" > "$LOG_FILE" 2>&1 &

  PIDS["$HOST"]=$!

  echo "Starting for $HOST"
  echo "PID: ${PIDS[$HOST]}"
  echo "Log: $LOG_FILE"
  echo
done

FAILED=0

for HOST in "${!PIDS[@]}"; do
  PID="${PIDS[$HOST]}"

  if wait "$PID"; then
    echo "OK: $HOST — log: logs/${HOST}.log"
  else
    echo "ERROR: $HOST — check log: logs/${HOST}.log"
    FAILED=1
  fi
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "At least one node has failed"
  echo "Skipping; ansible-playbook."
  exit 1
fi

echo "Starting kubespray installation for $ADMIN_NODE"
run_kubespray_on_admin > "logs/${ADMIN_NODE}-kubespray.log" 2>&1

echo "Starting Argo CD installation for $ADMIN_NODE"
install_argocd_withHelm_on_admin > "logs/${ADMIN_NODE}-argocd.log" 2>&1