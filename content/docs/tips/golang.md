# Go

## Create a super minimal `FROM scratch` contianer image

Go applications can be statically compiled to run completely standalone
with no supporting Linux filesystem present whatsoever. Strip and compress
the binary and you'll have an image barely larger than busybox.

Compile your application statically and with stripped symbols. The necessary
command wil vary depending on your project's complexity. But for small projects
something like this will do:

    CGO_ENABLED=0 go build -ldflags='-s -w' -o main

Optionally compress the binary with `upx`. Check that it still runs! Sometimes
this will break binaries.

    upx main

If your application makes HTTP requests to TLS endpoints you'll want a copy
of the `SystemCertPool`. See [`root_linux.go`](https://golang.org/src/crypto/x509/root_linux.go)
for a list of files which are searched for by default on a Linux system.

    cp /etc/ssl/certs/ca-certificates.crt .

Create a simple Dockerfile to create an image "from scratch":

    FROM scratch
    COPY main /main
    COPY ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
    ENTRYPOINT ["/main"]

Build the image as usual with `podman build -t test .`. My test image clocked
in at a mere 2.87 MiB and was only 6 KiB larger than the binary and certificate
store combined.
