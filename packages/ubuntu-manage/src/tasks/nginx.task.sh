#!/bin/bash

# nginx 容器初始化脚本
## 在 工作区/deploys/nginx 目录下创建 nginx 容器基础目录
## 在 nginx 容器基础目录下创建 nginx/conf 配置文件目录
## 在 nginx 容器基础目录下创建 nginx/logs 日志目录
## 在 nginx 容器基础目录下创建 nginx/data 数据目录
## 在 nginx 容器基础目录下创建 nginx/html 静态资源目录
## 在 nginx 容器基础目录下创建 nginx/ssl 证书目录
## 创建名为 nginx 的 docker 容器, 匹配 80 及 443 端口,并加入 localnet 网络,自动重启

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

# 定义 nginx 容器基础目录
NGINX_BASE_DIR="${WORKSPACE_PATH}/deploys/nginx"

log_info "Nginx 容器基础目录: $NGINX_BASE_DIR"

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装，请先执行 docker-init.task.sh"
    exit 1
fi

# 检查 Docker 服务是否运行
if ! systemctl is-active --quiet docker 2>/dev/null && ! docker ps &> /dev/null; then
    log_error "Docker 服务未运行，请先启动 Docker 服务"
    exit 1
fi

# 检查 localnet 网络是否存在
if ! docker network inspect localnet &> /dev/null; then
    log_error "Docker 网络 'localnet' 不存在，请先执行 docker-init.task.sh"
    exit 1
fi

# 定义需要创建的目录列表
declare -a DIRS=(
    "$NGINX_BASE_DIR"
    "$NGINX_BASE_DIR/conf"
    "$NGINX_BASE_DIR/logs"
    "$NGINX_BASE_DIR/data"
    "$NGINX_BASE_DIR/html"
    "$NGINX_BASE_DIR/ssl"
)

# 创建目录
log_info "开始创建 Nginx 容器目录结构..."
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

# 检查 nginx 容器是否已存在（幂等性检查）
log_info "检查 Nginx 容器..."
if docker ps -a --format '{{.Names}}' | grep -q "^nginx$"; then
    log_info "Nginx 容器已存在，检查配置..."
    
    # 检查容器是否在运行
    if docker ps --format '{{.Names}}' | grep -q "^nginx$"; then
        log_success "Nginx 容器正在运行"
    else
        log_warn "Nginx 容器存在但未运行，尝试启动..."
        if docker start nginx; then
            log_success "Nginx 容器启动成功"
        else
            log_error "Nginx 容器启动失败"
            exit 1
        fi
    fi
    
    # 检查容器是否在 localnet 网络中
    if docker inspect nginx --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}{{end}}' | grep -q "localnet"; then
        log_info "Nginx 容器已在 localnet 网络中"
    else
        log_warn "Nginx 容器未在 localnet 网络中，尝试连接..."
        if docker network connect localnet nginx 2>/dev/null; then
            log_success "Nginx 容器已连接到 localnet 网络"
        else
            log_warn "连接 Nginx 容器到 localnet 网络失败（可能已在其他网络中）"
        fi
    fi
    
    log_success "Nginx 容器初始化完成（容器已存在）"
    exit 0
fi

# 写入基础 web 配置文件
WEB_CONF_FILE="${NGINX_BASE_DIR}/conf/default.conf"
if [ ! -f "$WEB_CONF_FILE" ]; then
    log_info "创建基础 web 配置文件: $WEB_CONF_FILE"
    cat > "$WEB_CONF_FILE" << 'EOF'
