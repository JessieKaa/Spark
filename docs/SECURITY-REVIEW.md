# Security Review — Spark 仓库安全审查报告

## Vuln 1: Path Traversal — 任意文件读取 `server/handler/generate/generate.go:87`

* **Severity:** HIGH
* **Category:** `path_traversal`
* **Confidence:** 9/10

**Description:** `GenerateClient` 端点将用户提交的 `os` 和 `arch` 参数直接拼接到文件路径中（`fmt.Sprintf(config.BuiltPath, form.OS, form.Arch)`），没有任何校验或清理。攻击者可以通过路径遍历序列读取服务器上的任意文件，且文件内容会被完整地流式返回到 HTTP 响应中。

**Exploit Scenario:** 已认证的攻击者发送 POST 请求到 `/client/generate`：

```json
{"os": "../../etc", "arch": "passwd", "host": "x", "port": 1, "path": "x"}
```

路径解析为 `./built/../../etc_passwd` → `/etc_passwd`。通过调整 `../` 层数，可以读取服务器文件系统上的任意文件（如 `/etc/shadow`、配置文件、密钥文件等），内容以 `application/octet-stream` 下载形式返回。`CheckClient`（utility.go:158）中存在相同模式。

**Recommendation:** 对 `form.OS` 和 `form.Arch` 做白名单校验（仅允许 `windows`/`linux`/`darwin` 和 `amd64`/`arm64`/`386`/`arm`），或使用 `filepath.Clean()` 后检查路径是否仍在 `./built/` 目录内。

---

## Vuln 2: 远程终端输入明文记录 `server/handler/terminal/terminal.go:211-214`

* **Severity:** MEDIUM
* **Category:** `data_exposure`
* **Confidence:** 8/10

**Description:** 远程终端会话的所有键盘输入（`TERMINAL_INPUT`）被完整记录到日志中，包括原始字节内容。管理员在远程终端中输入的密码、API Key、SSH 密钥等敏感信息会被明文写入日志文件。

```go
common.Info(terminal.session, `TERMINAL_INPUT`, ``, ``, map[string]any{
    `deviceConn`: terminal.deviceConn,
    `input`:      utils.BytesToString(rawInput),
})
```

**Exploit Scenario:** 任何对 Spark 服务器日志目录有读权限的攻击者（如通过路径遍历漏洞读取日志、日志收集系统泄露、或服务器被入侵后取证），可以提取所有远程终端会话中输入的密码和凭据。

**Recommendation:** 移除日志中的 `input` 字段，或仅记录输入长度/哈希值，不记录原始内容。

---

## 排除的发现（经验证为误报或加固建议）

| 发现 | 排除原因 |
|------|----------|
| Bridge 端点无认证 | UUID 为 128 位随机值，不可猜测，单次使用，60秒过期 — 等同于能力令牌模式 |
| 服务端可无认证启动 | 有意的设计，文档明确标注 auth 为可选 |
| AES-CTR nonce 来自 MD5 | 64 字节随机填充使 nonce 实际上不可预测 |
| XSS via ReactMarkdown | ReactMarkdown 默认安全，未使用 dangerouslySetInnerHTML |
| XOR 加密用于终端/桌面 | 是 AES + TLS 之上的次要混淆层 |
| 客户端任意命令执行/文件操作 | RAT 核心功能，非漏洞 |
| 明文密码存储选项 | 加固建议，非具体漏洞 |
| X-Forwarded-For 信任 | 加固建议，无实际攻击路径 |
| Session Cookie 缺少 Secure/SameSite | 加固建议 |
| Salt 填充 / MD5 完整性 / 同一 Salt 加密所有客户端 | 加固建议，无实际可利用路径 |
