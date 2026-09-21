ARG IMG_TAG=latest

FROM golang:1.23.4-alpine AS builder
WORKDIR /src
ENV PACKAGES="curl build-base git bash file linux-headers"
RUN apk add --no-cache $PACKAGES

# https://github.com/CosmWasm/wasmvm/releases
ARG WASMVM_VERSION=v2.2.4
ADD https://github.com/CosmWasm/wasmvm/releases/download/${WASMVM_VERSION}/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.x86_64.a
RUN sha256sum /lib/libwasmvm_muslc.x86_64.a | grep 70c989684d2b48ca17bbd55bb694bbb136d75c393c067ef3bdbca31d2b23b578
RUN cp /lib/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.a

COPY go.mod go.sum* ./
RUN go mod download

COPY . .
RUN LEDGER_ENABLED=false LINK_STATICALLY=true BUILD_TAGS=muslc make build
RUN echo "Ensuring binary is statically linked ..." \
    && file /src/build/firmachaind | grep "statically linked"

FROM alpine:$IMG_TAG
RUN apk add --no-cache ca-certificates curl jq
RUN addgroup -g 10001 nonroot
RUN adduser -D nonroot -u 10001 -G nonroot
COPY --from=builder /src/build/firmachaind /usr/local/bin/
EXPOSE 26656 26657 1317 9090
USER 10001:10001

ENTRYPOINT ["firmachaind"]
CMD ["start"]