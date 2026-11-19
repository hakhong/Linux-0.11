#!/bin/bash
# 1. First time only: build the Docker image (Ubuntu 14.04, gcc 4.8, bin86)
#    and start the build container "linux-0.11". Takes 15+ minutes.
#    처음 한 번: 빌드용 Docker 이미지를 만들고 컨테이너 linux-0.11 을 띄운다 (15분 이상).
cd "$(dirname "$0")" || exit 1
docker compose build --no-cache && docker compose up -d && docker compose ps
