#!/bin/bash

# 工作空间初始化脚本
## 在 ~ 下创建 workspace 基础目录
## 在 workspace 下创建 logs 日志目录
## 在 workspace 下创建 configs 配置目录
## 在 workspace 下创建 scripts 脚本目录
## 在 workspace 下创建 backups 备份目录
## 在 workspace 下创建 data 数据存储目录
## 在 workspace 下创建 deploys 部署目录
## 在 workspace 下创建 docs 文档目录

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

# 定义需要创建的目录列表
declare -a DIRS=(
    "$WORKSPACE_PATH"
    "$WORKSPACE_PATH/logs"
    "$WORKSPACE_PATH/configs"
    "$WORKSPACE_PATH/scripts"
    "$WORKSPACE_PATH/backups"
    "$WORKSPACE_PATH/data"
    "$WORKSPACE_PATH/deploys"
    "$WORKSPACE_PATH/docs"
)

# 创建目录
log_info "开始创建工作空间目录结构..."
for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log_warn "目录已存在: $dir"
    else
        if mkdir -p "$dir" 2>/dev/null; then
            log_success "创建目录: $dir"
        else
            log_error "创建目录失败: $dir"
            exit 1
        fi
    fi
done

log_success "工作空间初始化完成！"
log_info "工作空间根目录: $WORKSPACE_PATH"
