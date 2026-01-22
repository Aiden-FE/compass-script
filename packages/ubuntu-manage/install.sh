#!/bin/bash

# Ubuntu 服务器安装脚本
# 用于从远程服务器下载并执行 ubuntu-manage 初始化脚本

set -e

# 配置
DOWNLOAD_URL="${DOWNLOAD_URL:-https://compass-aiden.oss-cn-shanghai.aliyuncs.com/common/scripts/ubuntu-manage/dist/ubuntu-manage.tar.gz}"
TEMP_DIR="${TEMP_DIR:-/tmp/ubuntu-manage-install}"
ARCHIVE_NAME="ubuntu-manage.tar.gz"
INSTALL_DIR="${INSTALL_DIR:-${TEMP_DIR}/src}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的命令
check_requirements() {
    log_info "检查系统要求..."
    
    local missing_tools=()
    
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing_tools+=("curl 或 wget")
    fi
    
    if ! command -v tar &> /dev/null; then
        missing_tools+=("tar")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要的工具: ${missing_tools[*]}"
        log_info "请先安装: sudo apt-get update && sudo apt-get install -y curl wget tar"
        exit 1
    fi
    
    log_info "系统要求检查通过"
}

# 下载压缩包
download_archive() {
    log_info "开始下载压缩包..."
    log_info "下载地址: ${DOWNLOAD_URL}"
    
    mkdir -p "${TEMP_DIR}"
    local archive_path="${TEMP_DIR}/${ARCHIVE_NAME}"
    
    # 优先使用 curl，如果没有则使用 wget
    if command -v curl &> /dev/null; then
        if curl -fSL --progress-bar -o "${archive_path}" "${DOWNLOAD_URL}"; then
            log_info "下载成功: ${archive_path}"
        else
            log_error "下载失败，请检查网络连接和 URL"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if wget --progress=bar:force -O "${archive_path}" "${DOWNLOAD_URL}"; then
            log_info "下载成功: ${archive_path}"
        else
            log_error "下载失败，请检查网络连接和 URL"
            exit 1
        fi
    else
        log_error "未找到 curl 或 wget"
        exit 1
    fi
}

# 解压压缩包
extract_archive() {
    log_info "解压压缩包..."
    local archive_path="${TEMP_DIR}/${ARCHIVE_NAME}"
    
    if [ ! -f "${archive_path}" ]; then
        log_error "压缩包不存在: ${archive_path}"
        exit 1
    fi
    
    # 解压到临时目录
    tar -xzf "${archive_path}" -C "${TEMP_DIR}"
    
    if [ $? -eq 0 ]; then
        log_info "解压成功"
    else
        log_error "解压失败"
        exit 1
    fi
    
    # 检查解压后的目录结构
    if [ ! -f "${INSTALL_DIR}/ubuntu-init.sh" ]; then
        log_error "解压后的文件结构不正确，未找到 ubuntu-init.sh"
        exit 1
    fi
    
    log_info "文件结构验证通过"
}

# 执行初始化脚本
run_init_script() {
    log_info "开始执行初始化脚本..."
    
    if [ ! -f "${INSTALL_DIR}/ubuntu-init.sh" ]; then
        log_error "初始化脚本不存在: ${INSTALL_DIR}/ubuntu-init.sh"
        exit 1
    fi
    
    # 添加执行权限
    chmod +x "${INSTALL_DIR}/ubuntu-init.sh"
    chmod +x "${INSTALL_DIR}/tasks/"*.sh 2>/dev/null || true
    chmod +x "${INSTALL_DIR}/utils/"*.sh 2>/dev/null || true
    
    # 执行初始化脚本，传递所有参数
    log_info "执行: ${INSTALL_DIR}/ubuntu-init.sh $@"
    bash "${INSTALL_DIR}/ubuntu-init.sh" "$@"
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log_info "初始化脚本执行成功"
    else
        log_error "初始化脚本执行失败，退出码: ${exit_code}"
        exit $exit_code
    fi
}

# 清理临时文件
cleanup() {
    if [ "${KEEP_TEMP}" != "true" ]; then
        log_info "清理临时文件..."
        rm -rf "${TEMP_DIR}"
        log_info "清理完成"
    else
        log_warn "保留临时文件: ${TEMP_DIR}"
    fi
}

# 主函数
main() {
    log_info "========================================="
    log_info "Ubuntu 服务器初始化脚本安装程序"
    log_info "========================================="
    
    # 检查是否为 root 用户（某些操作可能需要）
    if [ "$EUID" -ne 0 ]; then
        log_warn "当前不是 root 用户，某些操作可能需要 sudo 权限"
    fi
    
    # 执行安装流程
    check_requirements
    download_archive
    extract_archive
    run_init_script "$@"
    
    # 询问是否清理
    if [ "${KEEP_TEMP}" != "true" ] && [ -t 0 ]; then
        echo ""
        read -p "是否清理临时文件? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            cleanup
        else
            log_warn "保留临时文件: ${TEMP_DIR}"
        fi
    else
        cleanup
    fi
    
    log_info "========================================="
    log_info "安装完成！"
    log_info "========================================="
}

# 显示帮助信息
show_help() {
    cat << EOF
Ubuntu 服务器初始化脚本安装程序

用法:
    bash install.sh [选项] [初始化脚本参数...]

选项:
    -h, --help              显示此帮助信息
    -u, --url URL           指定下载 URL (默认: ${DOWNLOAD_URL})
    -d, --dir DIR           指定安装目录 (默认: ${TEMP_DIR}/src)
    -k, --keep-temp         保留临时文件

环境变量:
    DOWNLOAD_URL            下载地址
    TEMP_DIR                临时目录
    INSTALL_DIR             安装目录
    KEEP_TEMP               保留临时文件 (true/false)

示例:
    # 使用默认配置安装
    bash install.sh

    # 指定自定义下载地址
    bash install.sh --url https://example.com/ubuntu-manage.tar.gz

    # 传递参数给初始化脚本
    bash install.sh --skip-docker

    # 保留临时文件用于调试
    KEEP_TEMP=true bash install.sh

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--url)
            DOWNLOAD_URL="$2"
            shift 2
            ;;
        -d|--dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -k|--keep-temp)
            KEEP_TEMP="true"
            shift
            ;;
        *)
            # 剩余参数传递给初始化脚本
            break
            ;;
    esac
done

# 执行主函数
main "$@"
