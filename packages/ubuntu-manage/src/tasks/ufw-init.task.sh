#!/bin/bash

# UFW 防火墙安装初始化脚本

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 引入通用参数解析函数库
source "${SCRIPT_DIR}/../utils/parse-args.sh" "$@"

# 引入日志工具
source "${SCRIPT_DIR}/../utils/logger.sh"

# 检查 UFW 是否已安装（幂等性检查）
if command -v ufw &> /dev/null; then
    UFW_VERSION=$(ufw --version 2>/dev/null | head -n1)
    log_info "检测到 UFW 已安装: $UFW_VERSION"
else
    log_info "开始安装 UFW..."
    
    # 更新软件包列表
    log_info "更新软件包列表..."
    if ! sudo apt-get update; then
        log_error "更新软件包列表失败"
        exit 1
    fi
    
    # 安装 UFW
    log_info "安装 UFW 防火墙..."
    if ! sudo apt-get install -y ufw; then
        log_error "安装 UFW 失败"
        exit 1
    fi
    log_success "UFW 安装成功"
fi

# 检查 UFW 状态
log_info "检查 UFW 当前状态..."
UFW_STATUS=$(sudo ufw status 2>/dev/null | head -n1)

# 如果 UFW 已启用，检查是否已配置所需端口
if echo "$UFW_STATUS" | grep -q "Status: active"; then
    log_info "UFW 已启用，检查端口配置..."
    
    # 检查是否已配置所需端口, 这里不检查 22 端口是因为使用 ufw 后用户有可能改变 ssh 登录端口
    PORTS_CONFIGURED=true
    for port in 80 443; do
        if ! sudo ufw status | grep -q "${port}/tcp.*ALLOW"; then
            PORTS_CONFIGURED=false
            break
        fi
    done
    
    if [ "$PORTS_CONFIGURED" = "true" ]; then
        log_success "UFW 已启用且所需端口已配置，跳过配置步骤"
        log_info "当前 UFW 规则:"
        sudo ufw status numbered | grep -E "(22|80|443)" || true
        exit 0
    else
        log_warn "UFW 已启用但端口配置不完整，将重新配置..."
    fi
fi

# 重置 UFW 规则（如果已启用，需要先禁用才能重置）
if echo "$UFW_STATUS" | grep -q "Status: active"; then
    log_info "禁用 UFW 以重置规则..."
    if ! sudo ufw --force disable; then
        log_error "禁用 UFW 失败"
        exit 1
    fi
fi

# 重置 UFW 规则到默认状态
log_info "重置 UFW 规则..."
if ! sudo ufw --force reset; then
    log_error "重置 UFW 规则失败"
    exit 1
fi
log_success "UFW 规则已重置"

# 设置默认策略
log_info "设置 UFW 默认策略..."
# 默认拒绝所有入站连接
if ! sudo ufw default deny incoming; then
    log_error "设置默认入站策略失败"
    exit 1
fi
# 默认允许所有出站连接
if ! sudo ufw default allow outgoing; then
    log_error "设置默认出站策略失败"
    exit 1
fi
log_success "默认策略设置完成（拒绝入站，允许出站）"

# 开放必要的端口
log_info "配置允许的端口..."

# 开放 SSH 端口（22）- 必须开放，否则可能无法远程连接
log_info "开放 SSH 端口 (22)..."
if ! sudo ufw allow 22/tcp comment 'SSH'; then
    log_error "开放 SSH 端口失败"
    exit 1
fi
log_success "SSH 端口 (22) 已开放"

# 开放 HTTP 端口（80）
log_info "开放 HTTP 端口 (80)..."
if ! sudo ufw allow 80/tcp comment 'HTTP'; then
    log_error "开放 HTTP 端口失败"
    exit 1
fi
log_success "HTTP 端口 (80) 已开放"

# 开放 HTTPS 端口（443）
log_info "开放 HTTPS 端口 (443)..."
if ! sudo ufw allow 443/tcp comment 'HTTPS'; then
    log_error "开放 HTTPS 端口失败"
    exit 1
