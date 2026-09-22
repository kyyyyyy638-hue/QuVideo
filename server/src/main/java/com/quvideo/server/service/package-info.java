/**
 * 业务核心层：媒体接入、任务事件与失败任务台账。
 *
 * <p>与具体分析流程相关的编排与处理逻辑按职责下沉到子包：
 * <ul>
 *   <li>{@link com.quvideo.server.service.agent} —— Agent 编排与运行态：
 *       {@code AiService}(应用入口)、{@code AgentLoopService}(Planner→Executor→Critic
 *       受控循环)、{@code AnalysisDispatchService}(提交 / 限流 / 幂等)、
 *       {@code AnalysisStatusService}(状态聚合)、{@code AgentCheckpointService}、
 *       {@code AgentTelemetry}、{@code AgentExecutionBudget}。</li>
 *   <li>{@link com.quvideo.server.service.retrieval} —— 分块、向量召回与证据校验：
 *       {@code VideoChunkingService}、{@code QdrantVectorStore}、
 *       {@code VideoEvidenceRetrievalService}、{@code EvidenceVerificationService}。</li>
 *   <li>{@link com.quvideo.server.service.videocontext} —— 时序多模态上下文：
 *       {@code VideoContextService}(抽帧去重与合并)、转写三件套、{@code AudioExportService}、
 *       {@code LongVideoContextService}。</li>
 *   <li>{@link com.quvideo.server.service.mode} —— 多模式定义与注册。</li>
 * </ul>
 *
 * <p>本包只保留与具体分析流程无关的基础能力：媒体元数据与入库、媒体文件读写、分片上传、
 * 阶段事件通道、失败任务台账与账号鉴权。
 */
package com.quvideo.server.service;
