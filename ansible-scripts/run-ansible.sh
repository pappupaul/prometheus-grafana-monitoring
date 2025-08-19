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

# Check authentication methods
if [ -z "$SSH_PRIVATE_KEY_FILE" ] && [ -z "$TARGET_PASSWORD" ]; then
    echo "Error: Neither SSH key nor password provided in .env file"
    echo "Please set either SSH_PRIVATE_KEY_FILE or TARGET_PASSWORD"
    exit 1
fi

# If SSH key is provided, validate and set permissions
if [ ! -z "$SSH_PRIVATE_KEY_FILE" ]; then
    if [ -f "$SSH_PRIVATE_KEY_FILE" ]; then
        echo "Using SSH key authentication"
        chmod 600 "$SSH_PRIVATE_KEY_FILE"
    else
        echo "Warning: SSH key file not found at $SSH_PRIVATE_KEY_FILE"
        if [ ! -z "$TARGET_PASSWORD" ]; then
            echo "Falling back to password authentication"
        else
            echo "Error: No valid authentication method available"
            exit 1
        fi
    fi
else
    echo "Using password authentication"
fi

# Check if we need to run Python check first
if [ "$1" != "check_python.yml" ]; then
    echo "Running Python version check first..."
    ansible-playbook -i inventory.ini check_python.yml -e 'ansible_python_interpreter=/usr/bin/python3.8'
    if [ $? -ne 0 ]; then
        echo "Failed to verify/install Python3. Please check the target machine."
        exit 1
    fi
fi

# Run the actual playbook with Python3 interpreter
ansible-playbook -i inventory.ini "$@" -e 'ansible_python_interpreter=/usr/bin/python3.8'
