FROM golang:alpine AS builder
COPY . /app
WORKDIR /app

RUN go mod init webapp
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o webapp . 
RUN chmod +x webapp

FROM scratch
COPY --from=builder /app/webapp /
COPY --from=builder /app/index.html /

ENV PORT=8080
ENV AUTH_URL=http://host.docker.internal:8081
ENV RECOMMEND_URL=http://host.docker.internal:8082
ENV SUBMIT_URL=http://host.docker.internal:8083

EXPOSE 8080
ENTRYPOINT [ "/webapp" ]