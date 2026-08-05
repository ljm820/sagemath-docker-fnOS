SHELL := /bin/bash
.PHONY: help build build-debian12 build-fedora36 build-alpine up down restart logs test test-debian12 test-fedora36 test-alpine test-sci security-scan push clean

help:
	@echo "可用目标:"
	@echo "  build            构建全部镜像 (debian12/fedora36/alpine)"
	@echo "  build-debian12   构建 Debian 12 版本"
	@echo "  build-fedora36   构建 Fedora 36 版本"
	@echo "  build-alpine     构建 Alpine 实验版本"
	@echo "  up               启动默认 (debian12) 容器"
	@echo "  down             停止并删除所有容器"
	@echo "  restart          重启所有容器"
	@echo "  logs             查看 debian12 容器日志"
	@echo "  test             运行全部镜像冒烟测试"
	@echo "  test-sci         运行 v2.0 科学环境测试 (XRD/EDS/XAS)"
	@echo "  security-scan    运行 NVIDIA SkillSpector 安全扫描"
	@echo "  push             推送镜像到仓库 (先 docker login)"
	@echo "  clean            停止容器并清理本地构建缓存"

build:
	./scripts/build.sh all

build-debian12:
	./scripts/build.sh debian12

build-fedora36:
	./scripts/build.sh fedora36

build-alpine:
	./scripts/build.sh alpine

up:
	docker compose up -d debian12

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker logs -f sagemath-debian12

test:
	./scripts/test.sh all

test-debian12:
	./scripts/test.sh debian12

test-fedora36:
	./scripts/test.sh fedora36

test-alpine:
	./scripts/test.sh alpine

test-sci:
	./scripts/test-sci.sh

security-scan:
	./scripts/security-scan.sh

push:
	./scripts/push-images.sh

clean:
	docker compose down
	docker builder prune -f
