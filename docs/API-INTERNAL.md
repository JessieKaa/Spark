# Spark 内部API文档

## 概述

本文档描述了Spark服务端与客户端之间的内部通信协议，以及服务端提供给前端的REST API。

---

## 一、客户端-服务端 WebSocket 协议

### 1.1 连接握手

**端点**: `ws://server:port/ws`

**请求头**:
```
UUID: <客户端UUID的16进制编码>
Key: <AES加密后的UUID，使用Salt加密>
```

**握手流程**:
1. 客户端发送UUID和加密后的Key
2. 服务端验证 `Decrypt(Key, Salt) == UUID`
3. 验证通过后，服务端生成32字节随机Secret
4. 服务端在响应头中返回 `Secret: <16进制编码>`
5. 后续所有通信使用此Secret进行AES-CTR加密

### 1.2 数据包结构

#### JSON数据包

```json
{
    "code": 0,              // 响应码，0表示成功
    "act": "ACTION_NAME",   // 动作类型
    "msg": "message",       // 消息内容
    "data": {},             // 数据载荷
    "event": "uuid"         // 事件ID，用于异步回调
}
```

#### 二进制数据包

```
+--------+--------+--------+--------+--------+--------+--------+--------+
|  Magic Number (4 bytes)  | Svc(1) | Op(1)  |   Reserved (2)   |
+--------+--------+--------+--------+--------+--------+--------+--------+
|                        Event ID (16 bytes)                            |
+--------+--------+--------+--------+--------+--------+--------+--------+
|                          Payload (n bytes)                            |
+--------+--------+--------+--------+--------+--------+--------+--------+

Magic Number: 0x22161311
Svc (Service): 20 = 文件服务, 21 = 终端服务
Op (Operation): 操作码
```

### 1.3 客户端上线流程

```
Client                                  Server
   |                                       |
   |  -------- WebSocket握手 ---------->   |
   |                                       |
   |  <-------- Secret ----------          |
   |                                       |
   |  ---- DEVICE_UP (设备信息) ---->      |
   |                                       |
   |  <-------- Code: 0 ----------         |
   |                                       |
   |  <======= 双向通信建立 =======>        |
```

---

## 二、客户端动作命令

### 2.1 系统控制命令

| 动作 | 说明 | 请求数据 | 响应数据 |
|------|------|----------|----------|
| `PING` | 心跳检测 | - | `code: 0` |
| `OFFLINE` | 客户端下线 | - | `code: 0` |
| `LOCK` | 锁定屏幕 | - | `code: 0/1, msg` |
| `LOGOFF` | 注销登录 | - | `code: 0/1, msg` |
| `HIBERNATE` | 系统休眠 | - | `code: 0/1, msg` |
| `SUSPEND` | 系统睡眠 | - | `code: 0/1, msg` |
| `RESTART` | 重启系统 | - | `code: 0/1, msg` |
| `SHUTDOWN` | 关闭系统 | - | `code: 0/1, msg` |

### 2.2 设备信息命令

#### DEVICE_UP - 设备上线

请求:
```json
{
    "act": "DEVICE_UP",
    "data": {
        "id": "设备唯一ID",
        "os": "windows/linux/darwin",
        "arch": "amd64/arm64/arm/386",
        "lan": "192.168.1.100",
        "mac": "AA:BB:CC:DD:EE:FF",
        "cpu": {
            "model": "Intel Core i7-9700K",
            "usage": 25.5,
            "cores": {"logical": 8, "physical": 8}
        },
        "ram": {"total": 17179869184, "used": 8589934592, "usage": 50.0},
        "disk": {"total": 500000000000, "used": 250000000000, "usage": 50.0},
        "net": {"sent": 1024, "recv": 2048},
        "uptime": 86400,
        "hostname": "DESKTOP-XXX",
        "username": "admin",
        "remark": "备注信息"
    }
}
```

#### DEVICE_UPDATE - 设备状态更新

