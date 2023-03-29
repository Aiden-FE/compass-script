# node-nginx-container

> node + nginx 前端运行时容器环境

## 构建镜像

`docker build . --tag [name:tag]` 构建镜像,具体参数如下说明.

### ARG 参数

通过 --build-arg 设置

| 参数名              | 默认值          | 说明            |
|------------------|--------------|---------------|
| NGINX_CONFIG_DIR | ./config     | nginx配置文件路径   |
| NODE_VERSION     | 18.15.0-slim | 不支持指定为alpine版 |
