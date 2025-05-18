# 检查 AWS CLI 是否安装
function Check-AwsCli {
    Write-Host "`n🧪 检查 AWS CLI..."
    $awsCli = Get-Command "aws" -ErrorAction SilentlyContinue
    if ($awsCli) {
        Write-Host "✅ AWS CLI 已安装"
        return $true
    } else {
        Write-Host "❌ 未检测到 AWS CLI，正在下载安装..."
        Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "$env:TEMP\AWSCLIV2.msi"
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$env:TEMP\AWSCLIV2.msi`" /quiet"
        Remove-Item "$env:TEMP\AWSCLIV2.msi"
        return (Get-Command "aws" -ErrorAction SilentlyContinue) -ne $null
    }
}

# 检查 Session Manager 插件（SSM）是否安装
function Check-SessionManagerPlugin {
    Write-Host "`n🧪 检查 Session Manager 插件..."
    $ssm = Get-Command "session-manager-plugin" -ErrorAction SilentlyContinue
    if ($ssm) {
        Write-Host "✅ Session Manager 插件已安装"
        return $true
    } else {
        Write-Host "❌ 未检测到 SSM 插件，正在下载安装..."
        Invoke-WebRequest "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile "$env:TEMP\SessionManagerPluginSetup.exe"
        Start-Process "$env:TEMP\SessionManagerPluginSetup.exe" -Wait
        Remove-Item "$env:TEMP\SessionManagerPluginSetup.exe"
        return (Get-Command "session-manager-plugin" -ErrorAction SilentlyContinue) -ne $null
    }
}

# 检查 AWS CLI 凭证是否配置
function Check-AwsCredentials {
    Write-Host "`n🔐 检查 AWS CLI 凭证..."
    try {
        $identity = aws sts get-caller-identity --output json 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ AWS 凭证已配置：OK"
            return $true
        } else {
            throw
        }
    } catch {
        Write-Host "⚠️ AWS 凭证未配置或无效，请手动配置："
        aws configure
        Write-Host "`n⏳ 正在验证配置..."
        try {
            $identity = aws sts get-caller-identity --output json 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ 验证成功：OK"
            } else {
                Write-Host "❌ 验证失败：NO"
            }
        } catch {
            Write-Host "❌ 验证失败：NO"
        }
    }
}

# 主流程
Write-Host "`n🚀 开始执行 AWS CLI 环境检测与配置脚本"

$cliOk = Check-AwsCli
$ssmOk = Check-SessionManagerPlugin

if ($cliOk -and $ssmOk) {
    Write-Host "`n✅ CLI 和 SSM 插件准备完毕"
    Check-AwsCredentials
} else {
    Write-Host "`n❌ 安装失败，请手动检查 AWS CLI 和 Session Manager 插件"
}
