#!/bin/bash

# Check if .env file exists
if [ ! -f ../.env ]; then
    echo "Error: .env file not found in parent directory"
    exit 1
fi

###############################################
# Dynamic Inventory Builder
# Parses all TARGET_HOST entries (with preceding comments)
# in ../.env and constructs a temporary inventory so the
# playbook runs against every listed host, not just one.
###############################################

ENV_FILE=../.env
TMP_INV="/tmp/generated_inventory_$$.ini"

# Capture original .env vars (for user, key, password) without losing duplicates
set -a
source "$ENV_FILE"
set +a

SSH_KEY_OK=0
if [ -n "$SSH_PRIVATE_KEY_FILE" ] && [ -f "$SSH_PRIVATE_KEY_FILE" ]; then
    chmod 600 "$SSH_PRIVATE_KEY_FILE" 2>/dev/null || true
    SSH_KEY_OK=1
fi

echo "Building dynamic inventory from $ENV_FILE ..."

awk -v user="${TARGET_USER:-ubuntu}" -v key="${SSH_PRIVATE_KEY_FILE:-}" -v pass="${TARGET_PASSWORD:-}" 'BEGIN {FS="="}
    function sanitize(n) {gsub(/\r/,"",n); gsub(/^[# ]+/,"",n); gsub(/\(.*/,"",n); gsub(/[^A-Za-z0-9_-]/,"_",n); return n}
    /^#/ { last_comment=$0; next }
    /^TARGET_HOST=/ {
         ip=$2; name=sanitize(last_comment);
         if(name=="" || name=="_" ) { name="host" ++auto }
         # Avoid duplicates: if name reused, append index
         if(hosts[name]!="") { name=name "_" ++dups[name] } else { dups[name]=1 }
         hosts[name]=ip; order[++count]=name; last_comment="";
    }
    END {
        print "[targets]";
        for(i=1;i<=count;i++){ h=order[i]; print h " ansible_host=" hosts[h]; }
        print "\n[targets:vars]";
        print "ansible_user=" user;
        print "ansible_port=22";
        if(key!="") print "ansible_private_key_file=" key;
        if(pass!="") print "ansible_password=" pass;
        print "ansible_ssh_common_args=-o StrictHostKeyChecking=no";
    }
' "$ENV_FILE" > "$TMP_INV"

echo "Generated inventory:" >&2
grep -v '^ansible_' "$TMP_INV" >&2 || true

if [ ! -s "$TMP_INV" ]; then
    echo "Error: No TARGET_HOST entries found in $ENV_FILE" >&2
    exit 1
fi

# Decide authentication message
if [ $SSH_KEY_OK -eq 1 ]; then
    echo "Using SSH key: $SSH_PRIVATE_KEY_FILE"
elif [ -n "$TARGET_PASSWORD" ]; then
    echo "Using password authentication"
else
    echo "Warning: Neither valid key nor password found; Ansible may fail."
fi

# Run playbook(s) with generated inventory
ansible-playbook -i "$TMP_INV" "$@"

RC=$?
rm -f "$TMP_INV"
exit $RC
