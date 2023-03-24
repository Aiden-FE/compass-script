# Compass script

> 脚本仓库

## script

### Dockerfile

#### 前端node运行时容器


```shell
# build front end runtime container
docker build -t docker378928518/fe-static:1.0.0-slim packages/front-end-runtime-container/
```

#### Linux基础服务器 容器编排

* 进入 packages/server-basic-container
* 调整 .env.example 文件为自身所需的配置,并删除.example后缀
* 启动容器

```shell
docker compose up # 可添加-d后台执行
```
