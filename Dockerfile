FROM alpine:3.8

WORKDIR /app

RUN wget -q https://aliyuncli.alicdn.com/aliyun-cli-linux-3.0.6-amd64.tgz -O - \
    | tar zx -C /usr/local/bin 
RUN apk add curl && apk add jq

COPY . /app

ENTRYPOINT ["/app/px-disk.sh"]