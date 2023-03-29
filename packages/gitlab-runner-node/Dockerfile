ARG NODE_VERSION=18.15.0-slim

FROM node:${NODE_VERSION}

LABEL author=aiden_fe@outlook.com

RUN apt update -y \
    apt install gitlab-runner -y \
    node -v \
    gitlab-runner -v
