# ubuntu-manage
> Ubuntu 服务器管理脚本
> 脚本执行应当维持幂等性,重复执行结果一致,无副作用,能跳过已完成的步骤

## 使用说明

### 在 Ubuntu 服务器上安装和执行

#### 方法一：使用安装脚本（推荐）

在 Ubuntu 服务器上执行以下命令：

```bash
# 下载并执行安装脚本
bash <(curl -fsSL https://compass-aiden.oss-cn-shanghai.aliyuncs.com/common/scripts/ubuntu-manage/dist/install.sh)

# 或者使用 wget
bash <(wget -qO- https://compass-aiden.oss-cn-shanghai.aliyuncs.com/common/scripts/ubuntu-manage/dist/install.sh)
```

#### 方法二：手动下载和执行

```bash
# 1. 下载压缩包
curl -O https://compass-aiden.oss-cn-shanghai.aliyuncs.com/common/scripts/ubuntu-manage/dist/ubuntu-manage.tar.gz
# 或使用 wget
# wget https://compass-aiden.oss-cn-shanghai.aliyuncs.com/common/scripts/ubuntu-manage/dist/ubuntu-manage.tar.gz

# 2. 解压
tar -xzf ubuntu-manage.tar.gz

# 3. 执行初始化脚本
bash src/ubuntu-init.sh
```

#### 方法三：使用自定义 URL

```bash
# 指定自定义下载地址
bash install.sh --url https://your-domain.com/path/to/ubuntu-manage.tar.gz
```

### 安装脚本参数

```bash
bash install.sh [选项] [初始化脚本参数...]

选项:
    -h, --help              显示帮助信息
    -u, --url URL           指定下载 URL
    -d, --dir DIR           指定安装目录
    -k, --keep-temp         保留临时文件
    -r, --region REGION     指定区域 (默认: os) cn: 国内服务器 os: 海外服务器
    -w, --workspace PATH    指定工作空间路径 (默认: ~/workspace)
    --only-run TASK_NAME    仅执行指定的任务脚本（跳过其他任务）

环境变量:
    DOWNLOAD_URL            安装脚本下载地址
    TEMP_DIR                安装脚本临时目录
    INSTALL_DIR             安装目录
    KEEP_TEMP               保留临时文件 (true/false)
```

### 示例

```bash
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
```

### 系统要求

- Ubuntu 系统
- curl 或 wget（用于下载）
- tar（用于解压）
- bash（用于执行脚本）

如果缺少必要工具，可以运行：
```bash
sudo apt-get update && sudo apt-get install -y curl wget tar
```
