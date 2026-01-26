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

# 获取 region 参数，可选值为 cn 或 os，默认值为 os
REGION=$(get_arg "region" "os" "r")

# 验证区域参数值
if [ "$REGION" != "cn" ] && [ "$REGION" != "os" ]; then
    log_error "无效的区域参数 '$REGION'"
    log_error "用法: [--region|-r] [cn|os]"
    log_error "示例: --region cn  # 国内服务器"
    log_error "      --region os  # 海外服务器"
    exit 1
fi

log_info "初始化区域: $REGION"

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

# 定义原始 GitHub URL
ORIGINAL_URL="https://raw.githubusercontent.com/NoFxAiOS/nofx/main/install.sh"
# 定义代理 URL（用于国内服务器）
PROXY_URL="https://ghfast.top/https://raw.githubusercontent.com/NoFxAiOS/nofx/main/install.sh"

# 根据区域选择安装策略
# 设置 curl 超时时间为 30 秒，避免无限制等待
CURL_TIMEOUT=30

if [ "$REGION" = "cn" ]; then
    # 国内服务器：优先尝试原始地址，失败后使用代理地址
    log_info "尝试使用原始 GitHub URL（超时限制：${CURL_TIMEOUT}秒）..."
    if curl -fsSL --max-time "$CURL_TIMEOUT" "$ORIGINAL_URL" | bash; then
        log_success "nofx 安装完成（使用原始地址）"
    else
        log_warn "原始地址访问失败，尝试使用 GitHub 镜像代理（超时限制：${CURL_TIMEOUT}秒）..."
        if curl -fsSL --max-time "$CURL_TIMEOUT" "$PROXY_URL" | bash; then
            log_success "nofx 安装完成（使用镜像代理）"
        else
            log_error "nofx 安装失败（原始地址和镜像代理均失败）"
            exit 1
        fi
    fi
else
    # 海外服务器：直接使用原始 GitHub URL
    log_info "使用原始 GitHub URL（海外服务器，超时限制：${CURL_TIMEOUT}秒）..."
    if curl -fsSL --max-time "$CURL_TIMEOUT" "$ORIGINAL_URL" | bash; then
        log_success "nofx 安装完成"
    else
        log_error "nofx 安装失败"
        exit 1
    fi
fi
