#!/bin/bash

# Git 安装初始化脚本

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 引入通用参数解析函数库
source "${SCRIPT_DIR}/../utils/parse-args.sh" "$@"

# 引入日志工具
source "${SCRIPT_DIR}/../utils/logger.sh"

# 检查 Git 是否已安装（幂等性检查）
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version 2>/dev/null)
    log_info "检测到 Git 已安装: $GIT_VERSION"
    log_success "Git 已就绪，跳过安装步骤"
    exit 0
fi

log_info "开始安装 Git..."

# 更新软件包列表
log_info "更新软件包列表..."
if ! sudo apt update; then
    log_error "更新软件包列表失败"
    exit 1
fi

# 安装 Git
log_info "安装 Git..."
if sudo apt install -y git; then
    log_success "Git 安装成功"
    
    # 验证安装
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version 2>/dev/null)
        log_success "Git 安装验证成功: $GIT_VERSION"
    else
        log_error "Git 安装后验证失败"
        exit 1
    fi
else
    log_error "Git 安装失败"
    exit 1
fi

log_success "Git 初始化完成！"
