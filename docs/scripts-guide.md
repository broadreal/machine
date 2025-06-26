# vLLM 脚本管理指南

## 📁 精简后的脚本结构

### 🎯 核心脚本（4个）

#### 1. `vllm.sh` - vLLM统一管理脚本
**功能**: 集成vLLM的所有操作
```bash
./scripts/vllm.sh [命令]

命令:
  setup    - 设置vLLM环境并修复问题
  start    - 启动vLLM服务  
  stop     - 停止vLLM服务
  check    - 检查vLLM服务状态
  status   - 显示详细状态信息
  help     - 显示帮助信息
```

**替代的旧脚本**:
- ✅ setup-vllm.sh
- ✅ start-vllm.sh  
- ✅ check-vllm.sh
- ✅ stop-vllm.sh
- ✅ start-service.sh
- ✅ check-service.sh
- ✅ health-check.sh

#### 2. `install-env.sh` - 环境安装脚本
**功能**: 统一管理环境安装
```bash
./scripts/install-env.sh [命令]

命令:
  modelscope  - 安装ModelScope和Python环境
  china       - 配置中国大陆网络优化
  docker      - 安装Docker环境
  all         - 安装所有环境
  help        - 显示帮助信息
```

**替代的旧脚本**:
- ✅ install-modelscope.sh
- ✅ configure-china-env.sh
- ✅ install-docker.sh

#### 3. `download-model.sh` - 模型下载脚本
**功能**: 下载AI模型（保持独立）
```bash
./scripts/download-model.sh [模型名]

示例:
  ./scripts/download-model.sh Qwen3-32B
  ./scripts/download-model.sh Qwen2-7B
```

**说明**: 功能完整且使用频率高，保持独立

#### 4. `deploy.sh` - 一键部署脚本
**功能**: 自动化部署流程
```bash
./scripts/deploy.sh [模式]

模式:
  full    - 完整部署（环境+模型+服务）
  quick   - 快速部署（假设环境已就绪）
  help    - 显示帮助信息
```

**替代的旧脚本**:
- ✅ deploy-all.sh

### 📦 备份的脚本

已移动到 `scripts/backup/` 目录:
- check-service.sh
- start-service.sh  
- health-check.sh

## 🚀 使用流程

### 首次安装（推荐）
```bash
# 1. 完整部署（一键完成所有步骤）
./scripts/deploy.sh full

# 或者分步执行：
# 2a. 安装环境
./scripts/install-env.sh all

# 2b. 下载模型  
./scripts/download-model.sh Qwen3-32B

# 2c. 设置并启动vLLM
./scripts/vllm.sh setup
./scripts/vllm.sh start
```

### 日常使用
```bash
# 检查服务状态
./scripts/vllm.sh status

# 启动/停止服务
./scripts/vllm.sh start
./scripts/vllm.sh stop

# 快速检查
./scripts/vllm.sh check
```

### 环境维护
```bash
# 重新设置环境
./scripts/vllm.sh setup

# 更新环境配置
./scripts/install-env.sh china  # 重新配置网络优化
```

## 📊 精简效果对比

### 精简前（12个脚本）
```
scripts/
├── check-service.sh        } 
├── check-vllm.sh          }  功能重复
├── health-check.sh        }
├── start-service.sh       }
├── start-vllm.sh          }  功能重复
├── setup-vllm.sh          }
├── stop-vllm.sh           }
├── install-modelscope.sh  }
├── configure-china-env.sh }  可合并
├── install-docker.sh      }
├── download-model.sh      ── 保留
└── deploy-all.sh          ── 简化
```

### 精简后（4个脚本）
```
scripts/
├── vllm.sh           ── 统一vLLM管理
├── install-env.sh    ── 统一环境安装
├── download-model.sh ── 模型下载
├── deploy.sh         ── 一键部署
└── backup/           ── 备份目录
    ├── check-service.sh
    ├── start-service.sh
    └── health-check.sh
```

## ✅ 改进优势

### 1. 简化维护
- **脚本数量**: 12个 → 4个 (减少67%)
- **功能整合**: 避免重复代码
- **统一接口**: 一致的命令行参数

### 2. 用户友好
- **命令简化**: `./vllm.sh start` vs `./start-vllm.sh`
- **功能集中**: 一个脚本多种用法
- **帮助完善**: 每个脚本都有详细帮助

### 3. 功能增强
- **错误处理**: 更好的错误检测和修复
- **日志管理**: 统一的日志记录
- **交互式**: 用户友好的交互选项

### 4. 扩展性
- **模块化**: 各脚本职责清晰
- **可扩展**: 容易添加新功能
- **配置化**: 统一的配置管理

## 🔧 故障排除

### 常见问题
1. **权限问题**: 确保脚本有执行权限
   ```bash
   chmod +x scripts/*.sh
   ```

2. **路径问题**: 在项目根目录运行脚本
   ```bash
   cd /home/user/machine
   ./scripts/vllm.sh status
   ```

3. **环境问题**: 重新设置环境
   ```bash
   ./scripts/vllm.sh setup
   ```

### 日志位置
- 管理日志: `/home/user/machine/logs/vllm.log`
- 服务日志: `/home/user/machine/logs/vllm-service.log`
- 安装日志: `/home/user/machine/logs/install-env.log`
- 部署日志: `/home/user/machine/logs/deploy.log`

## 📞 技术支持

如果遇到问题：
1. 查看日志文件中的错误信息
2. 运行 `./scripts/vllm.sh status` 获取详细状态
3. 检查是否有torch-npu等依赖冲突
4. 确认模型文件完整性
