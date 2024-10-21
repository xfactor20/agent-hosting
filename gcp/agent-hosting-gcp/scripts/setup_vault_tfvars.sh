#!/bin/bash


# PREREQUISITES 

# 1. Docker is installed on the VM host or PC Client
# 2. Vault is installed on the VM host or PC Client. Reference instructions here: https://developer.hashicorp.com/vault/install 

#    Ubuntu/Debian:
#          wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
#          echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
#          sudo apt update && sudo apt install vault


# 3. Generated SSH keys exist
#    Be sure to run th following command to generate ssh private and public keys BEFORE running this script.  It will fail otherwise
#    Run the following command.  Accept all default values. Leave the passphrase blank
#
#       ssh-keygen -t rsa -b 4096 -C "vault-server-access-by-<my-email-address>"


####################################################################
# set environment variables for use by terraform scripts
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN="root"

# echo "Setting vault address: $VAULT_ADDR and vault token: $VAULT_TOKEN variables..."
# echo "The Vault address: $VAULT_ADDR. The Vault token: $VAULT_TOKEN"


####################################################################
# Step 1: Check if Vault is installed, install if not. Proceed otherwise

# Function to install Vault
install_vault() {
    echo "Installing Vault..."
    
    # Add the HashiCorp GPG key
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

    # Add the official HashiCorp Linux repository
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

    # Update the package list
    sudo apt-get update

    # Install Vault
    sudo apt-get install -y vault

    echo "Vault installation completed."
}

# Function to check if Vault is installed
check_vault_installed() {
    if ! command -v vault &> /dev/null; then
        echo "Vault is not installed."
        return 1
    else
        echo "Vault is already installed."
        return 0
    fi
}

# Check if Vault_installed() bool for installation guidance.  
check_vault_installed
if [ $? -ne 0 ]; then
    install_vault
fi

####################################################################
# Step 2: Run an explicit version container of the Vault server

VAULT_CONTAINER="vault-dev"

# Check if the Docker container 'vault-dev' is running
if [ $(docker ps --filter "name=$VAULT_CONTAINER" --filter "status=running" -q) ]; then
    echo "The '$VAULT_CONTAINER' container is already running."
else
    echo "The 'vault-dev' container is not running. Starting the container..."
    echo " #################  BYPASS VAULT DOCKER FOR NOW.  ENABLE WHEN APPLICABLE ######" 
    docker run -d --name $VAULT_CONTAINER -p 8200:8200 -e 'VAULT_DEV_ROOT_TOKEN_ID=root' hashicorp/vault:1.13.3
    if [ $? -eq 0 ]; then
        echo "'$VAULT_CONTAINER' container started successfully."
    else
        echo "Failed to start '$VAULT_CONTAINER' container."
    fi
fi

echo "Making sure Vault server is running prior to setting up secret keys..."

while ! curl -s "$VAULT_ADDR/v1/sys/health" | grep '"sealed":false'; do
    echo "Waiting for Vault to be ready..."
    sleep 2
done


####################################################################
# Step 3: Create Secrets in Vault

echo "Verifying and setting up keys on Vault server now..."

# Define the Vault path
vault_path="secret/gcp/k8s_beta_ssh_keys"
private_key_var="private_key"
public_key_var="public_key"

# Check if the Vault path exists with the required variables
output=$(vault kv get -field=$private_key_var $vault_path 2>&1)
if [[ $output == *"No value found"* ]]; then
  echo "Keys not found, creating them..."

  # Store the SSH keys in Vault
  vault kv put $vault_path private_key="$(cat ~/.ssh/id_rsa)" public_key="$(cat ~/.ssh/id_rsa.pub)"

  echo "SSH keys have been stored in Vault."
else
  echo "Keys already exist at the specified path on the Vault server"
fi

# For reference only
# vault secrets enable -path=secret kv
# vault kv put secret/gcp/k8s_beta_ssh_keys private_key="$(cat ~/.ssh/id_rsa)" public_key="$(cat ~/.ssh/id_rsa.pub)"

echo "DONE: Setting up keys on Vault repository command..." 

####################################################################
# Step 4: Create Terraform Variables
tf_vars_file="terraform.tfvars"

NOTE: Default settings for region and zone listed. Change here and execute for desired environment runtime

echo "Creating terraform variables file: $tf_vars_file" 

cat > $tf_vars_file <<EOF
gcp_project_id = "$(gcloud config get-value project)"
gcp_region     = "us-west1"
gcp_zone       = "us-west1-a"
vault_address  = "$VAULT_ADDR"
vault_token    = "$VAULT_TOKEN"
EOF

if [ -e "$tf_vars_file" ]; then
    echo "The file ' $tf_vars_file' exists."
    echo "Vault server and Terraform variables are set up and ready to use."
else
    echo "ERROR: The file ' $tf_vars_file' does not exist.  Please review and fix the process.  Once resolved, run this part again to set up Terraform variables file"
fi

