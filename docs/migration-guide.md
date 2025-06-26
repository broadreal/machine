# 脚本迁移指南

## 📋 旧脚本 → 新脚本映射

### vLLM 相关操作

| 旧脚本 | 新脚本 | 说明 |
|--------|--------|------|
| `./scripts/setup-vllm.sh` | `./scripts/vllm.sh setup` | 环境设置 |
| `./scripts/start-vllm.sh` | `./scripts/vllm.sh start` | 启动服务 |
| `./scripts/stop-vllm.sh` | `./scripts/vllm.sh stop` | 停止服务 |
| `./scripts/check-vllm.sh` | `./scripts/vllm.sh check` | 快速检查 |
| `./scripts/start-service.sh` | `./scripts/vllm.sh start` | 启动服务 |
| `./scripts/check-service.sh` | `./scripts/vllm.sh status` | 详细状态 |
| `./scripts/health-check.sh` | `./scripts/vllm.sh status` | 健康检查 |

### 环境安装操作

| 旧脚本 | 新脚本 | 说明 |
|--------|--------|------|
| `./scripts/install-modelscope.sh` | `./scripts/install-env.sh modelscope` | ModelScope安装 |
| `./scripts/configure-china-env.sh` | `./scripts/install-env.sh china` | 中国网络优化 |
| `./scripts/install-docker.sh` | `./scripts/install-env.sh docker` | Docker安装 |
| 全部环境安装 | `./scripts/install-env.sh all` | 一键安装所有环境 |

### 部署操作

| 旧脚本 | 新脚本 | 说明 |
|--------|--------|------|
| `./scripts/deploy-all.sh` | `./scripts/deploy.sh full` | 完整部署 |
| 快速部署 | `./scripts/deploy.sh quick` | 快速部署 |

### 保持不变

| 脚本 | 说明 |
|------|------|
| `./scripts/download-model.sh` | 模型下载（功能完整，保持独立） |

## 🔄 快速迁移命令

### 如果你之前使用：
```bash
# 旧方式
./scripts/setup-vllm.sh
./scripts/start-vllm.sh
./scripts/check-vllm.sh
```

### 现在使用：
```bash
# 新方式
./scripts/vllm.sh setup
./scripts/vllm.sh start
./scripts/vllm.sh check
```

## ⚡ 常用命令对照

### 完整部署流程

#### 旧方式（多个步骤）：
```bash
./scripts/install-modelscope.sh
./scripts/configure-china-env.sh
./scripts/download-model.sh Qwen3-32B
./scripts/setup-vllm.sh
./scripts/start-vllm.sh
./scripts/check-vllm.sh
```

#### 新方式（一键部署）：
```bash
./scripts/deploy.sh full
```

### 日常维护

#### 旧方式：
```bash
./scripts/check-service.sh    # 检查状态
./scripts/stop-vllm.sh        # 停止服务
./scripts/start-vllm.sh       # 启动服务
./scripts/health-check.sh     # 健康检查
```

#### 新方式：
```bash
./scripts/vllm.sh status      # 详细状态
./scripts/vllm.sh stop        # 停止服务
./scripts/vllm.sh start       # 启动服务
./scripts/vllm.sh check       # 快速检查
```

## 🎯 推荐的新工作流程

### 1. 首次安装
```bash
# 一键完成所有安装
./scripts/deploy.sh full
```

### 2. 日常使用
```bash
# 检查状态
./scripts/vllm.sh status

# 启动服务
./scripts/vllm.sh start

# 停止服务
./scripts/vllm.sh stop
```

### 3. 环境维护
```bash
# 重新配置环境
./scripts/vllm.sh setup

# 重新配置网络（中国用户）
./scripts/install-env.sh china
```

### 4. 模型管理
```bash
# 下载新模型
./scripts/download-model.sh Qwen2-7B

# 重新设置vLLM（如果更换了模型）
./scripts/vllm.sh setup
```

## 📝 注意事项

1. **备份文件**：旧脚本已移动到 `scripts/backup/` 目录，不会丢失
2. **权限设置**：新脚本已设置执行权限
3. **兼容性**：新脚本保持了所有原有功能
4. **增强特性**：新脚本增加了更好的错误处理和日志记录

## 🚫 已废弃的脚本

以下脚本已移动到 `scripts/backup/` 目录，不建议继续使用：
- `check-service.sh`
- `start-service.sh`
- `health-check.sh`

如需使用，请改用对应的新脚本命令。
