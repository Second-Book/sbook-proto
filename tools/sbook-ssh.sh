#!/bin/bash
# SSH tool for executing commands on sbook-dev server
# Usage: ./tools/sbook-ssh.sh <command>
# Example: ./tools/sbook-ssh.sh "sudo -u postgres psql -c '\du'"

set -e

SSH_HOST="sbook-dev"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <command>"
    echo "Example: $0 'sudo -u postgres psql -c \"\\du\"'"
    echo ""
    echo "Common diagnostic commands:"
    echo "  $0 'sudo -u postgres psql -c \"\\du\"'  # List users"
    echo "  $0 'sudo -u postgres psql -c \"\\l\"'   # List databases"
    echo "  $0 'sudo cat /etc/postgresql/*/main/pg_hba.conf | grep -v \"^#\" | grep -v \"^$\"'  # Check auth config"
    exit 1
fi

# Execute command on remote server
# -o RemoteCommand=none overrides RemoteCommand from SSH config to allow passing commands
ssh -o RemoteCommand=none "$SSH_HOST" "$@"

