# server-basic-container
> Linux服务器 基础设施容器编排

* 调整 .env.example 文件为自身所需的配置,并删除.example后缀
* `docker compose up -d` 启动容器
* `docker compose stop` 停止容器
* `docker compose down` 移除up启动的容器

## 支持的编排容器
> 根据实际需要注释掉docker-compose.yml文件内需要的容器

* MySQL 关系型数据库
* MongoDB 非关系型数据库
* Redis 缓存
* Nginx 网关
* postgres 非关系型数据库
* MinIO 对象存储
* adminer 数据库管理界面,连接时的host地址可以填写 compose别名,类似: mysql:3306, postgres:5432等