server {
  listen       80;
  # listen       443 ssl http2; # FIXME: 启用证书后取消注释并配置 SSL
  server_name  localhost; # FIXME: 修改为实际的域名

  # 字符集设置
  charset utf-8;

  # 隐藏 nginx 版本信息（安全考虑）
  server_tokens off;

  # 安全响应头
  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-XSS-Protection "1; mode=block" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;

  # HSTS策略,要求客户端采用https访问（仅在启用SSL后使用）
  # add_header      Strict-Transport-Security "max-age=31536000;includeSubDomains;preload" always;

  # 上传文件的大小限制
  client_max_body_size 10M;

  # 启用缓冲区（用于反向代理场景）
  proxy_buffering on;

  # gzip压缩
  gzip on; # 启用gzip
  gzip_comp_level 5; # 压缩级别, 最大9
  gzip_min_length 1024; # 最小压缩1k
  gzip_buffers 16 8k; # 压缩缓冲区, 16个8k
  gzip_proxied any; # 对代理服务的响应压缩
  gzip_vary on; # 告知客户端支持压缩
  gzip_static on; # 预压缩（on: 如果预压缩文件不存在则动态压缩; always: 必须存在预压缩文件）
  gzip_disable "MSIE [1-6]\."; # 指定ie6以下不开启gzip压缩
  gzip_types text/plain text/css text/js text/xml text/javascript application/javascript application/json application/xml application/rss+xml image/svg+xml;

  # brotli压缩,需要启用SSL证书, 可以与gzip并存,优先采用brotli,不支持回退到gzip压缩
  # 注意：需要安装 nginx-module-brotli 模块
  # brotli on; # 启用brotli
  # brotli_comp_level 6; # 压缩级别 最大11
  # brotli_min_length 1k; # 大于等于1k执行压缩
  # brotli_buffers 16 8k; # 压缩缓冲区, 16个8k
  # brotli_vary on; # 告知客户端支持压缩
  # brotli_static always; # 是否允许查找已压缩好的.br文件
  # brotli_types text/plain text/css text/js text/xml text/javascript application/javascript application/json application/xml application/rss+xml image/svg+xml;

  # SSL配置（启用HTTPS时取消注释）
  # ssl_certificate /etc/nginx/ssl/xxx.pem; # 证书文件路径
  # ssl_certificate_key /etc/nginx/ssl/xxx.key; # 证书密钥文件路径
  # ssl_session_cache shared:SSL:10m; # 会话重用,提高https性能
  # ssl_session_timeout 5m; # 会话超时时间
  # ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4; # 加密套件
  # ssl_protocols TLSv1.2 TLSv1.3; # 协议版本
  # ssl_prefer_server_ciphers on; # 启用服务器端加密套件优先

  # 负载均衡配置示例（通常放在 http 块中，这里仅作说明）
  # upstream backend {
  #   # 根据ip hash分配
  #   ip_hash;
  #   # 根据响应时间分配（需要安装 nginx-upstream-fair 模块）
  #   # fair;
  #   # 根据URL hash分配（需要安装 nginx-upstream-hash 模块）
  #   # url_hash;
  #   # hash_methods crc32;
  #   # 用法server 192.168.0.1:8080 [option],option可选,down表示不参与负载/weight=1,负载权重/backup当其他机器不可用或繁忙时启用
  #   server 192.168.0.1:8080;
  # }

  # location 匹配规则说明:
  # 1. 前缀匹配 location /test {} 要求以指定符号开始, 可以命中 host/test, host/test?key=value, host/test/, host/testtest
  # 2. 精确匹配 location =/test {} 精确匹配, 命中 host/test, host/test?key=value 不会匹配 host/test/, host/testtest
  # 3. 正则匹配 location ~^/test {} 或location ~*^/test {} 正则匹配,用在uri中包含正则表达式前,例如^/test,*用来设置不区分大小写
  # 4. 精确捕获匹配 location ^~ 等同于location /test {},只是命中后会停止匹配其他模式
  # 5. location @name {}, 定义location,以便内部定向使用
  # 6. 通配匹配 location / {}
  # 优先级: 粒度越细越优先, 精确匹配 > 精确捕获匹配 > 正则匹配 > 前缀匹配 > 通配匹配

  root   /usr/share/nginx/html; # FIXME: 修改为实际的资源部署位置

  # 静态资源缓存配置（使用 location 块替代 if 判断，性能更好）
  location ~* \.(?:js|css|gif|jpg|jpeg|webp|png|bmp|swf|woff2?|eot|otf|ttf|svg|apng|ico)$ {
    expires 90d;
    add_header Cache-Control "public, immutable";
    add_header Last-Modified $date_gmt;
    access_log off; # 静态资源访问日志可关闭以提升性能
  }

  # HTML 入口文件不缓存
  location ~* \.(?:htm|html)$ {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
  }

  location / {
    index  index.html index.htm;
    try_files $uri $uri/ /index.html =404; # 路由history模式可以启用
  }

  # 设置出现对应的错误码后如何处理
  error_page   500 502 503 504  /50x.html;
  # =500的作用是将状态更改为500
  # error_page   500 502 503 504 =500 /50x.html;

  location = /50x.html {
    # root指定根路径 alias 路径别名, 例如: /usr/local/images/test.png 路径下有图片资源
    # location /images { root /usr/local; }, 此时访问路径为host/images/test.png
    # 如果使用alias: location /images { alias /usr/local; },host/images/test.png将不可访问,调整为location /images/ { alias /usr/local/images/; }
    # root的逻辑是: root路径+location路径,alias的逻辑是: 用alias路径替换location路径
    root   /usr/share/nginx/html;
    # 指定默认返回的首页,如果没指定具体资源,则多个值依次返回,找到1个返回为止
    index index.html index.htm;
  }

  # 禁止访问隐藏文件（安全考虑）
  location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
  }
}
EOF
    if [ $? -eq 0 ]; then
        log_success "基础 web 配置文件创建成功"
    else
        log_error "基础 web 配置文件创建失败"
        exit 1
    fi
