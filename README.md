# 酒馆 (SillyTavern) 部署

基于 Docker Compose 的 SillyTavern 一键部署配置，配置全部固化在仓库中，服务器拉取后一键完成部署。

## 服务器部署（推荐）

```bash
# 克隆仓库
git clone https://github.com/Xenon-024/fllstck.git
cd fllstck

# 一键部署（自动拉镜像、初始化配置、注入白名单）
bash deploy.sh

# 若安全组只放行 80 端口，附加 nginx 反代
bash deploy.sh --nginx
```

部署脚本会自动完成：

1. 拉取镜像（ghcr.io 直连失败自动切换南京大学代理 `ghcr.nju.edu.cn`）
2. 由 `config/config.yaml.example` 模板初始化配置
3. 启动容器并把 Docker 网关 IP 注入 `whitelist` 白名单
4. （`--nginx` 时）安装 `nginx/sillytavern.conf` 反代配置并生效
5. 重启容器应用配置

## 访问

- 直连：`http://<服务器IP>:8000`（需云安全组放行 8000 端口）
- 反代：`http://<服务器IP>`（需云安全组放行 80 端口）

## 目录结构

```
├── docker-compose.yml          # 容器编排（端口 8000，数据持久化，自动重启）
├── config/
│   └── config.yaml.example     # 官方默认配置模板（已针对反代场景预调）
├── nginx/
│   └── sillytavern.conf        # nginx 反代配置（含 WebSocket 支持）
├── deploy.sh                   # 一键部署脚本
└── .gitignore
```

## 说明

- 数据持久化在 `config/`、`data/`、`plugins/` 目录（运行时生成，已 git 忽略）
- 容器设置了 `restart: unless-stopped`，服务器重启后自动拉起
- `config.yaml.example` 中已设置 `enableForwardedWhitelist: false`，适配 nginx 反代场景
- 更新酒馆版本：`docker compose pull && docker compose up -d`

## 国内服务器安装 Docker（阿里云镜像源）

```bash
mkdir -p /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```