请求:
```json
{
    "act": "DEVICE_UPDATE",
    "data": {
        "cpu": {"usage": 30.5},
        "ram": {"total": 17179869184, "used": 9000000000, "usage": 52.3},
        "disk": {"total": 500000000000, "used": 251000000000, "usage": 50.2},
        "net": {"sent": 2048, "recv": 4096},
        "uptime": 86500
    }
}
```

### 2.3 截图命令

#### SCREENSHOT

请求:
```json
{
    "act": "SCREENSHOT",
    "data": {
        "bridge": "桥接ID，用于上传截图"
    },
    "event": "事件ID"
}
```

### 2.4 终端命令

#### TERMINAL_INIT - 初始化终端

请求:
```json
{
    "act": "TERMINAL_INIT",
    "data": {
        "cols": 80,
        "rows": 24
    },
    "event": "终端会话ID"
}
```

响应:
```json
{
    "act": "TERMINAL_INIT",
    "code": 0,
    "event": "终端会话ID"
}
```

#### TERMINAL_INPUT - 终端输入

请求:
```json
{
    "act": "TERMINAL_INPUT",
    "data": {
        "input": "ls -la\n"
    },
    "event": "终端会话ID"
}
```

#### TERMINAL_RESIZE - 调整终端大小

请求:
```json
{
    "act": "TERMINAL_RESIZE",
    "data": {
        "cols": 120,
        "rows": 40
    },
    "event": "终端会话ID"
}
```

#### TERMINAL_KILL - 关闭终端

请求:
```json
{
    "act": "TERMINAL_KILL",
    "event": "终端会话ID"
}
```

### 2.5 文件操作命令

#### FILES_LIST - 列出文件

请求:
```json
{
    "act": "FILES_LIST",
    "data": {
        "path": "/home/user"
    },
    "event": "事件ID"
}
```

响应:
```json
{
    "code": 0,
    "data": {
        "files": [
            {
                "name": "documents",
                "size": 4096,
                "mod": 1640000000,
                "dir": true
            },
            {
                "name": "test.txt",
                "size": 1024,
                "mod": 1640000000,
                "dir": false
            }
        ]
    },
    "event": "事件ID"
}
```

#### FILES_FETCH - 下载文件

请求:
```json
{
    "act": "FILES_FETCH",
    "data": {
        "path": "/home/user",
        "file": "test.txt",
        "bridge": "桥接ID"
    },
    "event": "事件ID"
}
```

#### FILES_REMOVE - 删除文件

请求:
```json
{
    "act": "FILES_REMOVE",
    "data": {
        "files": ["/home/user/test.txt", "/home/user/temp"]
    },
    "event": "事件ID"
}
```

#### FILES_UPLOAD - 上传文件

请求:
```json
{
    "act": "FILES_UPLOAD",
    "data": {
        "files": ["/home/user/uploaded.txt"],
        "bridge": "桥接ID",
        "start": 0,
        "end": 0
    },
    "event": "事件ID"
}
```

### 2.6 进程操作命令

#### PROCESSES_LIST - 列出进程

请求:
```json
{
    "act": "PROCESSES_LIST",
    "event": "事件ID"
}
```

响应:
```json
{
    "code": 0,
    "data": {
        "processes": [
            {
                "pid": 1234,
                "ppid": 1,
                "name": "chrome",
                "user": "admin",
                "cpu": 5.5,
                "mem": 1024000000
            }
        ]
    },
    "event": "事件ID"
}
```

#### PROCESS_KILL - 杀死进程

请求:
```json
{
    "act": "PROCESS_KILL",
    "data": {
        "pid": 1234
    },
    "event": "事件ID"
}
```

### 2.7 远程桌面命令

#### DESKTOP_INIT - 初始化桌面

请求:
```json
{
    "act": "DESKTOP_INIT",
    "event": "桌面会话ID"
}
```

#### DESKTOP_SHOT - 获取桌面帧

请求:
```json
{
    "act": "DESKTOP_SHOT",
    "event": "桌面会话ID"
}
```

#### DESKTOP_KILL - 关闭桌面会话

请求:
```json
{
    "act": "DESKTOP_KILL",
    "event": "桌面会话ID"
}
```

### 2.8 命令执行

#### COMMAND_EXEC

