#!/bin/bash

# Step 1: Remove the Vault binary from the ~/bin directory
echo "Removing Vault from ~/bin directory..."
rm -f ~/bin/vault

# Step 2: Remove the PATH modification from ~/.bashrc if it exists
echo "Removing ~/bin from PATH in ~/.bashrc..."
sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc

# Step 3: Source the ~/.bashrc file to update the PATH without the ~/bin
echo "Reloading the shell configuration..."
source ~/.bashrc

# Step 4: Clean up any downloaded Vault zip files (optional)
echo "Cleaning up any leftover Vault installation files..."
rm -f vault_*_linux_amd64.zip

# Final step: Confirmation
echo "Vault has been successfully uninstalled from the local environment."

