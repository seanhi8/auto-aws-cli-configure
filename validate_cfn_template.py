import os
import sys
import subprocess
import json
from pathlib import Path

# 自动检测并导入 colorama，用于高亮终端输出
def install_and_import_colorama():
    try:
        import colorama
    except ImportError:
        print("[提示] 未检测到 colorama，正在自动安装...")
        subprocess.run([sys.executable, "-m", "pip", "install", "colorama"])
    finally:
        # 引入颜色组件
        global Fore, Style, init
        from colorama import Fore, Style, init
        init(autoreset=True)

install_and_import_colorama()

# 格式化输出（颜色）
def print_success(msg): print(Fore.GREEN + msg)
def print_error(msg): print(Fore.RED + msg)
def print_info(msg): print(Fore.CYAN + msg)

# 检查 AWS CLI 是否已安装
def check_aws_cli_installed():
    print_info("[检查] 是否已安装 AWS CLI...")
    result = subprocess.run("aws --version", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        print_error("[错误] 未检测到 AWS CLI，请先手动安装： https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html")
        sys.exit(1)
    print_success("[通过] AWS CLI 已安装。")

# 检查 AWS CLI 是否已配置凭证（使用 STS 获取当前身份）
def check_aws_configured():
    print_info("[检查] AWS CLI 是否已配置凭证...")
    result = subprocess.run(["aws", "sts", "get-caller-identity"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print_error("[警告] AWS CLI 尚未配置，请运行 'aws configure' 设置凭证。")
        sys.exit(1)
    print_success("[通过] AWS CLI 凭证已配置。")

# 检查并安装 CloudFormation 结构检查工具 cfn-lint
def check_and_install_cfn_lint():
    print_info("[检查] 是否已安装 cfn-lint...")
    try:
        subprocess.run(["cfn-lint", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        print_success("[通过] cfn-lint 已安装。")
    except subprocess.CalledProcessError:
        print_info("[提示] 未检测到 cfn-lint，正在自动安装...")
        subprocess.run([sys.executable, "-m", "pip", "install", "cfn-lint"])
        print_success("[完成] cfn-lint 安装完成。")

# 判断模板中是否包含 CDK 生成标记
def is_cdk_template(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            # 简单通过关键字识别 CDK 生成模板
            return 'CDKMetadata' in content or 'aws:cdk:path' in content
    except Exception as e:
        print_error(f"[错误] 无法读取文件: {e}")
        return False

# 执行 shell 命令并返回输出与状态
def run_command(command):
    try:
        result = subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return (True, result.stdout)
    except subprocess.CalledProcessError as e:
        return (False, e.stderr)

# 使用 cfn-lint 对模板做结构级检查
def validate_with_cfn_lint(filepath):
    print_info("\n[步骤1] 使用 cfn-lint 检查结构...")
    ok, output = run_command(f"cfn-lint \"{filepath}\"")
    if ok:
        print_success("[通过] cfn-lint 检查通过。")
    else:
        print_error("[失败] cfn-lint 检查失败：")
        print(output)

# 使用 AWS CLI 验证 CloudFormation 模板语法
def validate_with_aws_cli(filepath):
    print_info("\n[步骤2] 使用 AWS CLI 验证语法...")
    ok, output = run_command(f"aws cloudformation validate-template --template-body file://{filepath}")
    if ok:
        print_success("[通过] AWS CLI 校验通过。")
        # 尝试解析参数信息
        try:
            data = json.loads(output)
            if "Parameters" in data:
                keys = ', '.join(p['ParameterKey'] for p in data['Parameters'])
                print_info(f"[信息] 检测到参数：{keys}")
        except:
            pass
    else:
        print_error("[失败] AWS CLI 校验失败：")
        print(output)

# 主程序入口
def main():
    # 执行所有依赖项检查
    check_aws_cli_installed()
    check_and_install_cfn_lint()
    check_aws_configured()

    # 提示用户输入模板文件路径
    filepath = input("\n请输入 CloudFormation 模板路径（.yaml 或 .json）: ").strip()
    path = Path(filepath)

    # 基本校验：文件是否存在、格式是否符合
    if not path.is_file():
        print_error("[错误] 文件不存在。")
        sys.exit(1)

    if not path.suffix.lower() in ['.yaml', '.yml', '.json']:
        print_error("[错误] 仅支持 .yaml, .yml, .json 文件。")
        sys.exit(1)

    print_info(f"\n[信息] 正在检查文件: {filepath}")
    # 判断是否为 CDK 模板
    if is_cdk_template(filepath):
        print_info("[识别] 这是一个 CDK 生成的模板。")
    else:
        print_info("[识别] 这是一个普通 CloudFormation 模板。")

    # 结构与语法检查
    validate_with_cfn_lint(filepath)
    validate_with_aws_cli(filepath)

# 启动程序
if __name__ == "__main__":
    main()
