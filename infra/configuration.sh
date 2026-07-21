#ssh user
USER="lukaskub"

#list of VMs
HOSTS=(
  "20.51.133.196"
  "20.121.184.69"
  "20.85.234.75"
)

#admin node from where ansible is run
ADMIN_NODE="20.51.133.196"

KUBESPAY_REPO="https://github.com/kubernetes-sigs/kubespray"

PRIVATE_KEY_PATH="~/.ssh/private_key"