# QuVideo

面向长视频内容理解的 Video Agent：把长视频转成可检索、可追溯、可继续追问的结构化知识。

## 技术栈

| 层次 | 技术 | 用途 |
| :--- | :--- | :--- |
| Web | Vue 3、Vite、SSE、Marked | 上传、Agent 工作台与实时进度 |
| API | Java 21、Spring Boot、Undertow、MyBatis-Plus | 鉴权、媒体管理、任务编排 |
| 异步与缓存 | RocketMQ、Redis、Redisson | 异步削峰、状态缓存、限流与锁 |
| 数据与存储 | MySQL、MinIO、Qdrant | 业务数据、视频对象、Checkpoint 与向量检索 |
| 视频与 AI | FFmpeg、Tesseract、LangChain4j | 音视频处理、多模态解析、Agent 推理 |

## 本地运行

准备本地配置并启动中间件：

```bash
cp .env.example .env
./scripts/dev-up.sh
```

启动后端：

```bash
set -a; source .env; set +a
cd server && ./mvnw spring-boot:run
```

启动前端：

```bash
set -a; source .env; set +a
cd client && npm ci && npm run dev
```

后端默认 `http://localhost:9090`，前端默认 `http://localhost:15173`。

## License

本项目基于 [MIT License](LICENSE) 开源。