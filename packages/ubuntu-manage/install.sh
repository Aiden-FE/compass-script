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

# 检查操作系统是否为 Ubuntu
check_os() {
    log_info "检查操作系统环境..."
    
    if [ ! -f /etc/os-release ]; then
        log_error "无法检测操作系统类型，/etc/os-release 文件不存在"
        exit 1
    fi
    
    # 读取操作系统信息
    . /etc/os-release
    
    # 检查是否为 Ubuntu 或基于 Ubuntu 的系统
    if [ "$ID" != "ubuntu" ] && [ "$ID_LIKE" != "ubuntu" ] && [[ ! "$ID_LIKE" =~ "ubuntu" ]]; then
        log_error "此脚本仅支持 Ubuntu 系统"
        log_error "检测到的操作系统: $ID ($PRETTY_NAME)"
        log_error "请确保在 Ubuntu 系统上运行此脚本"
        exit 1
    fi
    
    log_info "操作系统检查通过: $PRETTY_NAME"
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

# 执行单个任务脚本
run_single_task() {
    local task_name="$1"
    shift  # 移除 task_name，剩余参数传递给任务脚本
    
    log_info "开始执行任务: ${task_name}"
    
    local task_script="${INSTALL_DIR}/tasks/${task_name}.task.sh"
    
    # 检查任务脚本是否存在
    if [ ! -f "${task_script}" ]; then
        log_error "任务脚本不存在: ${task_script}"
        log_info "可用的任务列表:"
        if [ -d "${INSTALL_DIR}/tasks" ]; then
            for task_file in "${INSTALL_DIR}/tasks/"*.task.sh; do
                if [ -f "${task_file}" ]; then
                    local name=$(basename "${task_file}" .task.sh)
                    log_info "  - ${name}"
                fi
            done
        fi
        exit 1
    fi
    
    # 添加执行权限
    chmod +x "${task_script}"
    chmod +x "${INSTALL_DIR}/utils/"*.sh 2>/dev/null || true
    
    # 执行任务脚本，传递剩余参数
    log_info "执行: ${task_script} $@"
    bash "${task_script}" "$@"
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log_info "任务执行成功: ${task_name}"
    else
        log_error "任务执行失败: ${task_name}，退出码: ${exit_code}"
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
    
    # 首先检查操作系统环境
    check_os
    
    # 检查是否为 root 用户（某些操作可能需要）
    if [ "$EUID" -ne 0 ]; then
        log_warn "当前不是 root 用户，某些操作可能需要 sudo 权限"
    fi
    
    # 如果指定了 --only-run，只执行单个任务
    if [ -n "${ONLY_RUN_TASK}" ]; then
        # 检查任务脚本是否存在，如果不存在则先下载解压
        local task_script="${INSTALL_DIR}/tasks/${ONLY_RUN_TASK}.task.sh"
        if [ ! -f "${task_script}" ]; then
            log_info "任务脚本不存在，开始下载和解压..."
            check_requirements
            download_archive
            extract_archive
        else
            log_info "使用已存在的任务脚本: ${task_script}"
        fi
        
        # 执行单个任务
        run_single_task "${ONLY_RUN_TASK}" "$@"
    else
        # 执行完整的安装流程
        check_requirements
        download_archive
        extract_archive
        run_init_script "$@"
    fi

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
    -r, --region REGION     指定区域 (默认: os) cn: 国内服务器 os: 海外服务器
    -w, --workspace PATH    指定工作空间路径 (默认: ~/workspace)
    --only-run TASK_NAME    仅执行指定的任务脚本（跳过其他任务）

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
    bash install.sh --region cn --workspace /root/workspace

    # 仅执行 docker 初始化任务
    bash install.sh --only-run docker-init

    # 仅执行 ufw 初始化任务，并传递参数
    bash install.sh --only-run ufw-init --region cn

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
        --only-run)
            if [ -z "$2" ]; then
                log_error "--only-run 需要指定任务名称"
                show_help
                exit 1
            fi
            ONLY_RUN_TASK="$2"
            shift 2
            ;;
        *)
            # 剩余参数传递给初始化脚本或任务脚本
            break
            ;;
    esac
done

# 执行主函数
main "$@"
