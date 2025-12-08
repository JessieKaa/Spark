# ============================================
# 阶段1: 构建前端
# ============================================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/web

# 复制前端依赖文件
COPY web/package*.json ./

# 安装依赖
RUN npm ci --registry=https://registry.npmmirror.com

# 复制前端源码
COPY web/ ./

# 构建前端
RUN npm run build-prod

# ============================================
# 阶段2: 构建后端
# ============================================
FROM golang:1.21-alpine AS backend-builder

# 安装必要的构建工具
RUN apk add --no-cache git gcc musl-dev

WORKDIR /app

# 设置Go代理
ENV GOPROXY=https://goproxy.cn,direct
ENV CGO_ENABLED=1

# 复制go模块文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 安装statik工具
RUN go install github.com/rakyll/statik@latest

# 复制源码
COPY . .

# 复制前端构建产物
COPY --from=frontend-builder /app/web/dist ./web/dist

# 嵌入静态资源
RUN statik -m -src="./web/dist" -f -dest="./server/embed" -p web -ns web

# 构建服务端
RUN go build -ldflags="-s -w" -o spark-server ./server

# 构建客户端（多平台）- 禁用 CGO 以支持交叉编译
RUN mkdir -p built && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o built/linux_amd64 ./client && \
    CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o built/linux_arm64 ./client && \
    CGO_ENABLED=0 GOOS=linux GOARCH=arm go build -ldflags="-s -w" -o built/linux_arm ./client 
    # && \
    # CGO_ENABLED=0 GOOS=linux GOARCH=386 go build -ldflags="-s -w" -o built/linux_i386 ./client && \
    # CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o built/windows_amd64 ./client && \
    # CGO_ENABLED=0 GOOS=windows GOARCH=386 go build -ldflags="-s -w" -o built/windows_i386 ./client

# ============================================
# 阶段3: 最终运行镜像
# ============================================
FROM alpine:latest

# 安装必要的运行时依赖
RUN apk add --no-cache ca-certificates tzdata

# 设置时区
ENV TZ=Asia/Shanghai

WORKDIR /app

# 从构建阶段复制编译好的文件
COPY --from=backend-builder /app/spark-server .
COPY --from=backend-builder /app/built ./built

# 创建数据目录
RUN mkdir -p /app/data /app/logs

# 暴露端口
EXPOSE 8000

# 设置数据卷
VOLUME ["/app/data", "/app/logs", "/app/built"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/ || exit 1

# 启动命令
ENTRYPOINT ["./spark-server"]

# 默认参数
CMD ["-config", "/app/data/config.json", "-database", "/app/data/spark.db", "-log-path", "/app/logs"]

