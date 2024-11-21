# https://stackoverflow.com/a/3467959
declare -A CLUSTERLABELS
declare CONCAT

CLUSTERLABELS=(
    ["eodata_access_enabled"]="true"
    ["min_node_count"]=1
    ["max_node_count"]=1
    ["auto_scaling_enabled"]="false"
    ["auto_healing_enabled"]="true"
    ["etcd_volume_type"]="hdd"
    ["master_lb_floating_ip_enabled"]="true"    
    ["lb_api_flavor"]="HA-large"
    ["worker_type"]="gpu"
)

for label in "${!CLUSTERLABELS[@]}"; do CONCAT="$CONCAT$label='${CLUSTERLABELS[$label]}',"; done

echo $CONCAT

# openstack coe cluster create \
#   --cluster-template k8s-1.23.16-vgpu-v1.0.0 \
#   --keypair cluster \
#   --master-count 1 --master-flavor eo1.large \
#   --node-count 1 --flavor <worker-flavor> \
#   --labels $CONCAT \
#   --merge-labels \
#   --master-lb-enabled \
#   <cluster-name>
