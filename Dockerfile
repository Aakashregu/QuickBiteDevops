FROM nginx:stable-alpine

COPY frontend/default.conf /etc/nginx/conf.d/default.conf
COPY frontend/index.html /usr/share/nginx/html/index.html

EXPOSE 80
