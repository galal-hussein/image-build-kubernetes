SEVERITIES = HIGH,CRITICAL
SHELL := /bin/bash -x

UNAME_M = $(shell uname -m)
ARCH=
ifeq ($(UNAME_M), x86_64)
	ARCH=amd64
else ifeq ($(UNAME_M), aarch64)
	ARCH=arm64
else 
	ARCH=$(UNAME_M)
endif

ORG ?= rancher
PKG ?= github.com/kubernetes/kubernetes
SRC ?= github.com/kubernetes/kubernetes
K3S_ROOT_VERSION ?= v0.13.0

BUILD_META := -build$(shell date +%Y%m%d)

ifeq ($(TAG),)
TAG := v1.29.3-rke2dev$(BUILD_META)
endif

GOLANG_VERSION := $(shell ./scripts/golang-version.sh $(TAG))

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker build \
		--pull \
		--build-arg ARCH=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG) \
		--build-arg GO_IMAGE=rancher/hardened-build-base:$(GOLANG_VERSION) \
		--build-arg K3S_ROOT_VERSION=$(K3S_ROOT_VERSION) \
		--tag $(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH) \
		.

.PHONY: all
all:
	docker build \
		--build-arg K8S_TAG=$(shell echo $(TAG) | grep -oP "^v(([0-9]+)\.([0-9]+)\.([0-9]+))") \
		--build-arg TAG=$(TAG) -t $(ORG)/hardened-kubernetes:$(shell echo $(TAG) | sed -e 's/+/-/g') .

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH) >> /dev/null

.PHONY: scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --skip-db-update --ignore-unfixed $(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH)

PHONY: log
log:
	@echo "ARCH=$(ARCH)"
	@echo "TAG=$(TAG)"
	@echo "ORG=$(ORG)"
	@echo "PKG=$(PKG)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "K3S_ROOT_VERSION=$(K3S_ROOT_VERSION)"
	@echo "UNAME_M=$(UNAME_M)"