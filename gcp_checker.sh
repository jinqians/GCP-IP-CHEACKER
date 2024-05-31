#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Language selection
echo "Please select language / 请选择语言:"
echo "1) English"
echo "2) 中文"
read -p "Enter the number / 输入数字: " lang_choice

if [ "$lang_choice" -eq 1 ]; then
  LANG="en"
elif [ "$lang_choice" -eq 2 ]; then
  LANG="zh"
else
  echo "Invalid selection. Defaulting to English."
  LANG="en"
fi

# Function to print messages in the selected language
print_msg() {
  if [ "$LANG" == "en" ]; then
    echo "$1"
  else
    echo "$2"
  fi
}

# Update packages and install dependencies if not already installed
if ! command_exists gcloud; then
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates gnupg curl

  # Import Google Cloud public key
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

  # Add gcloud CLI distribution URI as a package source
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

  # Update and install gcloud CLI
  sudo apt-get update && sudo apt-get install -y google-cloud-cli

  print_msg "gcloud CLI installed." "gcloud CLI 已安装。"
fi

# Initialize gcloud CLI if not already initialized
if ! gcloud auth list --format="value(account)" | grep -q "@"; then
  gcloud init
fi

# Get the instance name
INSTANCE_NAME=$(gcloud compute instances list --format="value(name)" | head -n 1)

# Check if the current IP is blocked
if ping -c 5 -W 2 -i 0.2 www.itdog.cn | grep -q "100% packet loss"; then
  print_msg "Current IP is blocked. Proceeding with IP change." "当前 IP 已被墙。正在更换 IP。"

  # List available IP addresses and store the name of the first available IP
  IP_NAME=$(gcloud compute addresses list --filter="status=RESERVED" --format="value(name)" | head -n 1)

  if [ -n "$IP_NAME" ]; then
    # Delete the existing reserved IP address
    gcloud compute addresses delete $IP_NAME -q
  fi

  # Create a new IP address
  NEW_IP_NAME="new-ip"
  PROJECT_ID=$(gcloud config get-value project)
  REGION=$(gcloud config get-value compute/region)
  gcloud compute addresses create $NEW_IP_NAME --project=$PROJECT_ID --region=$REGION

  # Get the new IP address
  NEW_IP=$(gcloud compute addresses describe $NEW_IP_NAME --region=$REGION --format="value(address)")

  # Delete the current access config
  gcloud compute instances delete-access-config $INSTANCE_NAME --access-config-name="External NAT"

  # Assign the new IP address to the instance
  gcloud compute instances add-access-config $INSTANCE_NAME --access-config-name="External NAT" --address=$NEW_IP

  print_msg "IP address successfully changed to $NEW_IP." "IP 地址已成功更换为 $NEW_IP。"
else
  print_msg "Current IP is not blocked. No change necessary." "当前 IP 未被墙。无需更换。"
fi
