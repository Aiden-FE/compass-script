#!/bin/bash

# Docker 安装初始化脚本

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

# 检查 Docker 是否已安装（幂等性检查）
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version 2>/dev/null)
    log_info "检测到 Docker 已安装: $DOCKER_VERSION"
    
    # 检查 Docker 服务是否运行
    if systemctl is-active --quiet docker; then
        log_success "Docker 服务正在运行"
    else
        log_warn "Docker 已安装但服务未运行，尝试启动..."
        if sudo systemctl start docker; then
            log_success "Docker 服务启动成功"
        else
            log_error "Docker 服务启动失败"
            exit 1
        fi
    fi

    # 检查 Docker Compose 是否已安装
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version 2>/dev/null || docker compose version 2>/dev/null)
        log_info "检测到 Docker Compose 已安装: $COMPOSE_VERSION"
        log_success "Docker 环境已就绪，跳过安装步骤"
        exit 0
    else
        log_info "Docker 已安装，但 Docker Compose 未安装，继续安装 Docker Compose..."
    fi
else
    log_info "开始安装 Docker..."
fi

# 安装必要的依赖包（仅当需要安装 Docker 时）
if ! command -v docker &> /dev/null; then
    log_info "安装必要的依赖包..."
    if ! sudo apt-get update; then
        log_error "更新软件包列表失败"
        exit 1
    fi
    
    # 官方文档要求的依赖包
    REQUIRED_PACKAGES="ca-certificates curl"
    if ! sudo apt-get install -y $REQUIRED_PACKAGES; then
        log_error "安装依赖包失败"
        exit 1
    fi
    log_success "依赖包安装完成"
fi

# 如果 Docker 未安装，执行安装步骤
if ! command -v docker &> /dev/null; then
    # 卸载旧版本的 Docker（如果存在）
    log_info "检查并卸载旧版本的 Docker..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # 步骤 1: 设置 Docker 的 apt 仓库
    # 参考: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
    log_info "步骤 1: 设置 Docker 的 apt 仓库..."
    
    # 创建密钥目录
    if ! sudo install -m 0755 -d /etc/apt/keyrings; then
        log_error "创建密钥目录失败"
        exit 1
    fi
    
    # 添加 Docker 官方 GPG 密钥（使用官方推荐的新方法）
    log_info "添加 Docker 官方 GPG 密钥..."
    if [ "$REGION" = "cn" ]; then
        # 使用国内镜像源
        DOCKER_GPG_KEY_URL="https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg"
        DOCKER_KEYRING_PATH="/etc/apt/keyrings/docker.asc"
    else
        # 使用官方源
        DOCKER_GPG_KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
        DOCKER_KEYRING_PATH="/etc/apt/keyrings/docker.asc"
    fi
    
    if ! sudo curl -fsSL "$DOCKER_GPG_KEY_URL" -o "$DOCKER_KEYRING_PATH"; then
        log_error "下载 Docker GPG 密钥失败"
        exit 1
    fi
    
    if ! sudo chmod a+r "$DOCKER_KEYRING_PATH"; then
        log_error "设置 GPG 密钥权限失败"
        exit 1
    fi
    log_success "Docker GPG 密钥添加成功"
    
    # 添加 Docker 仓库到 Apt sources
    log_info "添加 Docker 仓库到 Apt sources..."
    if [ "$REGION" = "cn" ]; then
        # 使用阿里云镜像源
        DOCKER_REPO_URI="https://mirrors.aliyun.com/docker-ce/linux/ubuntu"
    else
        # 使用官方源
        DOCKER_REPO_URI="https://download.docker.com/linux/ubuntu"
    fi
    
    # 使用官方推荐的方式获取 Ubuntu 版本代号
    UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    if [ -z "$UBUNTU_CODENAME" ]; then
        log_error "无法检测 Ubuntu 版本代号"
        exit 1
    fi
    log_info "检测到 Ubuntu 版本代号: $UBUNTU_CODENAME"
    
    # 使用新的 sources 格式（官方推荐）
    if ! sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: $DOCKER_REPO_URI
Suites: $UBUNTU_CODENAME
Components: stable
Signed-By: $DOCKER_KEYRING_PATH
EOF
    then
        log_error "添加 Docker 仓库失败"
        exit 1
    fi
    log_success "Docker 仓库添加成功"
    
    # 更新软件包列表
    log_info "更新软件包列表..."
    if ! sudo apt-get update; then
        log_error "更新软件包列表失败"
        exit 1
    fi
    
    # 步骤 2: 安装 Docker 软件包
    # 参考: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
    log_info "步骤 2: 安装 Docker 软件包..."
    if ! sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        log_error "安装 Docker Engine 失败"
        exit 1
    fi
    log_success "Docker Engine 安装成功"
    
    # 检查 Docker 服务状态（安装后会自动启动）
    log_info "检查 Docker 服务状态..."
    if systemctl is-active --quiet docker; then
        log_success "Docker 服务正在运行"
    else
        log_warn "Docker 服务未运行，尝试启动..."
        if ! sudo systemctl start docker; then
            log_error "启动 Docker 服务失败"
            exit 1
        fi
        log_success "Docker 服务启动成功"
    fi
    
    # 启用 Docker 服务开机自启
    if ! sudo systemctl enable docker; then
        log_warn "设置 Docker 服务开机自启失败（非致命错误）"
    else
        log_success "Docker 服务已设置为开机自启"
    fi
