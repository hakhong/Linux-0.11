#!/bin/bash
# 9. Remove build outputs (make clean in the container). output/ is left as it is.
#    빌드 결과를 지운다 (컨테이너 안에서 make clean).
cd "$(dirname "$0")" || exit 1
docker compose exec linux011 make clean
