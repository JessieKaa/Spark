# Spark Docker 部署指南

本文档介绍如何使用 Docker 部署 Spark 服务端。

## 快速开始

### 方式一：使用 docker-compose（推荐）

1. **准备配置文件**

```bash
# 创建配置目录
mkdir -p docker-data

# 复制示例配置文件
cp docker-data/config.json.example docker-data/config.json

# 编辑配置文件
vim docker-data/config.json
```

配置文件示例：
```json
{
    "listen": ":8000",
    "salt": "your-secret-salt",
    "auth": {
        "admin": "your-password"
    },
    "log": {
        "level": "info",
        "path": "/app/logs",
        "days": 7
    },
    "database_path": "/app/data/spark.db"
}
```

2. **构建并启动**

```bash
# 使用管理脚本
chmod +x scripts/docker-start.sh
./scripts/docker-start.sh build
./scripts/docker-start.sh start

# 或者直接使用 docker-compose
docker-compose up -d --build
```

3. **访问服务**

打开浏览器访问 `http://localhost:8000`

### 方式二：使用预编译版本

如果你已经有编译好的二进制文件，可以使用更轻量的镜像：

```bash
# 使用预编译 Dockerfile
docker build -f Dockerfile.prebuilt -t spark-server:prebuilt .

# 运行容器
docker run -d \
    --name spark-server \
    -p 8000:8000 \
    -v $(pwd)/docker-data:/app/data \
    -v $(pwd)/docker-data/logs:/app/logs \
    spark-server:prebuilt
```

## 管理脚本

项目提供了便捷的管理脚本 `scripts/docker-start.sh`：

```bash
# 查看帮助
./scripts/docker-start.sh help

# 构建镜像
./scripts/docker-start.sh build

# 启动服务
./scripts/docker-start.sh start

# 停止服务
./scripts/docker-start.sh stop

# 重启服务
./scripts/docker-start.sh restart

# 查看日志
./scripts/docker-start.sh logs

# 进入容器
./scripts/docker-start.sh shell

# 查看状态
./scripts/docker-start.sh status

# 清理数据（危险）
./scripts/docker-start.sh clean
```

## 目录结构

```
spark/
├── docker-data/           # Docker 数据目录
│   ├── config.json        # 配置文件
│   ├── config.json.example # 配置示例
│   ├── spark.db           # SQLite 数据库（自动生成）
│   └── logs/              # 日志目录
├── built/                 # 预编译客户端
├── Dockerfile             # 完整构建 Dockerfile
├── Dockerfile.prebuilt    # 预编译版 Dockerfile
├── docker-compose.yml     # Docker Compose 配置
└── .dockerignore          # Docker 忽略文件
```

## 数据持久化

以下数据会被持久化到 `docker-data` 目录：

| 路径 | 说明 |
|------|------|
| `/app/data/config.json` | 配置文件 |
| `/app/data/spark.db` | SQLite 数据库 |
| `/app/logs/` | 日志文件 |
| `/app/built/` | 预编译客户端 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TZ` | `Asia/Shanghai` | 时区 |

## 端口映射

| 容器端口 | 说明 |
|----------|------|
| 8000 | HTTP/WebSocket 服务 |

## 资源限制

docker-compose.yml 中配置了资源限制：

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 512M
    reservations:
      cpus: '0.5'
      memory: 128M
```

根据实际需要调整这些值。

## 反向代理配置

### Nginx 示例

```nginx
server {
    listen 80;
    server_name spark.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name spark.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 支持
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 超时设置
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```

### Traefik 示例（docker-compose）

```yaml
version: '3.8'

services:
  spark:
    image: spark-server:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.spark.rule=Host(`spark.example.com`)"
      - "traefik.http.routers.spark.entrypoints=websecure"
      - "traefik.http.routers.spark.tls.certresolver=letsencrypt"
      - "traefik.http.services.spark.loadbalancer.server.port=8000"
    networks:
      - traefik-network
```

## 常见问题

### 1. 容器无法启动

检查配置文件是否存在且格式正确：
```bash
cat docker-data/config.json | jq .
```

### 2. 客户端无法连接

确保：
- 防火墙开放了 8000 端口
- 如果使用反向代理，确保配置了 WebSocket 支持
- salt 配置与生成客户端时一致

### 3. 数据库锁定错误

SQLite 只支持单写，确保只有一个实例运行：
```bash
docker-compose ps
```

### 4. 健康检查失败

查看容器日志：
```bash
docker-compose logs spark
```

### 5. 权限问题

确保 docker-data 目录有正确的权限：
```bash
chmod -R 755 docker-data
```

## 升级指南

1. **备份数据**
```bash
cp -r docker-data docker-data.bak
```

2. **拉取新代码**
```bash
git pull origin main
```

3. **重新构建**
```bash
./scripts/docker-start.sh build
./scripts/docker-start.sh restart
```

## 生产环境建议

1. **使用 HTTPS**：通过反向代理启用 TLS
2. **定期备份**：备份 `docker-data` 目录
3. **日志轮转**：配置日志保留天数
4. **监控告警**：监控容器健康状态
5. **资源限制**：根据实际负载调整资源限制

---

*文档版本: 1.0*