请求:
```json
{
    "act": "COMMAND_EXEC",
    "data": {
        "cmd": "notepad.exe",
        "args": "C:\\test.txt"
    },
    "event": "事件ID"
}
```

响应:
```json
{
    "code": 0,
    "data": {
        "pid": 5678
    },
    "event": "事件ID"
}
```

---

## 三、HTTP REST API

### 3.1 设备管理

#### 获取设备列表

```
POST /api/device/list
```

响应:
```json
{
    "code": 0,
    "data": {
        "connection-uuid-1": {
            "id": "device-id",
            "hostname": "DESKTOP-XXX",
            "os": "windows",
            ...
        }
    }
}
```

#### 设备控制

```
POST /api/device/{action}
```

支持的action: `lock`, `logoff`, `hibernate`, `suspend`, `restart`, `shutdown`, `offline`

请求参数:
```json
{
    "device": "设备ID",
    // 或
    "uuid": "连接UUID"
}
```

#### 执行命令

```
POST /api/device/exec
```

请求:
```json
{
    "device": "设备ID",
    "cmd": "命令",
    "args": "参数"
}
```

### 3.2 文件操作

#### 列出文件

```
POST /api/device/file/list
```

请求:
```json
{
    "device": "设备ID",
    "path": "/home/user"
}
```

#### 下载文件

```
POST /api/device/file/get
```

请求:
```json
{
    "device": "设备ID",
    "files": ["/home/user/test.txt"]
}
```

响应: 文件二进制流

#### 上传文件

```
POST /api/device/file/upload
```

请求: `multipart/form-data`
- `device`: 设备ID
- `path`: 目标路径
- `file`: 文件内容

#### 删除文件

```
POST /api/device/file/remove
```

请求:
```json
{
    "device": "设备ID",
    "files": ["/home/user/test.txt"]
}
```

#### 获取文本文件

```
POST /api/device/file/text
```

请求:
```json
{
    "device": "设备ID",
    "file": "/home/user/config.txt"
}
```

### 3.3 进程管理

#### 获取进程列表

```
POST /api/device/process/list
```

请求:
```json
{
    "device": "设备ID"
}
```

#### 杀死进程

```
POST /api/device/process/kill
```

请求:
```json
{
    "device": "设备ID",
    "pid": 1234
}
```

### 3.4 截图

```
POST /api/device/screenshot/get
```

请求:
```json
{
    "device": "设备ID"
}
```

响应: 图片二进制流 (`image/png`)

### 3.5 终端WebSocket

```
WebSocket /api/device/terminal?device={设备ID}
```

消息格式与客户端终端命令一致。

### 3.6 桌面WebSocket

```
WebSocket /api/device/desktop?device={设备ID}
```

消息格式与客户端桌面命令一致。

### 3.7 客户端生成

#### 检查预编译客户端

```
POST /api/client/check
```

请求:
```json
{
    "os": "windows",
    "arch": "amd64"
}
```

#### 生成客户端

```
POST /api/client/generate
```

请求:
```json
{
    "os": "windows",
    "arch": "amd64",
    "host": "192.168.1.1:8000",
    "path": "/ws",
    "remark": "客户端备注"
}
```

响应: 可执行文件二进制流

### 3.8 数据桥接

用于客户端与服务端之间传输大文件。

#### 推送数据

```
POST /api/bridge/push?id={bridge_id}
```

请求体: 二进制数据

#### 拉取数据

```
GET /api/bridge/pull?id={bridge_id}
```

响应: 二进制数据流

---

## 四、错误码说明

| Code | 含义 |
|------|------|
| 0 | 成功 |
| 1 | 一般错误 |
| -1 | 参数错误 |

## 五、国际化消息

消息格式: `${i18n|KEY}`

示例:
- `${i18n|COMMON.INVALID_PARAMETER}` - 无效参数
- `${i18n|COMMON.DEVICE_NOT_EXIST}` - 设备不存在
- `${i18n|COMMON.RESPONSE_TIMEOUT}` - 响应超时
- `${i18n|EXPLORER.FILE_OR_DIR_NOT_EXIST}` - 文件或目录不存在

---

*文档版本: 1.0*

