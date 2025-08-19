#!/bin/bash

# Check if .env file exists
if [ ! -f ../.env ]; then
    echo "Error: .env file not found in parent directory"
    exit 1
fi

# Source the .env file
set -a
source ../.env
set +a

# Run the ansible playbook with all arguments passed to this script
ansible-playbook -i inventory.ini install_node_exporter.yml
