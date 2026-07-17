#!/usr/bin/env bash
set -euo pipefail

USER="lukaskub"

HOSTS=(
  "52.188.120.181"
  "40.114.69.164"
  "168.61.51.85"
)

ADMIN_NODE="52.188.120.181"
PRIVATE_KEY_PATH="~/.ssh/private_key"

mkdir -p logs

configure_host() {
  local HOST="$1"

  echo "===== Konfiguruję $HOST ====="
  echo "Start: $(date)"

  ssh -A -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$USER@$HOST" \
    'bash -s' "$HOST" "$ADMIN_NODE" <<'REMOTE_SCRIPT'
set -euo pipefail

HOST="$1"
ADMIN_NODE="$2"

export DEBIAN_FRONTEND=noninteractive

echo "Host zdalny: $(hostname)"
echo "IP publiczne wg skryptu: $HOST"
echo "Admin node: $ADMIN_NODE"

sudo apt-get update
sudo apt-get -y upgrade

sudo apt-get install -y git python3-pip python3.12-venv

if [ ! -d kubespray ]; then
  git clone https://github.com/kubernetes-sigs/kubespray
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

if [[ "$HOST" == "$ADMIN_NODE" ]]; then
  echo "Ten host jest ADMIN_NODE — tworzę inventory/mycluster"

  rm -rf inventory/mycluster
  cp -rfp inventory/sample inventory/mycluster

  cat > inventory/mycluster/inventory.yaml <<'INVENTORY_FILE'
all:
  hosts:
    node1:
      ansible_host: 10.0.0.4
      ip: 10.0.0.4
      access_ip: 10.0.0.4
    node2:
      ansible_host: 10.0.0.5
      ip: 10.0.0.5
      access_ip: 10.0.0.5
    node3:
      ansible_host: 10.0.0.6
      ip: 10.0.0.6
      access_ip: 10.0.0.6

  vars:
    kube_vip_enabled: true
    kube_vip_arp_enabled: true
    kube_vip_controlplane_enabled: true
    kube_vip_address: 10.0.0.4
    kube_vip_services_enabled: true
    kube_vip_services_interface: eth0
    kube_vip_lb_enable: true
    kube_vip_interface: eth0
    etcd_deployment_type: host
    loadbalancer_apiserver:
      address: "{{ kube_vip_address }}"
      port: 6443

  children:
    kube_control_plane:
      hosts:
        node1:
          node_labels:
            node-role.kubernetes.io/master: master
        node2:
          node_labels:
            node-role.kubernetes.io/master: master
        node3:
          node_labels:
            node-role.kubernetes.io/master: master

    etcd:
      children:
        kube_control_plane:

    kube_node:
      hosts:
        node1:
        node2:
        node3:

    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:

    calico_rr:
      hosts: {}
INVENTORY_FILE

  echo "Utworzono inventory/mycluster/inventory.yaml"
else
  echo "Ten host nie jest ADMIN_NODE — pomijam tworzenie inventory"
fi

pip install --upgrade pip
pip install -r requirements.txt

echo "Gotowe na $(hostname)"
REMOTE_SCRIPT

  echo "Koniec: $(date)"
  echo "===== Zakończono $HOST ====="
}

run_kubespray_on_admin() {
  echo "===== Uruchamiam Kubespray na ADMIN_NODE: $ADMIN_NODE ====="
  echo "Start: $(date)"

  ssh -A -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$USER@$ADMIN_NODE" \
    'bash -s' "$PRIVATE_KEY_PATH" <<'REMOTE_ADMIN_SCRIPT'
set -euo pipefail

PRIVATE_KEY_PATH="$1"

VENVDIR="kubespray-venv"
KUBESPRAYDIR="kubespray"

echo "Host admin: $(hostname)"
echo "Katalog roboczy: $(pwd)"

if [ ! -d "$VENVDIR" ]; then
  python3 -m venv "$VENVDIR"
fi

# shellcheck disable=SC1090
source "$VENVDIR/bin/activate"

cd "$KUBESPRAYDIR"

if [ ! -f "$HOME/kubespray/inventory/mycluster/inventory.yaml" ]; then
  echo "BŁĄD: Brak pliku $HOME/kubespray/inventory/mycluster/inventory.yaml"
  exit 1
fi

if [ ! -f "$HOME/.ssh/private_key" ]; then
  echo "BŁĄD: Brak klucza prywatnego: $HOME/.ssh/private_key"
  exit 1
fi

chmod 600 "$HOME/.ssh/private_key"

ansible-playbook \
  -i "$HOME/kubespray/inventory/mycluster/inventory.yaml" \
  cluster.yml \
  -b \
  -v \
  --private-key="$HOME/.ssh/private_key"

echo "Kubespray zakończony na $(hostname)"
REMOTE_ADMIN_SCRIPT

  echo "Koniec: $(date)"
  echo "===== Zakończono Kubespray na ADMIN_NODE ====="
}

