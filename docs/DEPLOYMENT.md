# Spark 部署指南

## 快速部署

### 方式一：使用预编译版本

1. 从 [Releases](https://github.com/XZB-1248/Spark/releases) 下载对应平台的服务端可执行文件

2. 创建配置文件 `config.json`:
```json
{
    "listen": ":8000",
    "salt": "your-secret-salt",
    "auth": {
        "admin": "your-password"
    }
}
```

3. 将 `built` 目录（预编译客户端）放到服务端同级目录

4. 运行服务端:
```bash
./spark-server
```

5. 访问 `http://your-server:8000` 进入Web界面

### 方式二：从源码编译

#### 环境要求

- Go 1.18+
- Node.js 16+
- npm 8+
- Git

#### 编译步骤

```bash
# 克隆代码
git clone https://github.com/XZB-1248/Spark.git
cd Spark

# 编译前端
cd web
npm install
npm run build-prod
cd ..

# 嵌入静态资源
go install github.com/rakyll/statik@latest
statik -m -src="./web/dist" -f -dest="./server/embed" -p web -ns web

# 编译客户端
mkdir -p built
./scripts/build.client.sh

# 编译服务端
mkdir -p releases
./scripts/build.server.sh
```

---

## 配置详解

### 服务端配置 (`config.json`)

```json
{
    "listen": ":8000",
    "salt": "your-secret-salt-max-24",
    "auth": {
        "admin": "$sha256$e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    "log": {
        "level": "info",
        "path": "./logs",
        "days": 7
    }
}
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `listen` | 是 | 监听地址，格式 `IP:Port` 或 `:Port` |
| `salt` | 是 | 加密盐值，长度≤24字符，修改后需重新生成所有客户端 |
| `auth` | 否 | 认证配置，key为用户名，value为密码 |
| `log.level` | 否 | 日志级别: `disable`/`fatal`/`error`/`warn`/`info`/`debug` |
| `log.path` | 否 | 日志目录，默认 `./logs` |
| `log.days` | 否 | 日志保留天数，默认 7 |

### 密码格式

支持三种格式：

1. **明文密码**: `password123`
2. **SHA256**: `$sha256$<hex_hash>`
3. **SHA512**: `$sha512$<hex_hash>`
4. **Bcrypt**: `$bcrypt$<bcrypt_hash>`

生成SHA256密码示例:
```bash
echo -n "your-password" | sha256sum | cut -d' ' -f1
# 输出: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
# 配置: "$sha256$e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
```

### 命令行参数

服务端支持以下命令行参数（优先级高于配置文件）：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-config` | `config.json` | 配置文件路径 |
| `-listen` | `:8000` | 监听地址 |
| `-salt` | - | 加密盐值 |
| `-username` | - | Web界面用户名 |
| `-password` | - | Web界面密码 |
| `-log-level` | `info` | 日志级别 |
| `-log-path` | `./logs` | 日志目录 |
| `-log-days` | `7` | 日志保留天数 |
| `-device_info_file` | `device_info.json` | 设备信息持久化文件 |
| `-built_path` | `./built/%v_%v` | 预编译客户端路径模板 |

---

## 目录结构

部署后的推荐目录结构:

```
spark-server/
├── spark-server          # 服务端可执行文件
├── config.json           # 配置文件
├── device_info.json      # 设备信息（自动生成）
├── logs/                 # 日志目录（自动生成）
│   ├── 2024-01-01.log
│   └── ...
└── built/                # 预编译客户端
    ├── linux_amd64
    ├── linux_arm64
    ├── linux_arm
    ├── linux_i386
    ├── windows_amd64
    ├── windows_arm64
    └── windows_i386
```

---

## 反向代理配置

### Nginx

```nginx
server {
    listen 80;
    server_name spark.example.com;

    # 重定向到HTTPS
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

        # WebSocket支持
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 超时设置
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```

### Caddy

```caddyfile
spark.example.com {
    reverse_proxy localhost:8000 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

---

## Docker 部署

### Dockerfile 示例

```dockerfile
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git nodejs npm

WORKDIR /app
COPY . .

# 构建前端
WORKDIR /app/web
RUN npm install && npm run build-prod

# 嵌入静态资源
WORKDIR /app
RUN go install github.com/rakyll/statik@latest
RUN statik -m -src="./web/dist" -f -dest="./server/embed" -p web -ns web

# 构建服务端
RUN CGO_ENABLED=0 GOOS=linux go build -o spark-server ./server

FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/spark-server .
COPY --from=builder /app/built ./built

EXPOSE 8000

CMD ["./spark-server"]
```

### Docker Compose

```yaml
version: '3.8'

services:
  spark:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./config.json:/app/config.json:ro
      - ./logs:/app/logs
      - ./device_info.json:/app/device_info.json
    restart: unless-stopped
```

---

## Systemd 服务

创建 `/etc/systemd/system/spark.service`:

```ini
[Unit]
Description=Spark Remote Administration Tool
After=network.target

[Service]
Type=simple
User=spark
Group=spark
WorkingDirectory=/opt/spark
ExecStart=/opt/spark/spark-server
Restart=always
RestartSec=5
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
```

启用服务:
```bash
sudo systemctl daemon-reload
sudo systemctl enable spark
sudo systemctl start spark
```

---

## 客户端部署

### 环境变量

客户端支持通过环境变量覆盖设备ID:

```bash
export SPARK_DEVICE_ID="your-custom-64-char-device-id"
./spark-client
```

### Windows 自启动

1. 将客户端复制到 `C:\Users\<用户名>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\`
2. 或创建计划任务

### Linux 自启动

创建 systemd 用户服务:

```ini
# ~/.config/systemd/user/spark-client.service
[Unit]
Description=Spark Client

[Service]
ExecStart=/path/to/spark-client
Restart=always

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable spark-client
systemctl --user start spark-client
```

---

## 安全建议

1. **使用HTTPS**: 通过反向代理启用TLS加密
2. **强密码**: 使用哈希密码格式，避免明文密码
3. **防火墙**: 仅开放必要端口
4. **定期更新Salt**: 修改salt后重新生成所有客户端
5. **日志审计**: 定期检查日志文件
6. **网络隔离**: 将服务部署在内网或VPN中

---

## 故障排查

### 客户端无法连接

1. 检查服务端是否正常运行
2. 检查防火墙设置
3. 确认客户端配置的服务器地址正确
4. 检查Salt配置是否一致

### WebSocket连接失败

1. 检查反向代理是否正确配置WebSocket
2. 检查超时设置
3. 查看服务端日志

### 认证失败

1. 检查用户名密码格式
2. 如使用哈希密码，确认哈希格式正确
3. 检查是否被限流（登录失败过多）

---

## 性能优化

1. **调整Nginx缓冲区**:
```nginx
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;
```

2. **启用Gzip压缩** (服务端已内置支持)

3. **增加文件描述符限制**:
```bash
ulimit -n 65535
```

---

*文档版本: 1.0*

