#!/bin/bash

# Update and upgrade package lists
apt update || { echo "Error updating package lists"; exit 1; }
apt upgrade -y || { echo "Error upgrading packages"; exit 1; }

# Install necessary packages
pkg install -y esbuild git nodejs || { echo "Error installing packages"; exit 1; }

# Clone the repository
git clone https://github.com/SillyTavern/SillyTavern.git || { echo "Error cloning repository"; exit 1; }

# Navigate to the repository directory
cd SillyTavern || { echo "Error changing directory"; exit 1; }

# Install Node.js dependencies
npm install || { echo "Error installing Node.js dependencies"; exit 1; }

# Run the start script
./start.sh || { echo "Error running start script"; exit 1; }

echo "SillyTavern started successfully!"
