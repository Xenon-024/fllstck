#!/usr/bin/env bash
# 酒馆 (SillyTavern) 一键部署脚本
# 用法:
#   bash deploy.sh            # 仅部署酒馆容器(访问 http://<IP>:8000)
#   bash deploy.sh --nginx    # 同时配置 nginx 反代(访问 http://<IP>)
set -euo pipefail

cd "$(dirname "$0")"

INSTALL_NGINX=false
[ "${1:-}" = "--nginx" ] && INSTALL_NGINX=true

# ---------- 0. 环境检查 ----------
if ! command -v docker >/dev/null 2>&1; then
    echo "[错误] 未安装 Docker。Ubuntu 可执行:"
    echo "  curl -fsSL https://get.docker.com | sh"
    exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
    echo "[错误] 未安装 docker compose 插件。"
    exit 1
fi

# ---------- 1. 拉取镜像(国内直连 ghcr.io 失败时自动走南京大学代理) ----------
IMAGE="ghcr.io/sillytavern/sillytavern:latest"
PROXY_IMAGE="ghcr.nju.edu.cn/sillytavern/sillytavern:latest"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "[1/6] 拉取镜像 $IMAGE ..."
    if ! docker pull "$IMAGE"; then
        echo "      官方源失败,改用代理 $PROXY_IMAGE ..."
        docker pull "$PROXY_IMAGE"
        docker tag "$PROXY_IMAGE" "$IMAGE"
    fi
fi

# ---------- 2. 初始化配置 ----------
echo "[2/6] 初始化配置目录 ..."
mkdir -p config data plugins
if [ ! -f config/config.yaml ]; then
    cp config/config.yaml.example config/config.yaml
    echo "      已从模板生成 config/config.yaml"
fi

# ---------- 3. 启动容器 ----------
echo "[3/6] 启动容器 ..."
docker compose up -d

# ---------- 4. 注入 Docker 网关 IP 到白名单 ----------
echo "[4/6] 配置访问白名单 ..."
NETWORK="$(basename "$(pwd)")_default"
GATEWAY=$(docker network inspect "$NETWORK" --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || true)
if [ -n "$GATEWAY" ] && ! grep -q "^  - $GATEWAY$" config/config.yaml; then
    sed -i "s/^whitelist:/whitelist:\n  - $GATEWAY/" config/config.yaml
    echo "      已将 Docker 网关 $GATEWAY 加入白名单"
fi
# 反代场景关闭转发头白名单校验(模板中已默认 false,此处保证)
sed -i 's/^enableForwardedWhitelist: true/enableForwardedWhitelist: false/' config/config.yaml

# ---------- 5. 配置 nginx 反代(可选) ----------
if $INSTALL_NGINX; then
    echo "[5/6] 配置 nginx 反代 ..."
    if [ ! -d /etc/nginx ]; then
        echo "      未检测到 nginx,跳过反代配置"
    else
        mkdir -p /etc/nginx/sites-enabled
        if [ -f /etc/nginx/sites-enabled/default ] && [ ! -f /etc/nginx/sites-enabled/default.bak.orig ]; then
            cp /etc/nginx/sites-enabled/default /root/nginx-default.bak.orig
        fi
        cp nginx/sillytavern.conf /etc/nginx/sites-enabled/default
        if nginx -t 2>/dev/null; then
            systemctl reload nginx || service nginx reload || true
            echo "      nginx 反代已生效: http://<服务器IP>/"
        else
            echo "      [警告] nginx 配置测试失败,请手动检查 /etc/nginx/sites-enabled/default"
        fi
    fi
else
    echo "[5/6] 跳过 nginx(如需 80 端口反代,请运行: bash deploy.sh --nginx)"
fi

# ---------- 6. 重启容器应用配置 ----------
echo "[6/6] 重启容器应用配置 ..."
docker compose restart sillytavern

sleep 3
echo ""
echo "========================================"
echo " 部署完成!"
echo " 容器状态: $(docker inspect -f '{{.State.Status}}' sillytavern 2>/dev/null || echo unknown)"
echo " 访问地址:"
echo "   - 直连: http://<服务器IP>:8000  (需安全组放行 8000)"
$INSTALL_NGINX && echo "   - 反代: http://<服务器IP>      (需安全组放行 80)"
echo "========================================"
