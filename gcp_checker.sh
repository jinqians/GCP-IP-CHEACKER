#!/bin/bash

# author: jinqian 
# 网站: jinqians.com

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to print messages in the selected language
print_msg() {
  if [ "$LANG" == "en" ]; then
    echo "$1"
  else
    echo "$2"
  fi
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

# Check and install dependencies
print_msg "Checking and installing dependencies..." "检查并安装依赖项..."
if ! command_exists gcloud; then
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  sudo apt-get update && sudo apt-get install -y google-cloud-cli
  print_msg "gcloud CLI installed." "gcloud CLI 已安装。"
fi

# Initialize gcloud CLI if not already initialized
if [ ! -f "$HOME/.config/gcloud/configurations/config_default" ]; then
  print_msg "Initializing gcloud CLI..." "初始化 gcloud CLI..."
  gcloud init
fi

# Ensure sufficient permissions
print_msg "Logging in to ensure sufficient permissions..." "登录以确保具有足够的权限..."
gcloud auth login

# Get project ID and region, store them in a file if not already set
CONFIG_FILE="$HOME/.gcloud_config"
if [ ! -f "$CONFIG_FILE" ]; then
  gcloud projects list
  read -p "$(print_msg "Please enter your project ID: " "请输入你的项目ID: ")" PROJECT_ID
  gcloud config set project $PROJECT_ID

  read -p "$(print_msg "Please enter your preferred region: " "请输入你偏好的区域: ")" REGION
  gcloud config set compute/region $REGION

  read -p "$(print_msg "Please enter your preferred zone: " "请输入你偏好的区域: ")" ZONE
  gcloud config set compute/zone $ZONE

  echo "PROJECT_ID=$PROJECT_ID" > "$CONFIG_FILE"
  echo "REGION=$REGION" >> "$CONFIG_FILE"
  echo "ZONE=$ZONE" >> "$CONFIG_FILE"
else
  source "$CONFIG_FILE"
fi

# Get the instance name
INSTANCE_NAME=$(gcloud compute instances list --format="value(name)" | head -n 1)

# Temporarily comment out the IP check to test IP change
# CURRENT_IP=$(curl -s ifconfig.me)
# if ping -c 5 -W 2 -i 0.2 www.itdog.cn | grep -q "100% packet loss"; then
print_msg "Current IP is blocked. Proceeding with IP change." "当前 IP 已被墙。正在更换 IP。"

# List available IP addresses and store the name of the first available IP
IP_NAME=$(gcloud compute addresses list --filter="status=RESERVED" --format="value(name)" --regions=$REGION | head -n 1)

if [ -n "$IP_NAME" ]; then
  # Delete the existing reserved IP address
  gcloud compute addresses delete $IP_NAME --region=$REGION -q

  # Generate new IP name by appending a number to the old IP name
  NEW_IP_NAME="${IP_NAME}-1"
else
  # Fallback IP name if none exists
  NEW_IP_NAME="new-ip-1"
fi

# Create a new IP address
gcloud compute addresses create $NEW_IP_NAME --region=$REGION

# Get the new IP address
NEW_IP=$(gcloud compute addresses describe $NEW_IP_NAME --region=$REGION --format="value(address)")

if [ -z "$NEW_IP" ]; then
  print_msg "Failed to obtain a new IP address." "获取新 IP 地址失败。"
  exit 1
fi

# Delete the current access config
gcloud compute instances delete-access-config $INSTANCE_NAME --access-config-name="external-nat"

# Assign the new IP address to the instance
gcloud compute instances add-access-config $INSTANCE_NAME --access-config-name="external-nat" --address=$NEW_IP

print_msg "IP address successfully changed to $NEW_IP." "IP 地址已成功更换为 $NEW_IP。"
# else
#   print_msg "Current IP is not blocked. No change necessary." "当前 IP 未被墙。无需更换。"
# fi
