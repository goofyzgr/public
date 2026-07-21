#ssh user
USER="lukaskub"

#list of VMs
HOSTS=(
  "13.72.76.160"
  "20.102.120.74"
  "20.120.100.187"
)

#admin node from where ansible is run
ADMIN_NODE="13.72.76.160"

KUBESPAY_REPO="https://github.com/kubernetes-sigs/kubespray"

PRIVATE_KEY_PATH="~/.ssh/private_key"
INVENTORY_PATH="$HOME/public/infra/kubespray/inventory.yaml"