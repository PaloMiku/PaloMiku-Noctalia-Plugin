# 私有插件仓库工作流说明

此目录中的工作流已调整为适合个人私有仓库维护：

- 不再依赖 `pull_request_target`。
- 不再自动给 PR 评论或指派作者审查。
- 以“直接校验失败”方式阻断问题变更。

## 工作流列表

### 1) `check-first-plugin-correct-files.yml`

用途：校验插件目录基础结构。

触发：

- `pull_request`（涉及 `manifest.json` / `README.md` / `*.qml`）
- `push` 到 `main`

主要检查：

- 每个插件目录必须存在 `README.md`
- 若未创建 `i18n` 目录仅给出警告

### 2) `check-manifest.yml`

用途：校验所有插件 `manifest.json` 的完整性与一致性。

触发：

- `pull_request`（`manifest.json` 或 `schema.json` 变化）
- `push` 到 `main`

主要检查：

- 必填字段是否存在（依据 `schema.json.required`）
- `manifest.id` 是否与插件目录名一致
- `entryPoints` 是否至少包含一个入口
- `entryPoints` 指向的文件是否真实存在

### 3) `code-quality.yml`

用途：做轻量 QML 静态健全性检查。

触发：

- `pull_request`（`*.qml` 变化）
- `push` 到 `main`

主要检查：

- 是否存在冲突标记（`<<<<<<<` / `=======` / `>>>>>>>`）
- 是否包含 `import QtQuick`
- 是否出现 CRLF 行尾

### 4) `check-registry.yml`

用途：确保 `registry.json` 与当前插件元数据一致。

触发：

- `pull_request`（`manifest.json`、`registry.json` 或更新脚本变化）
- `push` 到 `main`

流程：

1. 运行 `update-registry.mjs` 重建注册表
2. 检查 `registry.json` 是否产生未提交差异
3. 如有差异则失败并提示先本地生成

### 5) `update-registry.yml`

用途：在主分支自动更新并提交 `registry.json`。

触发：

- `push` 到 `main`（`manifest.json` 或更新脚本变化）
- `workflow_dispatch`

说明：

- 使用 `GITHUB_TOKEN` 自动提交 `registry.json`
- 已移除对特定公开仓库名的限制，私有仓库可直接使用

## 本地手动更新注册表

```bash
node .github/workflows/update-registry.mjs
```

建议在提交前执行一次，避免 `check-registry` 失败。