fi

# 安装 Docker Compose（如果未安装）
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_info "Docker Compose 未检测到，但 Docker Compose Plugin 应该已随 Docker Engine 安装"
    log_info "验证 Docker Compose Plugin..."
    
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version 2>/dev/null)
        log_success "Docker Compose Plugin 已可用: $COMPOSE_VERSION"
    else
        log_warn "Docker Compose Plugin 不可用，尝试安装独立版本..."
        
        # 安装独立版本的 docker-compose
        DOCKER_COMPOSE_VERSION="v2.24.0"
        if [ "$REGION" = "cn" ]; then
            DOCKER_COMPOSE_URL="https://mirrors.aliyun.com/docker-compose/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)"
        else
            DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)"
        fi
        
        if ! sudo curl -L "$DOCKER_COMPOSE_URL" -o /usr/local/bin/docker-compose; then
            log_error "下载 Docker Compose 失败"
            exit 1
        fi
        
        if ! sudo chmod +x /usr/local/bin/docker-compose; then
            log_error "设置 Docker Compose 执行权限失败"
            exit 1
        fi
        
        log_success "Docker Compose 安装成功"
    fi
fi

# 配置 Docker 镜像加速（仅国内服务器）
if [ "$REGION" = "cn" ]; then
    log_info "配置 Docker 镜像加速（阿里云）..."
    
    DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
    DOCKER_DAEMON_JSON_BACKUP="${DOCKER_DAEMON_JSON}.backup"
    
    # 检查是否已配置镜像加速
    if [ -f "$DOCKER_DAEMON_JSON" ] && grep -q "registry-mirrors" "$DOCKER_DAEMON_JSON" 2>/dev/null; then
        log_info "检测到已配置 Docker 镜像加速，跳过配置步骤"
    else
        # 备份现有配置（如果存在）
        if [ -f "$DOCKER_DAEMON_JSON" ]; then
            if [ ! -f "$DOCKER_DAEMON_JSON_BACKUP" ]; then
                log_info "备份现有 Docker 配置..."
                sudo cp "$DOCKER_DAEMON_JSON" "$DOCKER_DAEMON_JSON_BACKUP" || {
                    log_warn "备份 Docker 配置失败（非致命错误）"
                }
            fi
        fi
        
        # 创建或更新 daemon.json
        log_info "配置阿里云 Docker 镜像加速..."
        sudo mkdir -p /etc/docker
        
        # 读取现有配置（如果存在）
        if [ -f "$DOCKER_DAEMON_JSON" ]; then
            # 使用 jq 或手动合并配置（如果 jq 不可用，使用简单方法）
            if command -v jq &> /dev/null; then
                sudo jq '. + {"registry-mirrors": ["https://registry.cn-hangzhou.aliyuncs.com"]}' "$DOCKER_DAEMON_JSON" | sudo tee "${DOCKER_DAEMON_JSON}.tmp" > /dev/null
                sudo mv "${DOCKER_DAEMON_JSON}.tmp" "$DOCKER_DAEMON_JSON"
            else
                # 简单方法：直接覆盖（保留注释说明）
                sudo tee "$DOCKER_DAEMON_JSON" > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://registry.cn-hangzhou.aliyuncs.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
            fi
        else
            # 创建新配置
            sudo tee "$DOCKER_DAEMON_JSON" > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://registry.cn-hangzhou.aliyuncs.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
        fi
        
        if [ $? -eq 0 ]; then
            log_success "Docker 镜像加速配置完成"
            
            # 重启 Docker 服务以应用配置
            log_info "重启 Docker 服务以应用配置..."
            if sudo systemctl restart docker; then
                log_success "Docker 服务重启成功"
            else
                log_error "Docker 服务重启失败"
                exit 1
            fi
        else
            log_error "Docker 镜像加速配置失败"
            exit 1
        fi
    fi
else
    log_info "海外服务器，跳过 Docker 镜像加速配置"
fi

# 验证安装
log_info "验证 Docker 安装..."
if docker --version &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    log_success "Docker 安装成功: $DOCKER_VERSION"
else
    log_error "Docker 验证失败"
    exit 1
fi

if docker compose version &> /dev/null || docker-compose --version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null)
    log_success "Docker Compose 可用: $COMPOSE_VERSION"
else
    log_error "Docker Compose 验证失败"
    exit 1
fi

# 创建跨容器网络 localnet（幂等性检查）
log_info "检查 Docker 网络 'localnet'..."
if docker network inspect localnet &> /dev/null; then
    log_info "Docker 网络 'localnet' 已存在，跳过创建"
else
    log_info "创建 Docker 网络 'localnet'..."
    if docker network create localnet; then
        log_success "Docker 网络 'localnet' 创建成功"
    else
        log_error "创建 Docker 网络 'localnet' 失败"
        exit 1
    fi
fi

# 提示用户将当前用户添加到 docker 组（可选）
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" != "root" ] && ! groups "$CURRENT_USER" | grep -q "\bdocker\b"; then
    log_info "提示: 要将用户 '$CURRENT_USER' 添加到 docker 组以无需 sudo 运行 Docker，请执行:"
    log_info "  sudo usermod -aG docker $CURRENT_USER"
    log_info "  然后重新登录或执行: newgrp docker"
fi

log_success "Docker 安装初始化完成！"
