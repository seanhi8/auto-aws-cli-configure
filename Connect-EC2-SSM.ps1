# 默认区域
$defaultRegion = "ap-northeast-1"
$regionInput = Read-Host "请输入 AWS Region (默认: $defaultRegion)"
if ([string]::IsNullOrWhiteSpace($regionInput)) {
    $region = $defaultRegion
} else {
    $region = $regionInput.Trim()
}

Write-Host "使用区域: $region"

# 获取所有运行中的实例
Write-Host "正在获取 Region $region 中运行的 EC2 实例..."
$instances = aws ec2 describe-instances --region $region --filters "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[]' | ConvertFrom-Json

if (-not $instances -or $instances.Count -eq 0) {
    Write-Host "未找到任何运行中的实例。"
    exit
}

# 显示实例列表
Write-Host "请选择你要连接的实例："
for ($i=0; $i -lt $instances.Count; $i++) {
    $inst = $instances[$i]
    $nameTag = ($inst.Tags | Where-Object { $_.Key -eq "Name" }).Value
    if (-not $nameTag) { $nameTag = "无名" }
    $publicIp = if ($inst.PublicIpAddress) { $inst.PublicIpAddress } else { "无公网IP" }
    Write-Host "$($i+1). InstanceId: $($inst.InstanceId) | Name: $nameTag | PrivateIP: $($inst.PrivateIpAddress) | PublicIP: $publicIp"
}

# 让用户选择
[int]$choice = 0
do {
    $choice = Read-Host "请输入序号 (1 - $($instances.Count))"
} while ($choice -lt 1 -or $choice -gt $instances.Count)

$selectedInstance = $instances[$choice - 1]

Write-Host "你选择了实例 $($selectedInstance.InstanceId)，开始连接..."

# 调用 Session Manager 连接
aws ssm start-session --target $selectedInstance.InstanceId --region $region
