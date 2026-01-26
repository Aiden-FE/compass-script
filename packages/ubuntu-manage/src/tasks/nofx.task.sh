#!/bin/bash

# nofx 初始化脚本
## 安装 nofx 软件包
## 配置 nofx 软件包
## 启动 nofx 软件包

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 引入通用参数解析函数库
source "${SCRIPT_DIR}/../utils/parse-args.sh" "$@"

# 引入日志工具
source "${SCRIPT_DIR}/../utils/logger.sh"

# 获取 workspace 路径参数，默认为 ~/workspace
WORKSPACE_PATH=$(get_arg "workspace" "$HOME/workspace" "w")

# 展开路径中的 ~
WORKSPACE_PATH="${WORKSPACE_PATH/#\~/$HOME}"

log_info "工作空间路径: $WORKSPACE_PATH"

# 定义 nofx 安装目录
NOFX_INSTALL_DIR="${WORKSPACE_PATH}/deploys/nofx"

log_info "nofx 安装目录: $NOFX_INSTALL_DIR"

# 创建 nofx 安装目录
mkdir -p "$NOFX_INSTALL_DIR"

log_success "nofx 安装目录创建成功"

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装，请先执行 docker-init.task.sh"
    exit 1
fi

# 检查 Docker 服务是否运行
if ! systemctl is-active --quiet docker 2>/dev/null && ! docker ps &> /dev/null; then
    log_error "Docker 服务未运行，请先启动 Docker 服务"
    exit 1
fi

# 进入 nofx 安装目录并执行安装
log_info "进入 nofx 安装目录: $NOFX_INSTALL_DIR"
cd "$NOFX_INSTALL_DIR" || {
    log_error "无法进入 nofx 安装目录"
    exit 1
}

log_info "开始安装 nofx..."
# 安装或更新 nofx
curl -fsSL https://raw.githubusercontent.com/NoFxAiOS/nofx/main/install.sh | bash

if [ $? -eq 0 ]; then
    log_success "nofx 安装完成"
else
    log_error "nofx 安装失败"
    exit 1
fi
