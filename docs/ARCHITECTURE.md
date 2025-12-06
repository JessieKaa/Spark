# Spark 技术架构文档

## 项目概述

**Spark** 是一个开源、跨平台、基于Web的远程管理工具（Remote Administration Tool，RAT）。它允许用户通过浏览器管理和控制多台设备。项目采用 Go 语言开发服务端和客户端，使用 React 开发前端界面。

## 目录结构

```
Spark/
├── client/                 # 客户端代码
│   ├── client.go          # 客户端入口
│   ├── common/            # 通用工具
│   ├── config/            # 客户端配置
│   ├── core/              # 核心功能
│   │   ├── core.go        # WebSocket连接和消息处理
│   │   ├── device.go      # 设备信息采集
│   │   └── handler.go     # 命令处理器
│   └── service/           # 服务模块
│       ├── basic/         # 系统基础操作（锁屏、关机等）
│       ├── desktop/       # 远程桌面
│       ├── file/          # 文件管理
│       ├── process/       # 进程管理
│       ├── screenshot/    # 截图功能
│       └── terminal/      # 远程终端
├── server/                 # 服务端代码
│   ├── main.go            # 服务端入口
│   ├── auth/              # 认证模块
│   ├── common/            # 通用工具和事件处理
│   ├── config/            # 服务端配置
│   ├── embed/             # 嵌入资源
│   │   ├── devices/       # 设备信息持久化
│   │   └── web/           # 前端静态资源（statik）
│   └── handler/           # API处理器
│       ├── bridge/        # 数据桥接
│       ├── desktop/       # 远程桌面
│       ├── file/          # 文件操作
│       ├── generate/      # 客户端生成
│       ├── process/       # 进程管理
│       ├── screenshot/    # 截图
│       ├── terminal/      # 终端
│       └── utility/       # 工具函数
├── web/                    # 前端代码（React）
│   ├── src/
│   │   ├── components/    # React组件
│   │   ├── pages/         # 页面
│   │   ├── locale/        # 国际化
│   │   └── utils/         # 工具函数
│   └── webpack.config.js  # Webpack配置
├── modules/                # 公共数据结构
├── utils/                  # 通用工具库
│   ├── cmap/              # 并发安全Map
│   └── melody/            # WebSocket库（基于Gorilla）
├── scripts/                # 构建脚本
├── built/                  # 预编译的客户端二进制
└── docs/                   # 文档和截图
```

## 技术栈

### 后端（Go 1.18+）

| 库名 | 用途 |
|------|------|
| `gin-gonic/gin` | HTTP Web框架 |
| `gorilla/websocket` | WebSocket通信 |
| `shirou/gopsutil` | 系统信息采集 |
| `kbinani/screenshot` | 屏幕截图 |
| `creack/pty` | 伪终端 |
| `imroc/req` | HTTP客户端 |
| `json-iterator/go` | 高性能JSON |
| `rakyll/statik` | 静态资源嵌入 |

### 前端（React 17）