fi
log_success "HTTPS 端口 (443) 已开放"

# 启用 UFW
log_info "启用 UFW 防火墙..."
if ! sudo ufw --force enable; then
    log_error "启用 UFW 失败"
    exit 1
fi
log_success "UFW 防火墙已启用"

# 验证配置
log_info "验证 UFW 配置..."
if sudo ufw status | grep -q "Status: active"; then
    log_success "UFW 防火墙已成功启用"
    
    # 显示当前规则
    log_info "当前 UFW 规则:"
    sudo ufw status numbered | head -n20
    
    # 验证所需端口是否已开放
    log_info "验证端口配置..."
    ALL_PORTS_OPEN=true
    for port in 22 80 443; do
        if sudo ufw status | grep -q "${port}/tcp.*ALLOW"; then
            log_success "端口 $port (TCP) 已开放"
        else
            log_error "端口 $port (TCP) 未正确配置"
            ALL_PORTS_OPEN=false
        fi
    done
    
    if [ "$ALL_PORTS_OPEN" = "true" ]; then
        log_success "所有必需端口已正确配置"
    else
        log_error "端口配置验证失败"
        exit 1
    fi
else
    log_error "UFW 启用验证失败"
    exit 1
fi

# 显示最终状态
log_info "UFW 防火墙配置摘要:"
echo ""
echo "  默认策略:"
echo "    - 入站: 拒绝所有"
echo "    - 出站: 允许所有"
echo ""
echo "  已开放的端口:"
echo "    - 22/tcp  (SSH)"
echo "    - 80/tcp  (HTTP)"
echo "    - 443/tcp (HTTPS)"
echo ""

log_success "UFW 防火墙安装初始化完成！"
log_warn "提示: 如需开放其他端口，请使用命令: sudo ufw allow <端口>/tcp"
echo ""
log_info "常用 UFW 命令参考:"
echo ""
echo "  # 查看防火墙状态"
echo "    sudo ufw status                    # 查看简要状态"
echo "    sudo ufw status numbered           # 查看带编号的规则列表"
echo "    sudo ufw status verbose            # 查看详细状态"
echo ""
echo "  # 端口管理"
echo "    sudo ufw allow <端口>/tcp          # 开放 TCP 端口"
echo "    sudo ufw allow <端口>/udp          # 开放 UDP 端口"
echo "    sudo ufw allow <端口>              # 开放 TCP/UDP 端口"
echo "    sudo ufw deny <端口>/tcp           # 拒绝 TCP 端口"
echo "    sudo ufw delete allow <端口>/tcp   # 删除允许规则"
echo ""
echo "  # 服务管理"
echo "    sudo ufw allow ssh                 # 允许 SSH 服务"
echo "    sudo ufw allow http                # 允许 HTTP 服务"
echo "    sudo ufw allow https               # 允许 HTTPS 服务"
echo ""
echo "  # IP 地址管理"
echo "    sudo ufw allow from <IP地址>       # 允许来自特定 IP 的所有连接"
echo "    sudo ufw allow from <IP地址> to any port <端口>  # 允许特定 IP 访问特定端口"
echo "    sudo ufw deny from <IP地址>        # 拒绝来自特定 IP 的连接"
echo ""
echo "  # 规则管理"
echo "    sudo ufw delete <规则编号>         # 根据编号删除规则"
echo "    sudo ufw delete allow <端口>/tcp   # 删除匹配的规则"
echo "    sudo ufw reset                     # 重置所有规则（需谨慎）"
echo ""
echo "  # 启用/禁用"
echo "    sudo ufw enable                    # 启用防火墙"
echo "    sudo ufw disable                   # 禁用防火墙"
echo "    sudo ufw reload                    # 重新加载规则"
echo ""
echo "  # 日志管理"
echo "    sudo ufw logging on                # 启用日志"
echo "    sudo ufw logging off               # 禁用日志"
echo "    sudo ufw logging low|medium|high   # 设置日志级别"
echo "    sudo tail -f /var/log/ufw.log      # 查看实时日志"
echo ""
