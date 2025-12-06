# Spark 开发指南

## 开发环境搭建

### 前置要求

- Go 1.18+ (推荐 1.21+)
- Node.js 16+ (推荐 18+)
- npm 8+
- Git
- 可选: Make, Docker

### 克隆项目

```bash
git clone https://github.com/XZB-1248/Spark.git
cd Spark
```

### 安装依赖

```bash
# Go依赖
go mod download

# 前端依赖
cd web
npm install
cd ..

# 安装statik工具
go install github.com/rakyll/statik@latest
```

### 开发模式运行

#### 前端开发

```bash
cd web
npm start
# 访问 http://localhost:8080 (Webpack Dev Server)
```

#### 服务端开发

```bash
# 先构建一次前端并嵌入资源
cd web && npm run build-dev && cd ..
statik -m -src="./web/dist" -f -dest="./server/embed" -p web -ns web

# 运行服务端
go run ./server
```

---

## 代码结构详解

### 客户端模块 (`client/`)

```
client/
├── client.go              # 入口文件，初始化配置
├── common/
│   └── common.go          # WebSocket连接封装、HTTP客户端
├── config/
│   └── config.go          # 客户端配置结构
├── core/
│   ├── core.go            # 主循环、WebSocket处理
│   ├── device.go          # 设备信息采集
│   └── handler.go         # 命令路由和处理器
└── service/
    ├── basic/             # 系统基础操作
    │   ├── basic_windows.go  # Windows实现
    │   ├── basic_linux.go    # Linux实现
    │   ├── basic_darwin.go   # macOS实现
    │   └── basic_others.go   # 其他平台存根
    ├── desktop/           # 远程桌面
    ├── file/              # 文件操作
    ├── process/           # 进程管理
    ├── screenshot/        # 截图
    └── terminal/          # 远程终端
```

#### 核心流程

```go
// client/core/core.go
func Start() {
    for !stop {
        // 1. 建立WebSocket连接
        common.WSConn, _ = connectWS()
        
        // 2. 上报设备信息
        reportWS(common.WSConn)
        
        // 3. 处理消息循环
        handleWS(common.WSConn)
    }
}

// 命令分发
func handleAct(pack modules.Packet, wsConn *common.Conn) {
    if act, ok := handlers[pack.Act]; ok {
        act(pack, wsConn)
    }
}
```

#### 添加新命令

1. 在 `handler.go` 中注册命令:
```go
var handlers = map[string]func(pack modules.Packet, wsConn *common.Conn){
    // ...
    `NEW_COMMAND`: newCommand,
}
```

2. 实现处理函数:
```go
func newCommand(pack modules.Packet, wsConn *common.Conn) {
    // 从pack.Data获取参数
    val, ok := pack.GetData(`param`, reflect.String)
    
    // 执行操作
    result, err := doSomething()
    
    // 返回结果
    if err != nil {
        wsConn.SendCallback(modules.Packet{Code: 1, Msg: err.Error()}, pack)
    } else {
        wsConn.SendCallback(modules.Packet{Code: 0, Data: map[string]any{"result": result}}, pack)
    }
}
```

### 服务端模块 (`server/`)

```
server/
├── main.go                # 入口文件、HTTP服务、WebSocket处理
├── auth/
│   └── auth.go            # 基础认证中间件
├── common/
│   ├── common.go          # 通用工具、加解密
│   ├── event.go           # 事件回调系统
│   └── log.go             # 日志封装
├── config/
│   └── config.go          # 服务端配置
├── embed/
│   ├── devices/
│   │   └── device_file.go # 设备信息持久化
│   └── web/
│       └── statik.go      # 嵌入的前端资源
└── handler/
    ├── handler.go         # 路由初始化
    ├── bridge/            # 数据桥接
    ├── desktop/           # 桌面WebSocket
    ├── file/              # 文件API
    ├── generate/          # 客户端生成
    ├── process/           # 进程API
    ├── screenshot/        # 截图API
    ├── terminal/          # 终端WebSocket
    └── utility/           # 设备管理API
```

#### 事件回调系统

```go
// server/common/event.go
// 添加一次性事件监听
func AddEventOnce(fn EventCallback, uuid, event string, timeout time.Duration) bool

// 触发事件
func CallEvent(pack modules.Packet, session *melody.Session)
```

使用示例:
```go
// 发送命令并等待响应
trigger := utils.GetStrUUID()
common.SendPackByUUID(modules.Packet{Act: `SOME_ACTION`, Event: trigger}, connUUID)

ok := common.AddEventOnce(func(p modules.Packet, _ *melody.Session) {
    if p.Code != 0 {
        ctx.JSON(http.StatusInternalServerError, p)
    } else {
        ctx.JSON(http.StatusOK, p)
    }
}, connUUID, trigger, 5*time.Second)

if !ok {
    ctx.JSON(http.StatusGatewayTimeout, modules.Packet{Code: 1, Msg: "timeout"})
}
```

#### 添加新API

1. 在 `handler/handler.go` 中添加路由:
```go
func InitRouter(ctx *gin.RouterGroup) {
    group := ctx.Group(`/`, AuthHandler)
    {
        // ...
        group.POST(`/device/new-feature`, newFeature.Handler)
    }
}
```

