# 酒馆 (SillyTavern) 部署

基于 Docker Compose 的 SillyTavern 一键部署配置。

## 服务器部署

```bash
# 克隆仓库
git clone https://github.com/Xenon-024/fllstck.git
cd fllstck

# 启动
docker compose up -d

# 查看日志
docker compose logs -f
```

启动后访问 `http://<服务器IP>:8000`

## 说明

- 数据持久化在 `config/`、`data/`、`plugins/` 目录
- 容器设置了 `restart: unless-stopped`,服务器重启后自动拉起
- 若需公网访问,请在云安全组/防火墙中放行 `8000` 端口
- 建议接入反向代理(如 Caddy/Nginx)并配置 HTTPS
