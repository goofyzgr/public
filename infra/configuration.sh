#ssh user
USER="lukaskub"

#list of VMs
HOSTS=(
  "172.191.109.11"
  "52.188.11.100"
  "172.191.123.29"
)

#admin node from where ansible is run
ADMIN_NODE="172.191.109.11"

KUBESPAY_REPO="https://github.com/kubernetes-sigs/kubespray"

PRIVATE_KEY_PATH="~/.ssh/private_key"
INVENTORY_PATH="$HOME/public/infra/kubespray/inventory.yaml"