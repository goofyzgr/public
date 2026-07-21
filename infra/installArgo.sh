install_argocd_on_admin() {
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