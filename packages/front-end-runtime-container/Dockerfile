FROM node:12.22.12-slim

LABEL author=aiden_fe@outlook.com

RUN apt update \
    && apt install nginx -y \
    && npm config set registry https://registry.npmmirror.com/ \
    && yarn config set registry https://registry.npmmirror.com/ \
    && nginx -v \
    && node -v \
    && npm -v \
    && yarn -v

EXPOSE 443
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