| 库名 | 用途 |
|------|------|
| `react` / `react-dom` | UI框架 |
| `antd` | Ant Design UI组件库 |
| `@ant-design/pro-table` | 高级表格组件 |
| `axios` | HTTP请求 |
| `xterm.js` | 终端模拟 |
| `react-ace` | 代码编辑器 |
| `i18next` | 国际化 |
| `zmodem.js` | Zmodem文件传输 |

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                        用户浏览器                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              React Frontend (Web)                    │   │
│  │  - Overview (设备列表)                               │   │
│  │  - Terminal (远程终端)                               │   │
│  │  - Desktop (远程桌面)                                │   │
│  │  - Explorer (文件管理)                               │   │
│  │  - ProcMgr (进程管理)                                │   │
│  └──────────────────────┬──────────────────────────────┘   │
└─────────────────────────┼───────────────────────────────────┘
                          │ HTTP/WebSocket
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Server (Go)                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Gin HTTP Server                      │   │
│  │  - /api/*          REST API                         │   │
│  │  - /ws             WebSocket (客户端连接)            │   │
│  │  - /*              静态资源                          │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               Melody WebSocket Hub                   │   │
│  │  - 会话管理 (Session Management)                     │   │
│  │  - 消息广播 (Message Broadcasting)                   │   │
│  │  - 事件回调 (Event Callbacks)                        │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                Device Registry                       │   │
│  │  - 设备状态维护 (ConcurrentMap)                      │   │
│  │  - 连接健康检查                                       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────┘
                          │ WebSocket (AES加密)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Client (Go)                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                Core Module                           │   │
│  │  - WebSocket连接管理                                  │   │
│  │  - 命令分发处理                                       │   │
│  │  - 设备信息上报                                       │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               Service Modules                        │   │
│  │  - Basic (系统操作)                                  │   │
│  │  - Terminal (PTY终端)                               │   │
│  │  - Desktop (屏幕捕获)                                │   │
│  │  - File (文件操作)                                   │   │
│  │  - Process (进程管理)                                │   │
│  │  - Screenshot (截图)                                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 通信协议

### WebSocket 数据包格式

#### 普通数据包 (JSON)

```go
type Packet struct {
    Code  int            `json:"code"`           // 响应码: 0=成功
    Act   string         `json:"act,omitempty"`  // 动作类型
    Msg   string         `json:"msg,omitempty"`  // 消息内容
    Data  map[string]any `json:"data,omitempty"` // 数据载荷
    Event string         `json:"event,omitempty"`// 事件ID（用于回调）
}
```

#### 二进制数据包

用于大数据传输（桌面帧、文件内容等）：

```
[4字节魔数: 0x22161311] + [1字节服务类型] + [1字节操作码] + [2字节保留] + [16字节事件ID] + [数据]
```

服务类型:
- `20`: 文件服务
- `21`: 终端服务

### 加密机制

1. **握手阶段**：客户端使用预共享Salt + UUID进行AES-CTR加密验证
2. **会话阶段**：服务端生成32字节随机Secret，用于后续所有数据的AES-CTR加密
3. **数据完整性**：使用MD5校验（16字节前缀）

```go
// 加密格式: MD5(plaintext) + AES-CTR(plaintext + 64字节随机nonce)
func Encrypt(data []byte, key []byte) ([]byte, error) {
    nonce := make([]byte, 64)
    rand.Reader.Read(nonce)
    data = append(data, nonce...)
    
    hash, _ := GetMD5(data)
    block, _ := aes.NewCipher(key)
    stream := cipher.NewCTR(block, hash)
    
    encBuffer := make([]byte, len(data))
    stream.XORKeyStream(encBuffer, data)
    return append(hash, encBuffer...), nil
}
```

## 核心模块说明

### 1. 设备信息模块 (`modules/modules.go`)

```go
type Device struct {
    Remark      string `json:"remark"`       // 设备备注
    ID          string `json:"id"`           // 设备唯一ID
    OS          string `json:"os"`           // 操作系统
    Arch        string `json:"arch"`         // CPU架构
    LAN         string `json:"lan"`          // 局域网IP
    WAN         string `json:"wan"`          // 公网IP
    MAC         string `json:"mac"`          // MAC地址
    Net         Net    `json:"net"`          // 网络IO
    CPU         CPU    `json:"cpu"`          // CPU信息
    RAM         IO     `json:"ram"`          // 内存信息
    Disk        IO     `json:"disk"`         // 磁盘信息
    Uptime      uint64 `json:"uptime"`       // 运行时间
    Latency     uint   `json:"latency"`      // 延迟(ms)
    Hostname    string `json:"hostname"`     // 主机名
    Username    string `json:"username"`     // 当前用户
    OfflineTime int64  `json:"offline_time"` // 离线时间戳
}
```

### 2. 客户端命令处理器 (`client/core/handler.go`)

支持的操作：

| 命令 | 说明 |
|------|------|
| `PING` | 心跳检测 |
| `OFFLINE` | 下线 |
| `LOCK` | 锁屏 |
| `LOGOFF` | 注销 |
| `HIBERNATE` | 休眠 |
| `SUSPEND` | 睡眠 |
| `RESTART` | 重启 |
| `SHUTDOWN` | 关机 |
| `SCREENSHOT` | 截图 |
| `TERMINAL_*` | 终端操作 |
| `FILES_*` | 文件操作 |
| `PROCESSES_*` | 进程操作 |
| `DESKTOP_*` | 桌面操作 |
| `COMMAND_EXEC` | 执行命令 |

### 3. 服务端API路由 (`server/handler/handler.go`)

```go
// 公开路由
/api/bridge/push      // 数据上传桥接
/api/bridge/pull      // 数据下载桥接

// 认证路由 (需要登录)
POST /api/device/screenshot/get  // 获取截图
POST /api/device/process/list    // 进程列表
POST /api/device/process/kill    // 杀死进程
POST /api/device/file/remove     // 删除文件
POST /api/device/file/upload     // 上传文件
POST /api/device/file/list       // 文件列表
POST /api/device/file/text       // 读取文本文件
POST /api/device/file/get        // 下载文件
POST /api/device/exec            // 执行命令
POST /api/device/list            // 设备列表
POST /api/device/:act            // 设备控制(lock/restart等)
POST /api/client/check           // 检查客户端
POST /api/client/generate        // 生成客户端
WS   /api/device/terminal        // 终端WebSocket
WS   /api/device/desktop         // 桌面WebSocket
```

## 配置说明

### 服务端配置 (`config.json`)

```json
{
    "listen": ":8000",           // 监听地址
    "salt": "123456abcdef",      // 加密盐值 (≤24字符)
    "auth": {                     // 认证配置 (可选)
        "admin": "$sha256$xxxxx" // 用户名: 密码(支持sha256/sha512/bcrypt)
    },
    "log": {                      // 日志配置
        "level": "info",          // 级别: disable/fatal/error/warn/info/debug
        "path": "./logs",         // 路径
        "days": 7                 // 保留天数
    }
}
```

### 客户端配置

客户端配置嵌入在二进制文件中，包含：
- `uuid`: 客户端UUID
- `key`: 加密密钥
- `host`: 服务器地址
- `path`: API路径
- `remark`: 设备备注

## 构建指南

### 前置条件

- Go 1.18+
- Node.js 16+
- npm 8+

### 构建步骤

```bash
# 1. 克隆仓库
git clone https://github.com/XZB-1248/Spark
cd Spark

# 2. 构建前端
cd web
npm install
npm run build-prod

# 3. 嵌入静态资源
cd ..
go install github.com/rakyll/statik
statik -m -src="./web/dist" -f -dest="./server/embed" -p web -ns web

# 4. 构建客户端
mkdir -p built
./scripts/build.client.sh

# 5. 构建服务端
mkdir -p releases
./scripts/build.server.sh
```

### 支持的平台

| 平台 | 架构 |
|------|------|
| Windows | amd64, arm64, i386 |
| Linux | amd64, arm64, arm, i386 |
| macOS | amd64, arm64 |

## 安全注意事项

1. **Salt配置**：修改Salt后需重新生成所有客户端
2. **密码存储**：推荐使用哈希密码格式 `$algorithm$hash`
3. **网络传输**：所有WebSocket数据均使用AES-CTR加密
4. **认证保护**：支持登录失败限流

## 功能特性

| 功能 | Windows | Linux | macOS |
|------|---------|-------|-------|
| 进程管理 | ✅ | ✅ | ✅ |
| 杀死进程 | ✅ | ✅ | ✅ |
| 网络流量监控 | ✅ | ✅ | ✅ |
| 文件浏览 | ✅ | ✅ | ✅ |
| 文件传输 | ✅ | ✅ | ✅ |
| 文件编辑 | ✅ | ✅ | ✅ |
| 桌面监控 | ✅ | ✅ | ✅ |
| 截图 | ✅ | ✅ | ✅ |
| 远程终端 | ✅ | ✅ | ✅ |
| 关机/重启 | ✅ | ✅ | ✅ |
| 锁屏 | ✅ | ❌ | ❌ |
| 注销 | ✅ | ❌ | ✅ |
| 睡眠 | ✅ | ❌ | ✅ |
| 休眠 | ✅ | ❌ | ❌ |

---

*文档生成时间: 2024*

