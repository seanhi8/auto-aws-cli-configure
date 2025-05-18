#!/bin/bash

echo ""
echo "🔐 AWS MFA 登录脚本"

# 配置区：请填写你的 IAM 用户名（或留空自动获取）
IAM_USER_NAME=""
PROFILE_NAME="default"

# 获取 IAM 用户名（如果未填写）
if [ -z "$IAM_USER_NAME" ]; then
  IAM_USER_NAME=$(aws sts get-caller-identity --query 'Arn' --output text | awk -F '/' '{print $2}')
  echo "👤 检测到当前用户: $IAM_USER_NAME"
fi

# 获取 MFA 设备 ARN
MFA_ARN=$(aws iam list-mfa-devices --user-name "$IAM_USER_NAME" --query 'MFADevices[0].SerialNumber' --output text)
if [ -z "$MFA_ARN" ]; then
  echo "❌ 无法获取 MFA 设备，请检查是否绑定了 MFA"
  exit 1
fi
echo "📎 MFA 设备 ARN: $MFA_ARN"

# 提示用户输入 MFA 验证码
read -p "请输入 MFA 验证码（6位数字）: " MFA_CODE

# 获取临时凭证
echo "⏳ 正在获取临时凭证..."
CREDS=$(aws sts get-session-token --serial-number "$MFA_ARN" --token-code "$MFA_CODE" --query 'Credentials' --output json)

if [ $? -ne 0 ]; then
  echo "❌ 获取临时凭证失败，请确认验证码是否正确"
  exit 1
fi

# 提取字段
AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.SessionToken')

# 写入 ~/.aws/credentials
echo ""
echo "📝 正在写入 ~/.aws/credentials 的 [$PROFILE_NAME] 配置"

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile "$PROFILE_NAME"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile "$PROFILE_NAME"
aws configure set aws_session_token "$AWS_SESSION_TOKEN" --profile "$PROFILE_NAME"

# 验证登录
echo ""
echo "✅ 验证登录状态..."
aws sts get-caller-identity --profile "$PROFILE_NAME" --output json
if [ $? -eq 0 ]; then
  echo "🎉 MFA 登录成功，你现在可以正常使用 AWS CLI。"
else
  echo "❌ 登录验证失败，请重试"
fi
