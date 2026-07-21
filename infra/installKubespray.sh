run_kubespray_on_admin() {
  echo "===== Installing Kubespray on ADMIN_NODE: $ADMIN_NODE ====="
  echo "Start: $(date)"

  ssh -A -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$USER@$ADMIN_NODE" \
    'bash -s' "$PRIVATE_KEY_PATH" <<'REMOTE_ADMIN_SCRIPT'
set -euo pipefail

PRIVATE_KEY_PATH="$1"

VENVDIR="kubespray-venv"
KUBESPRAYDIR="kubespray"

echo "Host admin: $(hostname)"
echo "Work directory: $(pwd)"

if [ ! -d "$VENVDIR" ]; then
  python3 -m venv "$VENVDIR"
fi

# shellcheck disable=SC1090
source "$VENVDIR/bin/activate"

cd "$KUBESPRAYDIR"

if [ ! -f "$INVENTORY_PATH" ]; then
  echo "ERROR: No $INVENTORY_PATH file"
  exit 1
fi

if [ ! -f "$HOME/.ssh/private_key" ]; then
  echo "ERROR: No private key: $HOME/.ssh/private_key"
  exit 1
fi

chmod 600 "$HOME/.ssh/private_key"

ansible-playbook \
  -i "$INVENTORY_PATH" \
  cluster.yml \
  -b \
  -v \
  --private-key="$HOME/.ssh/private_key"

echo "Kubespray done on $(hostname)"
REMOTE_ADMIN_SCRIPT

  echo "End: $(date)"
  echo "===== Kubespray done on ADMIN_NODE ====="
}