#!/bin/bash

# List of IPs to check
IP_LIST=(
    172.167.167.77
    20.108.246.157
    172.167.43.106
    20.162.218.251
    172.166.213.134
    4.161.51.118
    20.39.217.225
)

# Function to get detailed resource information by IP
get_resource_details() {
    local ip=$1
    echo -e "\n\e[1mChecking IP: $ip\e[0m"

    # Check public IPs first
    public_ip_info=$(az network public-ip list --query "[?ipAddress=='$ip']" -o json)

    if [ "$public_ip_info" != "[]" ]; then
        echo -e "\e[32mPublic IP found:\e[0m"
        name=$(echo "$public_ip_info" | jq -r '.[0].name')
        rg=$(echo "$public_ip_info" | jq -r '.[0].resourceGroup')
        attached_to=$(echo "$public_ip_info" | jq -r '.[0].ipConfiguration.id' | awk -F'/' '{print $9}')

        echo "Resource Group: $rg"
        echo "Public IP Name: $name"

        if [ "$attached_to" != "null" ]; then
            resource_type=$(echo "$public_ip_info" | jq -r '.[0].ipConfiguration.id' | awk -F'/' '{print $7}')
            echo "Attached to: $attached_to (Type: $resource_type)"

            # Get more details about the attached resource
            case $resource_type in
                "networkInterfaces")
                    nic_info=$(az network nic show --name $attached_to --resource-group $rg -o json)
                    vm_id=$(echo "$nic_info" | jq -r '.virtualMachine.id')
                    if [ "$vm_id" != "null" ]; then
                        vm_name=$(echo "$vm_id" | awk -F'/' '{print $9}')
                        echo "Associated VM: $vm_name"
                    fi
                    ;;
                "loadBalancers")
                    lb_info=$(az network lb show --name $attached_to --resource-group $rg -o json)
                    echo "Load Balancer Details:"
                    echo "  SKU: $(echo "$lb_info" | jq -r '.sku.name')"
                    ;;
                "applicationGateways")
                    agw_info=$(az network application-gateway show --name $attached_to --resource-group $rg -o json)
                    echo "Application Gateway Details:"
                    echo "  Tier: $(echo "$agw_info" | jq -r '.sku.tier')"
                    ;;
            esac
        else
            echo "This public IP is not currently attached to any resource"
        fi
    else
        # Check NICs (for private IPs)
        nic_info=$(az network nic list --query "[?ipConfigurations[].privateIpAddress | contains(@, '$ip')]" -o json)

        if [ "$nic_info" != "[]" ]; then
            echo -e "\e[32mPrivate IP found:\e[0m"
            nic_name=$(echo "$nic_info" | jq -r '.[0].name')
            rg=$(echo "$nic_info" | jq -r '.[0].resourceGroup')
            vm_id=$(echo "$nic_info" | jq -r '.[0].virtualMachine.id')

            echo "Resource Group: $rg"
            echo "NIC Name: $nic_name"

            if [ "$vm_id" != "null" ]; then
                vm_name=$(echo "$vm_id" | awk -F'/' '{print $9}')
                echo "Attached to VM: $vm_name"

                # Get VM details
                vm_info=$(az vm show --name $vm_name --resource-group $rg -o json 2>/dev/null)
                if [ ! -z "$vm_info" ]; then
                    echo "VM Details:"
                    echo "  Size: $(echo "$vm_info" | jq -r '.hardwareProfile.vmSize')"
                    echo "  OS: $(echo "$vm_info" | jq -r '.storageProfile.osDisk.osType')"
                    echo "  Status: $(az vm get-instance-view --name $vm_name --resource-group $rg --query instanceView.statuses[1].displayStatus -o tsv)"
                fi
            fi

            # Check if NIC is part of a scale set
            scale_set=$(echo "$nic_info" | jq -r '.[0].ipConfigurations[].loadBalancerBackendAddressPools[].id' | grep virtualMachineScaleSets)
            if [ ! -z "$scale_set" ]; then
                scale_set_name=$(echo "$scale_set" | awk -F'/' '{print $9}')
                echo "Part of Virtual Machine Scale Set: $scale_set_name"
            fi
        else
            echo -e "\e[31mNo Azure resource found with IP: $ip\e[0m"
        fi
    fi
}

# Main execution
echo -e "\e[1mAzure Resource Finder by IP\e[0m"
echo "=========================="

# Check for Azure CLI
if ! command -v az &> /dev/null; then
    echo "Azure CLI not found. Please install it first."
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "jq not found. Installing..."
    sudo apt-get install -y jq || sudo yum install -y jq || brew install jq
fi

# Check each IP
for ip in "${IP_LIST[@]}"; do
    get_resource_details "$ip"
done

echo -e "\n\e[1mSearch complete.\e[0m"