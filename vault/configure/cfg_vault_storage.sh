#!/usr/bin/env bash

##Variables
# USE_CONSUL - do we use Consul as a back end
# CONSUL_TOKEN - the Consul ACL token if needed
# NODEID - the node ID in case we're using Integrated Raft Storage instead of Consul

sudo chown -R vault /etc/vault.d

# If we are using Consul as a backend
if [ ! -z "$USE_CONSUL" ]; then
    cat <<EOF >/etc/vault.d/storage.hcl
storage "consul" {
address = "127.0.0.1:8500"
path    = "vault"
#token   = "${CONSUL_TOKEN}
}
EOF

    # If consul token was not empty, remove the comment as to use it
    if [ ! -z "$CONSUL_TOKEN" ]; then
        sed -i 's/#token/token/' /etc/vault.d/vault.hcl
    fi
else
    # if we're using Integrated storage as a backend
    # Set up Raft directory
    sudo mkdir -p /var/raft
    sudo chown -R vault /var/raft
    cat <<EOF >/etc/vault.d/storage.hcl
storage "raft" {
  path    = "/var/raft/"
  node_id = "$(hostname)"
}
EOF
fi