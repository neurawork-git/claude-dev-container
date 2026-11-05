FROM alpine:3.21
WORKDIR /app
ENV APP_VERSION=1.0
RUN apk add --no-cache busybox-extras
COPY app.sh .
EXPOSE 8080
USER nobody
CMD ["sh", "/app/app.sh"]
