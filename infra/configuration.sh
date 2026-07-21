#ssh user
USER="lukaskub"

#list of VMs
HOSTS=(
  "20.169.136.5"
  "20.169.239.237"
  "40.117.250.160"
)

#admin node from where ansible is run
ADMIN_NODE="20.169.136.5"

KUBESPAY_REPO="https://github.com/kubernetes-sigs/kubespray"

PRIVATE_KEY_PATH="~/.ssh/private_key"
INVENTORY_PATH="$HOME/public/infra/kubespray/inventory.yaml"