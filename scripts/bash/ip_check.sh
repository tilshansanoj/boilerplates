#!/bin/bash

# Your provided IP list (from the question)
provided_ips=(
    127.0.0.1
    192.168.1.2
)

# Get Azure public IPs using Azure CLI
echo "Fetching Azure public IPs..."
azure_public_ips=$(az network public-ip list --query "[].ipAddress" -o tsv)

# Get Azure private IPs (if needed)
# echo "Fetching Azure private IPs..."
# azure_private_ips=$(az vm list-ip-addresses --query "[].virtualMachine.network.privateIpAddresses[]" -o tsv)

# Combine all Azure IPs
azure_ips=($azure_public_ips $azure_private_ips)

# Check for matches
echo -e "\nChecking for matches..."
matches=()
for ip in "${azure_ips[@]}"; do
    if [[ " ${provided_ips[@]} " =~ " ${ip} " ]]; then
        matches+=("$ip")
    fi
done

# Find IPs in Azure but not in provided list
non_matches=()
for ip in "${azure_ips[@]}"; do
    if [[ ! " ${provided_ips[@]} " =~ " ${ip} " ]]; then
        non_matches+=("$ip")
    fi
done

# Print results
echo -e "\n=== RESULTS ==="
echo -e "\nIPs in BOTH lists (matches):"
printf '%s\n' "${matches[@]}"

echo -e "\nIPs ONLY in Azure (not in your list):"
printf '%s\n' "${non_matches[@]}"

echo -e "\nComparison complete."