install_argocd_on_admin() {
  echo "===== Instaluję Argo CD na ADMIN_NODE: $ADMIN_NODE ====="
  echo "Start: $(date)"

  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$USER@$ADMIN_NODE" \
    'bash -s' <<'REMOTE_ARGOCD_SCRIPT'
set -euo pipefail

echo "Host admin: $(hostname)"
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config

kubectl get nodes

if ! kubectl get namespace argocd >/dev/null 2>&1; then
  kubectl create namespace argocd
else
  echo "Namespace argocd już istnieje"
fi

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo
echo "Status podów Argo CD:"
kubectl get pods -n argocd

echo
echo "Serwisy Argo CD:"
kubectl get svc -n argocd

echo
echo "Hasło początkowe dla użytkownika admin:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

echo
echo "Argo CD zainstalowany."
echo "Aby dostać się do UI, uruchom na ADMIN_NODE:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
REMOTE_ARGOCD_SCRIPT

  echo "Koniec: $(date)"
  echo "===== Zakończono instalację Argo CD ====="
}

install_argocd_withHelm_on_admin() {
  echo "===== Instaluję Helm 3 i Argo CD przez Helm na ADMIN_NODE: $ADMIN_NODE ====="
  echo "Start: $(date)"

  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$USER@$ADMIN_NODE" \
    'bash -s' <<'REMOTE_ARGOCD_HELM_SCRIPT'
set -euo pipefail

echo "Host admin: $(hostname)"

mkdir -p "$HOME/.kube"

if [ -f /etc/kubernetes/admin.conf ] && [ ! -f "$HOME/.kube/config" ]; then
  sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
  sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
fi

kubectl get nodes

if ! command -v helm >/dev/null 2>&1; then
  echo "Helm nie jest zainstalowany — instaluję Helm 3"

  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 /tmp/get_helm.sh
  /tmp/get_helm.sh
else
  echo "Helm już jest zainstalowany:"
  helm version
fi

helm version

helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --wait

echo
echo "Status Argo CD:"
kubectl get pods -n argocd
kubectl get svc -n argocd

echo
echo "Hasło początkowe dla użytkownika admin:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

echo
echo "Argo CD zainstalowany przez Helm."
echo "UI przez port-forward:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
REMOTE_ARGOCD_HELM_SCRIPT

  echo "Koniec: $(date)"
  echo "===== Zakończono instalację Argo CD przez Helm ====="
}

declare -A PIDS

for HOST in "${HOSTS[@]}"; do
  LOG_FILE="logs/${HOST}.log"

  configure_host "$HOST" > "$LOG_FILE" 2>&1 &

  PIDS["$HOST"]=$!

  echo "Uruchomiono konfigurację hosta $HOST"
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
    echo "BŁĄD: $HOST — sprawdź log: logs/${HOST}.log"
    FAILED=1
  fi
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "Co najmniej jeden host zakończył się błędem."
  echo "Nie uruchamiam ansible-playbook."
  exit 1
fi

echo "Wszystkie maszyny zakończyły przygotowanie poprawnie."
echo "Uruchamiam ansible-playbook na ADMIN_NODE."

scp ~/.ssh/id_rsa "$USER@$ADMIN_NODE":~/.ssh/private_key
#scp -r config "$USER@$ADMIN_NODE":~

run_kubespray_on_admin > "logs/${ADMIN_NODE}-kubespray.log" 2>&1

echo "Kubespray zakończony."
echo "Log Kubespray: logs/${ADMIN_NODE}-kubespray.log"

#install_argocd_on_admin > "logs/${ADMIN_NODE}-argocd.log" 2>&1
install_argocd_withHelm_on_admin > "logs/${ADMIN_NODE}-argocd.log" 2>&1

#echo "Argo CD zainstalowany."
#echo "Log Argo CD: logs/${ADMIN_NODE}-argocd.log"