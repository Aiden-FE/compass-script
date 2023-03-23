FROM node:18.15.0-alpine

LABEL author=aiden_fe@outlook.com

RUN apt update \
    && apt install nginx -y \
    && npm install -g pnpm \
    && npm config set registry https://registry.npmmirror.com/ \
    && yarn config set registry https://registry.npmmirror.com/ \
    && pnpm config set registry https://registry.npmmirror.com/ \
    && nginx -v \
    && node -v \
    && npm -v \
    && yarn -v \
    && pnpm -v

EXPOSE 443
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