2. 创建处理器文件:
```go
// handler/newfeature/newfeature.go
package newfeature

func Handler(ctx *gin.Context) {
    // 检查参数和设备
    connUUID, ok := utility.CheckForm(ctx, &form)
    if !ok {
        return
    }
    
    // 发送命令到客户端
    trigger := utils.GetStrUUID()
    common.SendPackByUUID(modules.Packet{
        Act:   `NEW_COMMAND`,
        Data:  gin.H{"param": form.Param},
        Event: trigger,
    }, connUUID)
    
    // 等待响应
    common.AddEventOnce(func(p modules.Packet, _ *melody.Session) {
        ctx.JSON(http.StatusOK, p)
    }, connUUID, trigger, 5*time.Second)
}
```

### 前端模块 (`web/`)

```
web/
├── src/
│   ├── index.jsx          # 应用入口
│   ├── global.css         # 全局样式
│   ├── components/
│   │   ├── wrapper.jsx    # 布局容器
│   │   ├── modal.jsx      # 模态框组件
│   │   ├── terminal/      # 终端组件
│   │   ├── desktop/       # 桌面组件
│   │   ├── explorer/      # 文件管理器
│   │   ├── procmgr/       # 进程管理器
│   │   ├── generate/      # 客户端生成器
│   │   └── execute/       # 命令执行
│   ├── pages/
│   │   ├── overview.jsx   # 设备总览页面
│   │   └── 404.jsx        # 404页面
│   ├── locale/
│   │   ├── locale.js      # i18n配置
│   │   ├── en.js          # 英文
│   │   └── zh-CN.js       # 中文
│   ├── utils/
│   │   └── utils.js       # 工具函数
│   └── vendors/
│       └── zmodem.js/     # Zmodem文件传输库
├── public/
│   └── index.html         # HTML模板
├── package.json
└── webpack.config.js
```

#### 组件开发规范

使用函数组件 + Hooks:
```jsx
function MyComponent(props) {
    const [state, setState] = useState(initialState);
    
    useEffect(() => {
        // 副作用
        return () => {
            // 清理
        };
    }, [dependencies]);
    
    return (
        <div>...</div>
    );
}
```

#### API请求封装

```javascript
// utils/utils.js
export function request(url, data = {}, headers = {}, config = {}) {
    return axios.post(url, qs.stringify(data), {
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            ...headers
        },
        ...config
    });
}
```

#### 国际化

```javascript
// 添加翻译
// locale/en.js
export default {
    "FEATURE": {
        "TITLE": "Title",
        "DESCRIPTION": "Description"
    }
}

// 使用翻译
import i18n from '../locale/locale';
i18n.t('FEATURE.TITLE')
```

### 公共模块 (`modules/`, `utils/`)

#### 数据结构 (`modules/modules.go`)

```go
// 通信数据包
type Packet struct {
    Code  int            `json:"code"`
    Act   string         `json:"act,omitempty"`
    Msg   string         `json:"msg,omitempty"`
    Data  map[string]any `json:"data,omitempty"`
    Event string         `json:"event,omitempty"`
}

// 设备信息
type Device struct {
    ID       string `json:"id"`
    OS       string `json:"os"`
    // ...
}
```

#### 工具函数 (`utils/utils.go`)

```go
// 加密
func Encrypt(data []byte, key []byte) ([]byte, error)
func Decrypt(data []byte, key []byte) ([]byte, error)

// UUID
func GetStrUUID() string
func GetUUID() []byte

// 类型工具
func If[T any](b bool, t, f T) T
func Min[T constraints](a, b T) T
func Max[T constraints](a, b T) T
```

---

## 构建脚本

### 客户端构建 (`scripts/build.client.sh`)

```bash
#!/bin/bash
platforms=("linux/amd64" "linux/arm64" "linux/arm" "linux/386" 
           "windows/amd64" "windows/arm64" "windows/386")

for platform in "${platforms[@]}"; do
    platform_split=(${platform//\// })
    GOOS=${platform_split[0]}
    GOARCH=${platform_split[1]}
    
    output_name="built/${GOOS}_${GOARCH}"
    if [ $GOOS = "windows" ]; then
        output_name+='.exe'
    fi
    
    CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH \
        go build -ldflags="-s -w" -o $output_name ./client
done
```

### 服务端构建 (`scripts/build.server.sh`)

```bash
#!/bin/bash
CGO_ENABLED=0 go build -ldflags="-s -w" -o releases/spark-server ./server
```

---

## 测试

### 单元测试

```bash
go test ./...
```

### 集成测试

1. 启动服务端
2. 使用生成的测试客户端连接
3. 通过Web界面或API测试功能

---

## 调试技巧

### 日志级别

服务端配置 `log.level: debug` 获取详细日志。

### WebSocket抓包

使用 Chrome DevTools → Network → WS 查看WebSocket消息。

### 客户端调试

```bash
# 带详细日志运行
GOLOG_LEVEL=debug ./spark-client
```

---

## 代码规范

### Go代码

- 使用 `gofmt` 格式化
- 遵循官方 [Effective Go](https://golang.org/doc/effective_go.html)
- 错误处理要完整

### JavaScript代码

- 使用 ES6+ 语法
- React组件使用函数式组件
- 避免直接操作DOM

### 提交信息

```
feat: 添加新功能
fix: 修复bug
docs: 文档更新
refactor: 代码重构
test: 测试相关
chore: 构建/工具变更
```

---

## 常见问题

### Q: 如何支持新平台？

A: 在 `client/service/` 下添加平台特定实现文件，如 `basic_newos.go`，使用构建标签:
```go
//go:build newos
```

### Q: 如何添加新的系统信息采集？

A: 修改 `client/core/device.go` 中的 `GetDevice()` 函数。

### Q: 如何自定义客户端配置字段？

A: 修改 `client/config/config.go` 中的配置结构，并更新服务端的生成逻辑。

---

*文档版本: 1.0*

