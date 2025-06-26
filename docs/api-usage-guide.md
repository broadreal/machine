# API使用指南

## 概述

本文档介绍如何使用部署的Qwen3-32B AI服务API。服务提供OpenAI兼容的API接口，可以轻松集成到现有应用中。

## 基本信息

- **服务地址**: http://localhost:8000
- **API版本**: v1
- **兼容性**: OpenAI API格式

## API端点

### 1. 健康检查
```bash
GET /health
```

示例：
```bash
curl http://localhost:8000/health
```

### 2. 模型列表
```bash
GET /v1/models
```

示例：
```bash
curl http://localhost:8000/v1/models
```

### 3. 聊天完成
```bash
POST /v1/chat/completions
```

## 使用示例

### cURL 示例

#### 基础对话
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-32B",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下自己"}
    ],
    "max_tokens": 150,
    "temperature": 0.7
  }'
```

#### 多轮对话
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-32B",
    "messages": [
      {"role": "system", "content": "你是一个专业的AI助手"},
      {"role": "user", "content": "什么是机器学习？"},
      {"role": "assistant", "content": "机器学习是人工智能的一个分支..."},
      {"role": "user", "content": "能给我举个具体例子吗？"}
    ],
    "max_tokens": 200,
    "temperature": 0.8
  }'
```

#### 流式响应
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-32B",
    "messages": [
      {"role": "user", "content": "写一首关于春天的诗"}
    ],
    "max_tokens": 200,
    "temperature": 0.9,
    "stream": true
  }'
```

### Python 示例

#### 使用 requests 库
```python
import requests
import json

def chat_with_qwen(message, history=None):
    url = "http://localhost:8000/v1/chat/completions"
    
    messages = []
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": message})
    
    data = {
        "model": "Qwen3-32B",
        "messages": messages,
        "max_tokens": 150,
        "temperature": 0.7,
        "top_p": 0.8
    }
    
    response = requests.post(url, json=data)
    
    if response.status_code == 200:
        result = response.json()
        return result["choices"][0]["message"]["content"]
    else:
        return f"错误: {response.status_code} - {response.text}"

# 使用示例
response = chat_with_qwen("解释一下量子计算的基本原理")
print(response)
```

#### 使用 OpenAI 库
```python
from openai import OpenAI

# 初始化客户端
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="dummy-key"  # vLLM不需要真实的API key
)

def chat_completion(messages):
    response = client.chat.completions.create(
        model="Qwen3-32B",
        messages=messages,
        max_tokens=150,
        temperature=0.7
    )
    return response.choices[0].message.content

# 使用示例
messages = [
    {"role": "system", "content": "你是一个helpful的AI助手"},
    {"role": "user", "content": "帮我写一个Python排序算法"}
]

result = chat_completion(messages)
print(result)
```

#### 流式对话示例
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="dummy-key"
)

def stream_chat(message):
    stream = client.chat.completions.create(
        model="Qwen3-32B",
        messages=[{"role": "user", "content": message}],
        max_tokens=200,
        temperature=0.8,
        stream=True
    )
    
    for chunk in stream:
        if chunk.choices[0].delta.content is not None:
            print(chunk.choices[0].delta.content, end="")
    print()  # 换行

# 使用示例
stream_chat("请详细介绍一下深度学习的发展历程")
```

### JavaScript 示例

#### 基础请求
```javascript
async function chatWithQwen(message) {
    const response = await fetch('http://localhost:8000/v1/chat/completions', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            model: 'Qwen3-32B',
            messages: [
                { role: 'user', content: message }
            ],
            max_tokens: 150,
            temperature: 0.7
        })
    });
    
    const data = await response.json();
    return data.choices[0].message.content;
}

// 使用示例
chatWithQwen('什么是区块链技术？').then(response => {
    console.log(response);
});
```

#### 使用 axios 库
```javascript
const axios = require('axios');

async function chatCompletion(messages) {
    try {
        const response = await axios.post('http://localhost:8000/v1/chat/completions', {
            model: 'Qwen3-32B',
            messages: messages,
            max_tokens: 200,
            temperature: 0.8
        });
        
        return response.data.choices[0].message.content;
    } catch (error) {
        console.error('Error:', error.response?.data || error.message);
        return null;
    }
}

// 使用示例
const messages = [
    { role: 'system', content: '你是一个专业的编程助手' },
    { role: 'user', content: '帮我写一个JavaScript的快速排序算法' }
];

chatCompletion(messages).then(response => {
    if (response) {
        console.log(response);
    }
});
```

## 参数说明

