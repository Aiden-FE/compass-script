#!/bin/bash

# 通用参数解析函数库
# 用法: source parse-args.sh "$@"
#
# 函数说明:
#   get_arg <参数名> [默认值] [短参数名]
#     获取指定参数的值
#     参数名: 长参数名（如 "region" 对应 --region）
#     默认值: 如果未提供参数时的默认值（可选）
#     短参数名: 短参数名（如 "r" 对应 -r，可选）
#
#   返回值规则:
#     - 如果找到参数，返回参数的实际值（即使值为空字符串）
#     - 如果未找到参数，返回默认值（如果提供了默认值）
#     - 如果未找到参数且未提供默认值，返回空字符串
#
# 示例:
#   REGION=$(get_arg "region" "overseas" "r")
#   DEBUG=$(get_arg "debug" "false" "d")
#   # 支持以下格式:
#   # --region cn 或 -r cn        -> 返回 "cn"
#   # --region=cn 或 -r=cn        -> 返回 "cn"
#   # --region "" 或 -r ""        -> 返回 "" (空字符串)
#   # --region= 或 -r=            -> 返回 "" (空字符串)
#   # (未提供参数)                -> 返回 "overseas" (默认值)

# 保存原始参数数组
_ARGS=("$@")

# 获取参数值的函数
# 用法: get_arg <参数名> [默认值] [短参数名]
# 返回值:
#   - 如果找到参数，返回参数值（即使值为空字符串）
#   - 如果未找到参数，返回默认值（如果提供了默认值）
#   - 如果未找到参数且未提供默认值，返回空字符串
get_arg() {
    local param_name="$1"
    local default_value="${2:-}"
    local short_param="${3:-}"
    
    local long_param="--${param_name}"
    local found=false
    local value=""
    local has_value=false  # 标记是否明确提供了值（即使是空字符串）
    
    # 遍历参数数组
    for i in "${!_ARGS[@]}"; do
        local arg="${_ARGS[$i]}"
        
        # 检查长参数 (--param value 或 --param=value 或 --param=)
        if [ "$arg" = "$long_param" ]; then
            # 检查下一个参数是否存在且不是另一个参数
            if [ $((i + 1)) -lt ${#_ARGS[@]} ]; then
                local next_arg="${_ARGS[$((i + 1))]}"
                # 如果下一个参数不是以 - 开头，则它是值
                if [[ ! "$next_arg" =~ ^- ]]; then
                    value="$next_arg"
                    found=true
                    has_value=true
                    break
                fi
            fi
            # 如果 --param 后面没有值或下一个参数是另一个选项，标记为找到但值为空
            found=true
            has_value=false
            break
        elif [[ "$arg" =~ ^${long_param}=(.*)$ ]]; then
            # 处理 --param=value 或 --param= 格式
            value="${BASH_REMATCH[1]}"
            found=true
            has_value=true
            break
        fi
        
        # 检查短参数 (-s value 或 -s=value 或 -s=)
        if [ -n "$short_param" ]; then
            if [ "$arg" = "-${short_param}" ]; then
                # 检查下一个参数是否存在且不是另一个参数
                if [ $((i + 1)) -lt ${#_ARGS[@]} ]; then
                    local next_arg="${_ARGS[$((i + 1))]}"
                    # 如果下一个参数不是以 - 开头，则它是值
                    if [[ ! "$next_arg" =~ ^- ]]; then
                        value="$next_arg"
                        found=true
                        has_value=true
                        break
                    fi
                fi
                # 如果 -s 后面没有值或下一个参数是另一个选项，标记为找到但值为空
                found=true
                has_value=false
                break
            elif [[ "$arg" =~ ^-${short_param}=(.*)$ ]]; then
                # 处理 -s=value 或 -s= 格式
                value="${BASH_REMATCH[1]}"
                found=true
                has_value=true
                break
            fi
        fi
    done
    
    # 如果找到参数，返回实际值（即使为空字符串）
    if [ "$found" = true ]; then
        if [ "$has_value" = true ]; then
            echo "$value"
        else
            # 参数存在但没有提供值，返回空字符串
            echo ""
        fi
    else
        # 未找到参数，返回默认值
        echo "$default_value"
    fi
}

# 检查参数是否存在的函数
# 用法: has_arg <参数名> [短参数名]
# 返回值: 如果参数存在（无论是否有值）返回 0，否则返回 1
has_arg() {
    local param_name="$1"
    local short_param="${2:-}"
    
    local long_param="--${param_name}"
    
    for arg in "${_ARGS[@]}"; do
        # 检查长参数 (--param 或 --param=value 或 --param=)
        if [ "$arg" = "$long_param" ] || [[ "$arg" =~ ^${long_param}(=.*)?$ ]]; then
            return 0
        fi
        # 检查短参数 (-s 或 -s=value 或 -s=)
        if [ -n "$short_param" ]; then
            if [ "$arg" = "-${short_param}" ] || [[ "$arg" =~ ^-${short_param}(=.*)?$ ]]; then
                return 0
            fi
        fi
    done
    
    return 1
}
