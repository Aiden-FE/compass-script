#!/bin/bash

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"
DIST_DIR="${SCRIPT_DIR}/dist"
ARCHIVE_NAME="ubuntu-manage.tar.gz"

# 检查 src 目录是否存在
if [ ! -d "$SRC_DIR" ]; then
    echo "错误: src 目录不存在: $SRC_DIR"
    exit 1
fi

# 清除 dist 目录（如果存在）
if [ -d "$DIST_DIR" ]; then
    echo "正在清除 dist 目录..."
    rm -rf "$DIST_DIR"
fi

# 创建 dist 目录
mkdir -p "$DIST_DIR"

# 进入 src 的父目录，以便打包时保持目录结构
cd "$SCRIPT_DIR"

# 打包 src 目录到 dist 目录
echo "正在打包 src 目录..."
tar -czf "${DIST_DIR}/${ARCHIVE_NAME}" -C "$SCRIPT_DIR" src/

if [ $? -eq 0 ]; then
    echo "打包成功: ${DIST_DIR}/${ARCHIVE_NAME}"
    # 显示压缩包信息
    ls -lh "${DIST_DIR}/${ARCHIVE_NAME}"
else
    echo "打包失败"
    exit 1
fi

# 复制 install.sh 到 dist 目录
if [ -f "${SCRIPT_DIR}/install.sh" ]; then
    echo "正在复制 install.sh 到 dist 目录..."
    cp "${SCRIPT_DIR}/install.sh" "${DIST_DIR}/install.sh"
    chmod +x "${DIST_DIR}/install.sh"
    echo "复制成功: ${DIST_DIR}/install.sh"
else
    echo "警告: install.sh 文件不存在，跳过复制"
fi
