#!/bin/bash

# apt 基础环境初始化脚本

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

# 根据区域配置软件源
if [ "$REGION" = "cn" ]; then
    log_info "配置国内镜像源（阿里云）..."
    
    # 检测 Ubuntu 版本
    UBUNTU_VERSION=$(lsb_release -cs 2>/dev/null)
    if [ -z "$UBUNTU_VERSION" ]; then
        log_warn "无法检测 Ubuntu 版本，尝试从 /etc/os-release 获取..."
        UBUNTU_VERSION=$(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release 2>/dev/null || echo "")
    fi
    
    if [ -z "$UBUNTU_VERSION" ]; then
        log_error "无法检测 Ubuntu 版本，请手动配置软件源"
        exit 1
    fi
    
    log_info "检测到 Ubuntu 版本: $UBUNTU_VERSION"
    
    SOURCES_LIST="/etc/apt/sources.list"
    
    # 检查是否已经配置了阿里云镜像源（幂等性检查）
    if [ -f "$SOURCES_LIST" ] && grep -q "mirrors.aliyun.com" "$SOURCES_LIST" 2>/dev/null; then
        log_info "检测到已配置阿里云镜像源，跳过配置步骤"
    else
        # 备份原有的 sources.list（仅在首次配置时备份）
        if [ -f "$SOURCES_LIST" ]; then
            # 检查是否已有备份文件，避免重复备份
            BACKUP_FILE="${SOURCES_LIST}.backup"
            if [ ! -f "$BACKUP_FILE" ]; then
                log_info "备份原有软件源配置..."
                sudo cp "$SOURCES_LIST" "$BACKUP_FILE" || {
                    log_error "备份软件源配置失败"
                    exit 1
                }
                log_success "软件源配置已备份"
            else
                log_info "检测到已有备份文件，跳过备份步骤"
            fi
        fi
        
        # 配置阿里云镜像源
        log_info "配置阿里云镜像源..."
        sudo tee "$SOURCES_LIST" > /dev/null <<EOF
# 阿里云 Ubuntu 镜像源
deb http://mirrors.aliyun.com/ubuntu/ $UBUNTU_VERSION main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $UBUNTU_VERSION-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $UBUNTU_VERSION-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $UBUNTU_VERSION-security main restricted universe multiverse

# 源码仓库（可选）
# deb-src http://mirrors.aliyun.com/ubuntu/ $UBUNTU_VERSION main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ $UBUNTU_VERSION-updates main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ $UBUNTU_VERSION-backports main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ $UBUNTU_VERSION-security main restricted universe multiverse
EOF
        
        if [ $? -eq 0 ]; then
            log_success "阿里云镜像源配置完成！"
        else
            log_error "阿里云镜像源配置失败"
            exit 1
        fi
    fi
else
    log_info "使用官方软件源..."
    # 使用官方源，无需修改
fi

# 更新 apt 等基础软件包
# 注意：apt update 和 apt upgrade 本身是幂等的，但每次都会执行以确保系统最新
# 如果需要跳过更新，可以通过参数控制（未来可扩展）
log_info "更新软件包列表..."
if sudo apt update; then
    log_success "软件包列表更新成功"
    log_info "升级软件包..."
    if sudo apt upgrade -y; then
        log_success "软件包升级完成"
    else
        log_error "软件包升级失败"
        exit 1
    fi
else
    log_error "软件包列表更新失败"
    exit 1
fi