else
    log_warn "基础 web 配置文件已存在: $WEB_CONF_FILE"
fi

# 创建 nginx 容器
log_info "创建 Nginx 容器..."

# 使用官方 nginx 镜像创建容器
# -d: 后台运行
# --name nginx: 容器名称
# --restart unless-stopped: 自动重启（除非手动停止）
# -p 80:80: 映射 HTTP 端口
# -p 443:443: 映射 HTTPS 端口
# --network localnet: 加入 localnet 网络
# -v: 挂载目录（配置文件、日志、数据、静态资源、SSL证书）
if docker run -d \
    --name nginx \
    --restart unless-stopped \
    -p 80:80 \
    -p 443:443 \
    --network localnet \
    -v "${NGINX_BASE_DIR}/conf:/etc/nginx/conf.d" \
    -v "${NGINX_BASE_DIR}/logs:/var/log/nginx" \
    -v "${NGINX_BASE_DIR}/data:/var/lib/nginx" \
    -v "${NGINX_BASE_DIR}/html:/usr/share/nginx/html" \
    -v "${NGINX_BASE_DIR}/ssl:/etc/nginx/ssl" \
    nginx:latest; then
    log_success "Nginx 容器创建成功"
else
    log_error "Nginx 容器创建失败"
    exit 1
fi

# 验证容器状态
log_info "验证 Nginx 容器状态..."
if docker ps --format '{{.Names}}' | grep -q "^nginx$"; then
    log_success "Nginx 容器正在运行"
    
    # 显示容器信息
    CONTAINER_IP=$(docker inspect nginx --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)
    if [ -n "$CONTAINER_IP" ]; then
        log_info "Nginx 容器 IP 地址: $CONTAINER_IP"
    fi
    
    log_info "Nginx 容器端口映射:"
    docker port nginx 2>/dev/null | while read line; do
        log_info "  $line"
    done
else
    log_error "Nginx 容器创建后未运行"
    log_info "查看容器日志:"
    docker logs nginx 2>&1 | tail -20
    exit 1
fi

log_success "Nginx 容器初始化完成！"
log_info "Nginx 容器基础目录: $NGINX_BASE_DIR"
log_info "配置文件目录: $NGINX_BASE_DIR/conf"
log_info "日志目录: $NGINX_BASE_DIR/logs"
log_info "数据目录: $NGINX_BASE_DIR/data"
log_info "静态资源目录: $NGINX_BASE_DIR/html"
log_info "SSL 证书目录: $NGINX_BASE_DIR/ssl"
