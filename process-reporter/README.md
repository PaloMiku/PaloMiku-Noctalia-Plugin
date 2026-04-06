# Process Reporter

Process Reporter 是一个 Noctalia 插件，用于实时获取当前用户正在聚焦的窗口信息，并监听媒体播放状态后合并上报到同一个云函数。

## 功能概览

- 顶栏小组件：悬浮提示显示当前窗口标题。
- 面板详情：展示窗口信息、媒体信息、上传状态与最近更新时间。
- 事件驱动上报：窗口焦点变化时可立即触发合并上报。
- 媒体事件监听：监听 MediaService 的播放状态与曲目变化并触发合并上报。
- 可选定时心跳：启用后按固定间隔触发窗口与媒体刷新。
- Token 鉴权：上报时通过 Bearer Token 进行认证，避免被滥上传。

## 隐私与上报边界

窗口标题默认不上传；媒体上报默认关闭；未配置 token 时不会发起请求。

窗口字段：

- windowId
- appId
- appName
- windowTitle（仅在 uploadWindowTitle=true 时）

媒体字段（uploadMediaEnabled=true 且有活跃媒体时）：

- playerIdentity
- trackTitle
- trackArtist
- trackAlbum
- trackArtUrl
- isPlaying

## 上传触发策略

- 窗口事件触发：检测到聚焦窗口变化。
- 媒体事件触发：检测到播放状态变化或曲目变化。
- 定时触发：当启用定时上报后，按固定间隔刷新并尝试上报。

插件启用 uploadThrottleMs 节流与快照去重，避免短时间重复上传。

## 配置项说明

- uploadEnabled：是否启用上传路径。
- uploadMediaEnabled：是否启用媒体监听与媒体上报。
- uploadWindowTitle：是否上报窗口标题。
- scheduledUploadEnabled：是否启用定时刷新与上报。
- scheduledUploadIntervalMs：定时触发间隔，最小 1000。
- uploadEndpoint：云函数接收地址。
- uploadToken：云函数 Bearer Token（必填，否则不上报）。
- uploadThrottleMs：上传节流窗口，最小 1000。

## 云函数接口契约

统一上报地址：`uploadEndpoint`

认证方式：Bearer Token（来自 `uploadToken`）

### 请求头

```http
Authorization: Bearer <uploadToken>
Content-Type: application/json
```

### 请求体示例（单云函数合并上报）

```json
{
  "timestamp": 1711929600000,
  "event": "window-event",
  "window": {
    "windowId": "0x03a00007",
    "appId": "org.kde.konsole",
    "appName": "konsole",
    "windowTitle": "Konsole"
  },
  "media": {
    "playerIdentity": "spotify",
    "trackTitle": "Bohemian Rhapsody",
    "trackArtist": "Queen",
    "trackAlbum": "A Night at the Opera",
    "trackArtUrl": "file:///path/to/art",
    "isPlaying": true
  }
}
```

字段说明：

- `timestamp`：毫秒时间戳。
- `event`：触发来源，常见值：`window-event`、`media-is-playing`、`media-track-title`、`scheduled`、`manual`。
- `window`：窗口快照；无可用窗口时可为 `null`。
- `media`：媒体快照；未启用媒体上报或无活跃媒体时为 `null`。

### 成功响应示例

建议云函数返回 2xx：

```json
{
  "ok": true,
  "requestId": "req_20260401_001",
  "receivedAt": 1711929600123
}
```

### 鉴权失败响应示例

建议返回 401：

```json
{
  "ok": false,
  "error": "invalid_token"
}
```

### 速率限制响应示例

建议返回 429：

```json
{
  "ok": false,
  "error": "rate_limited"
}
```

## 本地收发测试

以下步骤用于本地验证“插件侧上报格式”和“云函数侧接收解析”。

1. 启动本地接收端（监听 8787）：

```bash
node -e "const http=require('http');const s=http.createServer((req,res)=>{let b='';req.on('data',c=>b+=c);req.on('end',()=>{console.log('method:',req.method);console.log('url:',req.url);console.log('auth:',req.headers.authorization||'');console.log('body:',b);res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:true,receivedAt:Date.now()}));s.close();});});s.listen(8787,'127.0.0.1',()=>console.log('listening:8787'));"
```

2. 在插件设置中配置：

- `uploadEnabled=true`
- `uploadEndpoint=http://127.0.0.1:8787/report`
- `uploadToken=<你的测试 token>`
- 按需设置 `uploadMediaEnabled`

3. 触发一次上报（窗口切换/媒体状态变化，或执行 IPC）：

```bash
qs -c noctalia-shell ipc call plugin:<插件键> refreshNow
```

4. 若本地接收端输出包含 `Authorization: Bearer <token>` 和 JSON body，说明上报与接收链路正常。

## IPC 命令

```bash
qs -c noctalia-shell ipc call plugin:<插件键> refreshNow
```

## 国际化说明

- 当前仅保留简体中文语言包（zh-CN）。