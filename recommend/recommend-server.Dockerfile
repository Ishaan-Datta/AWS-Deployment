FROM golang:alpine AS builder
COPY . /app
WORKDIR /app

RUN go mod init recommend-server
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o recommend-server . 
RUN chmod +x recommend-server

FROM scratch
COPY --from=builder /app/recommend-server /

ENV PORT=8082

EXPOSE 8082
ENTRYPOINT [ "/recommend-server" ]