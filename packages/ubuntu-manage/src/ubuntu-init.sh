#!/bin/bash

# Ubuntu 基础环境初始化脚本
## 1. 更新软件源
## 2. 安装常用软件
## 3. 配置常用软件
## 4. 配置常用服务
## 5. 配置常用环境变量

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 引入通用参数解析函数库
source "${SCRIPT_DIR}/utils/parse-args.sh" "$@"

# 引入日志工具
source "${SCRIPT_DIR}/utils/logger.sh"

log_info "开始执行 Ubuntu 基础环境初始化..."

# 执行工作空间初始化
log_info "执行工作空间初始化..."
bash "${SCRIPT_DIR}/tasks/workspace-init.task.sh" "$@"
if [ $? -ne 0 ]; then
    log_error "工作空间初始化失败"
    exit 1
fi

# 执行 apt 初始化
log_info "执行 apt 初始化..."
bash "${SCRIPT_DIR}/tasks/apt-init.task.sh" "$@"
if [ $? -ne 0 ]; then
    log_error "apt 初始化失败"
    exit 1
fi

# 执行 docker 初始化
log_info "执行 docker 初始化..."
bash "${SCRIPT_DIR}/tasks/docker-init.task.sh" "$@"
if [ $? -ne 0 ]; then
    log_error "docker 初始化失败"
    exit 1
fi

# 执行 git 初始化
log_info "执行 git 初始化..."
bash "${SCRIPT_DIR}/tasks/git-init.task.sh" "$@"
if [ $? -ne 0 ]; then
    log_error "git 初始化失败"
    exit 1
fi

# 执行 ufw 初始化
log_info "执行 ufw 初始化..."
bash "${SCRIPT_DIR}/tasks/ufw-init.task.sh" "$@"
if [ $? -ne 0 ]; then
    log_error "ufw 初始化失败"
    exit 1
fi

log_success "Ubuntu 基础环境初始化完成！"
