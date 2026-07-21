configure_host() {
  local HOST="$1"

  echo "Start: $(date)"

  ssh -A -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$USER@$HOST" \
    'bash -s' "$HOST" "$ADMIN_NODE" "$KUBESPAY_REPO" <<'REMOTE_SCRIPT'
set -euo pipefail

HOST="$1"
ADMIN_NODE="$2"
KUBESPAY_REPO="$3"

export DEBIAN_FRONTEND=noninteractive

echo "Host: $(hostname)"
echo "Admin node: $ADMIN_NODE"

sudo apt-get update
sudo apt-get -y upgrade

sudo apt-get install -y git python3-pip python3.12-venv

if [ ! -d kubespray ]; then
  git clone "$KUBESPAY_REPO"
else
  cd kubespray
  git pull
  cd ..
fi

VENVDIR="kubespray-venv"
KUBESPRAYDIR="kubespray"

if [ ! -d "$VENVDIR" ]; then
  python3 -m venv "$VENVDIR"
fi

# shellcheck disable=SC1090
source "$VENVDIR/bin/activate"

cd "$KUBESPRAYDIR"

pip install --upgrade pip
pip install -r requirements.txt

echo "$(hostname) ready"
REMOTE_SCRIPT

  echo "End: $(date)"
}