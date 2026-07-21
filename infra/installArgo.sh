install_argocd_on_admin() {
  echo "===== Installing Argo CD on ADMIN_NODE: $ADMIN_NODE ====="
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
  echo "Namespace argocd exists"
fi

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo
echo "Pods state Argo CD:"
kubectl get pods -n argocd

echo
echo "Services state Argo CD:"
kubectl get svc -n argocd

echo
echo "Password for admin:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

echo
echo "Argo CD installed."
echo "To open UI run on ADMIN_NODE:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
REMOTE_ARGOCD_SCRIPT

  echo "End: $(date)"
  echo "===== Finishing Argo CD installation ====="
}