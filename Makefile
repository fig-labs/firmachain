PACKAGES=$(shell go list ./... | grep -v '/simulation')
VERSION := $(shell echo $(shell git describe --tags --always) | sed 's/^v//')
COMMIT := $(shell git log -1 --format='%H')
BRANCH := $(shell git branch --show-current)

include Makefile.ledger

build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
whitespace += $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=FirmaChain \
	-X github.com/cosmos/cosmos-sdk/version.AppName=firmachaind \
	-X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
	-X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
	-X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)"

ifeq ($(LINK_STATICALLY),true)
	ldflags += -linkmode=external -extldflags "-Wl,-z,muldefs -static"
endif

BUILD_FLAGS := -ldflags '$(ldflags)' -tags "$(build_tags)"

DOCKER := $(shell which docker)

all: install

build:
	mkdir -p build
	go build -mod=readonly $(BUILD_FLAGS) -o build/firmachaind ./cmd/firmachaind

install: go.sum
	go install -mod=readonly $(BUILD_FLAGS) ./cmd/firmachaind

docker-img-from-current-branch:
	docker build -t firmachain .

go.sum: go.mod
		@echo "--> Ensure dependencies have not been modified"
		GO111MODULE=on go mod verify

test:
	@go test -mod=readonly $(PACKAGES)

###############################################################################
###                                  Proto                                  ###
###############################################################################

# Variables for the image and version
protoVer=0.15.3
protoImageName=ghcr.io/cosmos/proto-builder:$(protoVer)
protoImage=$(DOCKER) run --rm -v $(CURDIR):/workspace --workdir /workspace $(protoImageName)

proto-gen:
	@echo "Generating Protobuf files"
	@$(protoImage) sh ./scripts/protocgen.sh

###############################################################################
###                                  Docs                                   ###
###############################################################################

SWAGGER_DIR=./swagger-proto

swagger:
	@echo "Downloading go modules..."
	@go mod tidy
	@echo
	@echo "Generating Swagger..."
	@echo
	@./scripts/generate-swagger.sh