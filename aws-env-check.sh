#!/bin/bash

set -e

echo ""
echo "🚀 开始执行 AWS CLI 环境检测与配置脚本"

# === 检查并安装 AWS CLI ===
check_aws_cli() {
  echo ""
  echo "🧪 检查 AWS CLI..."
  if command -v aws >/dev/null 2>&1; then
    echo "✅ AWS CLI 已安装"
  else
    echo "❌ 未检测到 AWS CLI，正在下载安装..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
    command -v aws >/dev/null 2>&1 && echo "✅ 安装成功" || { echo "❌ 安装失败"; exit 1; }
  fi
}

# === 检查并安装 Session Manager 插件 ===
check_ssm_plugin() {
  echo ""
  echo "🧪 检查 Session Manager 插件..."
  if command -v session-manager-plugin >/dev/null 2>&1; then
    echo "✅ Session Manager 插件已安装"
    return
  fi

  echo "❌ 未检测到插件，正在下载安装..."
  arch=$(uname -m)
  case "$arch" in
    x86_64) arch_dir="64bit" ;;
    aarch64) arch_dir="arm64" ;;
    *) echo "❌ 不支持的架构: $arch"; exit 1 ;;
  esac

  # 检测包管理器
  if command -v apt >/dev/null 2>&1; then
    curl -s -o "ssm.deb" "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_$arch_dir/session-manager-plugin.deb"
    sudo apt update -y && sudo apt install -y ./ssm.deb
    rm -f ssm.deb
  elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
    curl -s -o "ssm.rpm" "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_$arch_dir/session-manager-plugin.rpm"
    sudo yum install -y ./ssm.rpm 2>/dev/null || sudo dnf install -y ./ssm.rpm
    rm -f ssm.rpm
  else
    echo "❌ 未检测到受支持的包管理器（apt/yum/dnf）"
    exit 1
  fi

  command -v session-manager-plugin >/dev/null 2>&1 && echo "✅ 插件安装成功" || { echo "❌ 插件安装失败"; exit 1; }
}

# === 检查 AWS CLI 凭证 ===
check_aws_credentials() {
  echo ""
  echo "🔐 检查 AWS CLI 凭证..."
  aws sts get-caller-identity >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ AWS 凭证有效：OK"
  else
    echo "⚠️ 未检测到有效凭证，开始配置"
    aws configure
    echo ""
    echo "⏳ 正在验证配置..."
    aws sts get-caller-identity >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅ 验证成功：OK"
    else
      echo "❌ 验证失败：NO"
    fi
  fi
}

# === 主流程 ===
check_aws_cli
check_ssm_plugin
check_aws_credentials
