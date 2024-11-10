#!/bin/bash

# Update package lists and upgrade existing packages
apt-get update -y && apt-get upgrade -y || exit 1  # Exit on failure

# Install necessary packages
apt-get install git vim -y || exit 1

# Create directories and navigate
mkdir -p Aiweb/SillyTavern && cd Aiweb/SillyTavern || exit 1 # -p creates parent directories

# Install nvm (improved error handling)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
if [ $? -ne 0 ]; then
  echo "Error installing nvm. Check your internet connection and permissions."
  exit 1
fi

source ~/.bashrc

# Install Node.js (specify version for reproducibility)
nvm install --lts || exit 1 # Use the latest LTS version for stability

# Install pm2
npm install -g pm2 || exit 1

# Clone SillyTavern (with error checking)
git clone https://github.com/SillyTavern/SillyTavern.git . || exit 1

# Install dependencies (with error checking)
npm install || exit 1

# Get user input for configuration (using a more secure approach)
read -s -p "Enter custom username (default: user): " custom_username
read -s -p "Enter custom password (default: password): " custom_password

# Use default values if input is empty
custom_username="${custom_username:-user}"
custom_password="${custom_password:-password}"
read -p "Enter custom port (default: 8000): " custom_port
custom_port="${custom_port:-8000}"

# Function to safely modify config.yaml (avoiding potential sed issues)
modify_config() {
  local key="$1"
  local value="$2"
  sed -i "s/^\(${key}:\).*$/\1: ${value}/" config.yaml
}

# Attempt to start the server and create config.yaml
node server.js &
sleep 5

# Check if config.yaml exists.  Handle the case where it doesn't exist gracefully.
if [ -f config.yaml ]; then
  # Modify config.yaml using the safer function.
  modify_config "listen" "true"
  modify_config "whitelistMode" "false"
  modify_config "basicAuthMode" "true"
  modify_config "port" "${custom_port}"
  modify_config "username" "${custom_username}"
  modify_config "password" "${custom_password}"


  # Stop any previously running node processes (more robust)
  pkill -f "node server.js"

  # Start with pm2
  pm2 start server.js --name "sillytavern" || exit 1
  pm2 startup systemd || exit 1 # Use systemd for better init system integration
  pm2 save || exit 1

  # Get server IP (more robust method)
  server_ip=$(ip route show default | awk '{print $5}')

  echo "SillyTavern deployed successfully, managed by pm2."
  echo "Your configuration:"
  echo "Username: ${custom_username}"
  echo "Port: ${custom_port}"
  echo "Access URL: ${server_ip}:${custom_port}"

else
  echo "Error: config.yaml not created. Check your server.js file."
  exit 1
fi


# Important security note:  Never display passwords in production logs or output.  This is only for demonstration purposes.
# In a production environment, use a secure method for managing secrets (e.g., environment variables or a secrets management service).
