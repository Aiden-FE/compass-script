# server-basic-container
> Linux服务器 基础设施容器编排

* 调整 .env.example 文件为自身所需的配置,并删除.example后缀
* 如果需要mongo-express,请在docker-compose.yml及.env中释放它
* `docker compose up -d` 启动容器
* `docker compose stop` 停止容器
* `docker compose down` 移除up启动的容器

## 支持的编排容器

* MySQL
* MongoDB
* MongoExpress
* Redis
* Nginx
