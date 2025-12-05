#!/bin/bash

# Spark Docker 启动脚本
# 使用方法: ./scripts/docker-start.sh [build|start|stop|restart|logs|shell]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查配置文件是否存在
check_config() {
    if [ ! -f "docker-data/config.json" ]; then
        echo -e "${YELLOW}配置文件不存在，正在从示例文件创建...${NC}"
        mkdir -p docker-data
        if [ -f "docker-data/config.json.example" ]; then
            cp docker-data/config.json.example docker-data/config.json
            echo -e "${YELLOW}请编辑 docker-data/config.json 配置文件后重新启动${NC}"
            exit 1
        else
            echo -e "${RED}示例配置文件不存在，请手动创建 docker-data/config.json${NC}"
            exit 1
        fi
    fi
}

# 构建镜像
build() {
    echo -e "${GREEN}正在构建 Docker 镜像...${NC}"
    docker-compose build --no-cache
    echo -e "${GREEN}构建完成！${NC}"
}

# 启动服务
start() {
    check_config
    echo -e "${GREEN}正在启动 Spark 服务...${NC}"
    docker-compose up -d
    echo -e "${GREEN}服务已启动！${NC}"
    echo -e "${GREEN}访问地址: http://localhost:8000${NC}"
}

# 停止服务
stop() {
    echo -e "${YELLOW}正在停止 Spark 服务...${NC}"
    docker-compose down
    echo -e "${GREEN}服务已停止！${NC}"
}

# 重启服务
restart() {
    stop
    start
}

# 查看日志
logs() {
    docker-compose logs -f --tail=100
}

# 进入容器
shell() {
    docker-compose exec spark /bin/sh
}

# 显示状态
status() {
    docker-compose ps
}

# 清理（停止并删除数据）
clean() {
    echo -e "${RED}警告：这将删除所有数据！${NC}"
    read -p "确定要继续吗？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v
        rm -rf docker-data/spark.db docker-data/logs
        echo -e "${GREEN}清理完成！${NC}"
    else
        echo -e "${YELLOW}已取消${NC}"
    fi
}

# 显示帮助
help() {
    echo "Spark Docker 管理脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  build    构建 Docker 镜像"
    echo "  start    启动服务"
    echo "  stop     停止服务"
    echo "  restart  重启服务"
    echo "  logs     查看日志"
    echo "  shell    进入容器"
    echo "  status   查看服务状态"
    echo "  clean    清理所有数据（危险）"
    echo "  help     显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build   # 构建镜像"
    echo "  $0 start   # 启动服务"
    echo "  $0 logs    # 查看日志"
}

# 主逻辑
case "${1:-help}" in
    build)
        build
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        logs
        ;;
    shell)
        shell
        ;;
    status)
        status
        ;;
    clean)
        clean
        ;;
    help|*)
        help
        ;;
esac

