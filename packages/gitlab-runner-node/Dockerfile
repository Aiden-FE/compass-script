ARG NODE_VERSION=18.15.0-slim

FROM node:${NODE_VERSION}

LABEL author=aiden_fe@outlook.com

RUN apt update \
    apt install gitlab-runner \
    node -v \
    gitlab-runner -v
