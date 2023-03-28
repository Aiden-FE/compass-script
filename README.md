# Compass script

> 脚本仓库

## script

### Dockerfile

#### Gitlab runner 前端node环境
> gitlab runner前端运行环境

[使用文档](./packages/gitlab-runner-node/README.md)

#### 前端node运行时容器

```shell
# build front end runtime container
docker build -t docker378928518/fe-static:1.0.0-slim packages/front-end-runtime-container/
```

#### Linux基础服务器 容器编排

> 一键启动nginx,mysql,redis,mongoDB. 如果你需要mongo-express,请在docker-compose.yml及.env中释放它

* 进入 packages/server-basic-container
* 调整 .env.example 文件为自身所需的配置,并删除.example后缀
* 启动容器

```shell
docker compose up # 可添加-d后台执行
```
