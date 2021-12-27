FROM alpine:3.15

RUN apk --no-cache add socat=1.7.4.2-r0
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
