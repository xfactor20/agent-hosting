#!/bin/bash

# Step 1: Download the latest version of Vault
echo "Downloading Vault..."
VAULT_VERSION="1.17.5"
wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip

# Step 2: Unzip the downloaded file
echo "Unzipping Vault..."
unzip vault_${VAULT_VERSION}_linux_amd64.zip

# Step 3: Move Vault to a local directory
echo "Moving Vault to ~/bin directory..."
mkdir -p ~/bin
mv vault ~/bin/

# Step 4: Add ~/bin to the PATH if not already added
if ! echo $PATH | grep -q "~/bin"; then
    echo "Adding ~/bin to PATH..."
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

# Step 5: Verify Vault installation
echo "Verifying Vault installation..."
vault --version

