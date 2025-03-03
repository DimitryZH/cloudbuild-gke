FROM golang:1.19.2 as builder
WORKDIR /app
RUN go mod init my-app
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /my-app

FROM gcr.io/distroless/base-debian11
WORKDIR /
COPY --from=builder /my-app /my-app
ENV PORT 8080
USER nonroot:nonroot
CMD ["/my-app"]
