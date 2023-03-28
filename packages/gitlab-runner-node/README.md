# gitlab-runner-node
> gitlab runner前端运行环境

## 构建镜像

构建
`docker build . --tag [name:tag]`

或指定node版本(不支持alpine版):

`docker build . --tag [name:tag] --build-arg NODE_VERSION=18.15.0-slim`

## 注册 gitlab runner

`docker run -it [name:tag] /bin/bash` 运行并进入容器

`gitlab-runner register` 根据[Gitlab runner文档](https://docs.gitlab.com/runner/register/index.html#docker)写入信息
