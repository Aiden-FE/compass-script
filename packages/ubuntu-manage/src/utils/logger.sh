#!/bin/bash

# 日志打印工具库
# 用法: source logger.sh
#
# 函数说明:
#   log_info <消息>          - 打印信息级别日志
#   log_warn <消息>          - 打印警告级别日志
#   log_error <消息>         - 打印错误级别日志
#   log_debug <消息>         - 打印调试级别日志
#   log_success <消息>       - 打印成功级别日志
#
# 环境变量:
#   LOG_LEVEL                - 日志级别过滤 (DEBUG|INFO|WARN|ERROR)，默认 INFO
#   LOG_ENABLE_FILE          - 是否启用文件日志 (true|false)，默认 false
#   LOG_FILE                 - 日志文件路径（可选），如果未指定则使用默认路径
#   LOG_DIR                  - 日志文件目录（可选），默认 ~/workspace/logs/ubuntu-manage
#   LOG_COLOR                - 是否启用颜色输出 (true|false)，默认 true

# 日志级别定义（数字越大优先级越高）
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 转换为大写（兼容旧版 bash）
_to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# 获取当前日志级别（从环境变量或默认值）
_get_log_level() {
    local level="${LOG_LEVEL:-INFO}"
    level=$(_to_upper "$level")
    case "$level" in
        DEBUG) echo $LOG_LEVEL_DEBUG ;;
        INFO)  echo $LOG_LEVEL_INFO ;;
        WARN)  echo $LOG_LEVEL_WARN ;;
        ERROR) echo $LOG_LEVEL_ERROR ;;
        *)     echo $LOG_LEVEL_INFO ;;
    esac
}

# 获取日志级别对应的数字
_get_level_num() {
    case "$1" in
        DEBUG)  echo $LOG_LEVEL_DEBUG ;;
        INFO)   echo $LOG_LEVEL_INFO ;;
        WARN)   echo $LOG_LEVEL_WARN ;;
        ERROR)  echo $LOG_LEVEL_ERROR ;;
        *)      echo $LOG_LEVEL_INFO ;;
    esac
}

# 检查是否应该输出日志
_should_log() {
    local level="$1"
    local current_level=$(_get_log_level)
    local level_num=$(_get_level_num "$level")
    [ "$level_num" -ge "$current_level" ]
}

# 获取时间戳（格式: YYYY-MM-DD HH:MM:SS）
_get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 获取日期（格式: YYYY-MM-DD）
_get_date() {
    date '+%Y-%m-%d'
}

# 获取日志文件路径
_get_log_file_path() {
    local enable_file="${LOG_ENABLE_FILE:-false}"
    
    # 如果未启用文件日志，返回空
    if [ "$enable_file" != "true" ]; then
        echo ""
        return 0
    fi
    
    # 如果指定了日志文件路径，使用指定的路径（但需要按日期区分）
    if [ -n "${LOG_FILE:-}" ]; then
        local log_file="$LOG_FILE"
        local dir=$(dirname "$log_file")
        local basename=$(basename "$log_file")
        local ext=""
        local name_without_ext="$basename"
        
        # 检查是否有扩展名
        if [[ "$basename" =~ \.(.+)$ ]]; then
            ext=".${BASH_REMATCH[1]}"
            name_without_ext="${basename%.*}"
        fi
        
        # 添加日期到文件名
        local date_str=$(_get_date)
        echo "${dir}/${name_without_ext}-${date_str}${ext}"
        return 0
    fi
    
    # 使用默认路径
    local log_dir="${LOG_DIR:-~/workspace/logs/ubuntu-manage}"
    local script_name="script"
    
    # 尝试获取调用脚本的名称
    if [ -n "${BASH_SOURCE[1]:-}" ]; then
        script_name=$(basename "${BASH_SOURCE[1]}" .sh)
    fi
    
    local date_str=$(_get_date)
    echo "${log_dir}/${script_name}-${date_str}.log"
}

# 获取颜色代码
_get_color() {
    local level="$1"
    local use_color="${LOG_COLOR:-true}"
    
    if [ "$use_color" != "true" ]; then
        echo ""
        return
    fi
    
    case "$level" in
        DEBUG)  echo "\033[0;36m" ;;  # 青色
        INFO)   echo "\033[0;32m" ;;  # 绿色
        WARN)   echo "\033[0;33m" ;;  # 黄色
        ERROR)  echo "\033[0;31m" ;;  # 红色
        SUCCESS) echo "\033[0;92m" ;; # 亮绿色
        *)      echo "\033[0m" ;;     # 默认
    esac
}

# 重置颜色
_reset_color() {
    local use_color="${LOG_COLOR:-true}"
    [ "$use_color" = "true" ] && echo "\033[0m" || echo ""
}

# 格式化日志级别（固定宽度）
_format_level() {
    local level="$1"
    printf "%-7s" "[$level]"
}

# 核心日志打印函数
_log() {
    local level="$1"
    shift
    local message="$@"
    
    # 检查是否应该输出
    if ! _should_log "$level"; then
        return 0
    fi
    
    local timestamp=$(_get_timestamp)
    local color=$(_get_color "$level")
    local reset=$(_reset_color)
    local level_str=$(_format_level "$level")
    
    # 格式化日志消息
    local log_message="${color}${timestamp} ${level_str} ${message}${reset}"
    
    # 输出到控制台
    echo -e "$log_message"
    
    # 如果启用了文件日志，同时写入文件（不带颜色）
    local log_file_path=$(_get_log_file_path)
    if [ -n "$log_file_path" ]; then
        local file_message="${timestamp} ${level_str} ${message}"
        # 确保日志目录存在
        local log_dir=$(dirname "$log_file_path")
        if [ ! -d "$log_dir" ]; then
            mkdir -p "$log_dir" 2>/dev/null || {
                # 如果无法创建目录，输出警告但不中断
                echo "警告: 无法创建日志目录 $log_dir" >&2
                return 0
            }
        fi
        echo "$file_message" >> "$log_file_path" 2>/dev/null || {
            # 如果无法写入文件，输出警告但不中断
            echo "警告: 无法写入日志文件 $log_file_path" >&2
        }
    fi
}

# 公共日志函数
log_debug() {
    _log "DEBUG" "$@"
}

log_info() {
    _log "INFO" "$@"
}

log_warn() {
    _log "WARN" "$@"
}

log_error() {
    _log "ERROR" "$@"
}

log_success() {
    _log "SUCCESS" "$@"
}

# 示例用法（如果直接运行此脚本）
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "日志工具测试:"
    echo ""
    
    log_debug "这是一条调试信息"
    log_info "这是一条普通信息"
    log_warn "这是一条警告信息"
    log_error "这是一条错误信息"
    log_success "这是一条成功信息"
    
    echo ""
    echo "设置 LOG_LEVEL=WARN 后:"
    export LOG_LEVEL=WARN
    log_debug "这条调试信息不会显示"
    log_info "这条普通信息不会显示"
    log_warn "这条警告信息会显示"
    log_error "这条错误信息会显示"
    
    echo ""
    echo "启用文件日志测试:"
    export LOG_ENABLE_FILE=true
    export LOG_DIR="/tmp"
    log_info "这条信息会同时写入文件"
    log_warn "日志文件路径: $(_get_log_file_path)"
fi