### 请求参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| model | string | 是 | - | 模型名称，使用 "Qwen3-32B" |
| messages | array | 是 | - | 对话历史，包含role和content |
| max_tokens | integer | 否 | 16 | 最大生成token数量 |
| temperature | float | 否 | 1.0 | 控制生成随机性 (0.0-2.0) |
| top_p | float | 否 | 1.0 | 核采样参数 (0.0-1.0) |
| stream | boolean | 否 | false | 是否使用流式响应 |
| stop | array | 否 | null | 停止词列表 |

### 消息格式

```json
{
  "role": "user|assistant|system",
  "content": "消息内容"
}
```

- **system**: 系统提示，设定AI的行为和角色
- **user**: 用户输入的消息
- **assistant**: AI助手的回复

## 性能优化建议

### 1. 合理设置参数

```python
# 快速响应（较短回复）
data = {
    "max_tokens": 50,
    "temperature": 0.3,
    "top_p": 0.8
}

# 创意生成（较长回复）
data = {
    "max_tokens": 500,
    "temperature": 0.9,
    "top_p": 0.95
}

# 代码生成（精确性优先）
data = {
    "max_tokens": 200,
    "temperature": 0.1,
    "top_p": 0.5
}
```

### 2. 批处理请求

对于多个独立请求，可以考虑批处理：

```python
import asyncio
import aiohttp

async def batch_chat(messages_list):
    async with aiohttp.ClientSession() as session:
        tasks = []
        for messages in messages_list:
            task = asyncio.create_task(
                send_request(session, messages)
            )
            tasks.append(task)
        
        results = await asyncio.gather(*tasks)
        return results

async def send_request(session, messages):
    async with session.post(
        'http://localhost:8000/v1/chat/completions',
        json={
            "model": "Qwen3-32B",
            "messages": messages,
            "max_tokens": 100
        }
    ) as response:
        data = await response.json()
        return data["choices"][0]["message"]["content"]
```

## 错误处理

### 常见错误码

- **400**: 请求参数错误
- **422**: 请求格式错误
- **500**: 服务器内部错误
- **503**: 服务不可用

### 错误处理示例

```python
import requests
import time

def robust_chat(message, max_retries=3):
    for attempt in range(max_retries):
        try:
            response = requests.post(
                'http://localhost:8000/v1/chat/completions',
                json={
                    "model": "Qwen3-32B",
                    "messages": [{"role": "user", "content": message}],
                    "max_tokens": 150
                },
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()["choices"][0]["message"]["content"]
            elif response.status_code == 503:
                # 服务暂时不可用，重试
                time.sleep(2 ** attempt)
                continue
            else:
                return f"错误 {response.status_code}: {response.text}"
                
        except requests.exceptions.Timeout:
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
                continue
            return "请求超时"
        except requests.exceptions.ConnectionError:
            return "连接错误，请检查服务是否运行"
    
    return "多次重试后仍然失败"
```

## 监控和日志

### 查看服务日志

```bash
# 查看实时日志
docker-compose -f /home/user/machine/docker/docker-compose.yml logs -f

# 查看最近的错误
docker-compose -f /home/user/machine/docker/docker-compose.yml logs | grep -i error

# 查看性能指标
./scripts/check-service.sh
```

### 性能监控

可以使用以下脚本监控API性能：

```python
import time
import requests
import threading
from statistics import mean

def performance_test(duration=60):
    results = []
    start_time = time.time()
    
    def worker():
        while time.time() - start_time < duration:
            request_start = time.time()
            try:
                response = requests.post(
                    'http://localhost:8000/v1/chat/completions',
                    json={
                        "model": "Qwen3-32B",
                        "messages": [{"role": "user", "content": "Hello"}],
                        "max_tokens": 10
                    },
                    timeout=30
                )
                request_time = time.time() - request_start
                if response.status_code == 200:
                    results.append(request_time)
            except:
                pass
    
    threads = [threading.Thread(target=worker) for _ in range(5)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    
    if results:
        print(f"平均响应时间: {mean(results):.2f}s")
        print(f"总请求数: {len(results)}")
        print(f"QPS: {len(results)/duration:.2f}")

# 运行性能测试
performance_test()
```

## 安全注意事项

1. **网络安全**: 在生产环境中，建议配置防火墙和反向代理
2. **访问控制**: 考虑添加API密钥认证
3. **资源限制**: 设置合理的请求频率限制
4. **数据隐私**: 不要发送敏感信息到AI模型

## 故障排除

### 常见问题

1. **连接被拒绝**
   ```bash
   # 检查服务状态
   ./scripts/check-service.sh
   
   # 重启服务
   docker-compose -f /home/user/machine/docker/docker-compose.yml restart
   ```

2. **响应缓慢**
   ```bash
   # 检查GPU/CPU使用情况
   nvidia-smi  # GPU
   htop        # CPU和内存
   ```

3. **内存不足**
   ```bash
   # 降低并发数或减少max_tokens参数
   # 考虑使用模型量化版本
   ```

有关更多信息，请参考项目文档或联系技术支持。
