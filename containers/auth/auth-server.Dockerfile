FROM golang:alpine AS builder
COPY . /app
WORKDIR /app

RUN go mod init auth-server
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o auth-server . 
RUN chmod +x auth-server

FROM scratch
COPY --from=builder /app/auth-server /

ENV PORT=8081

EXPOSE 8081
ENTRYPOINT [ "/auth-server" ]