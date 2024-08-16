FROM golang:alpine AS builder

RUN apk update && apk add --no-cache \
    curl \
    tar \
    xz

RUN curl -L https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz | tar -xJ && \
    mv zig-linux-x86_64-0.11.0 /usr/local/zig && \
    ln -s /usr/local/zig/zig /usr/local/bin/zig

COPY . /app
WORKDIR /app

RUN go mod init user-data
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 CC="zig cc -target x86_64-linux-musl" CXX="zig c++ -target x86_64-linux-musl" go build -ldflags="-w -s" -o user-data .
RUN chmod +x user-data

FROM scratch

COPY --from=builder /app/user-data /

ENV PORT=8083
ENV LOG_LEVEL=debug
ENV AUTH_URL=http://host.docker.internal:8081

EXPOSE 8083
ENTRYPOINT [ "/user-data" ]