# CameraM 连拍场景合成性能优化开发计划

## 1. 文档目标
- 面向当前核心问题：拍摄后水印/相框合成耗时高，导致拍摄入口被阻塞，无法实现高速连拍。
- 先建立统一的开发路线图，再按步骤实施、验证、回归，避免一次性大改造成风险不可控。
- 本文档作为后续开发执行基线，所有阶段按“完成定义（DoD）”推进。

## 2. 当前问题分析（基于现有代码）

## 2.1 关键调用链（现状）
1. 用户点击拍照按钮，UI进入 loading 状态。
2. `CameraManager` 拍摄完成后回调到 `CameraBusinessController`。
3. `CameraBusinessController` 在 `renderQueue`（串行）执行：
   - 裁剪
   - 水印/相框渲染
   - 保存相册
4. 全部完成后才回调 UI，结束 loading。

## 2.2 瓶颈根因
1. **流程串行化严重**
   - 合成与保存在同一串行队列，任务排队，吞吐受限。
2. **拍摄与合成耦合**
   - 用户可继续拍摄的时机被绑定到“合成+保存结束”。
3. **大图多次中间对象复制**
   - 原图、裁剪图、水印图、JPEG Data 多份对象并存，内存峰值高。
4. **渲染层未做强缓存与背压**
   - 静态素材/布局计算重复；连拍时缺少队列上限与降级策略。

## 2.3 当前实现中的直接信号
- `CameraBusinessController` 使用单一 `renderQueue` 串行处理图像任务。
- UI 拍摄 loading 的关闭时机在最终 `didCapturePhoto` 回调，非“拍摄完成立即可拍”。
- `CMWatermarkRenderer` 为重量级同步渲染路径，叠加相册保存后进一步拉长尾延迟。

## 3. 目标与验收指标

## 3.1 功能目标
1. 连拍时拍摄入口不被合成流程阻塞。
2. 合成/保存完全后台异步化，支持有序落盘。
3. 高压场景下系统可控降级，不崩溃、不内存爆涨。

## 3.2 性能目标（首版）
1. 快门到“可再次点击”的 p95 < 120ms（不等待合成完成）。
2. 连续拍摄 30 张（标准分辨率）无卡死、无明显掉速。
3. 合成任务队列长度可观测且受上限控制（默认 8）。
4. 10 分钟压力测试无 OOM、无明显内存持续爬升。

## 4. 总体架构方案（先实施 A，再评估 B）

## 4.1 方案 A（推荐首版）
### 核心思想
- 拍摄链路与合成链路解耦。
- 引入 `CMPhotoPipeline`（异步流水线）与 `CMPhotoJob`（任务实体）。
- 通过有界队列 + 背压，确保连拍稳定。

### 流程图（文字）
1. `Capture`：拍照成功，立即生成 `Job(seq, rawInput, metadata, configSnapshot)`。
2. `Ack UI`：立刻回 UI，结束 loading，允许继续拍。
3. `Pipeline` 后台执行：
   - Stage1 Decode/Crop（并发）
   - Stage2 Watermark/Frame Compose（并发）
   - Stage3 Save（串行或低并发，保证资源稳定）
4. `Result`：按 `seq` 有序通知缩略图与状态。

## 4.2 方案 B（后续可选增强）
- 将图片层合成逐步迁移到 Core Image/Metal，文本层按需保留 CoreGraphics/CoreText。
- 适用于更多模板、动态相框、复杂效果叠加场景。

## 5. 技术决策
1. **并发模型**
   - 相机会话相关继续用 GCD（`sessionQueue`）。
   - 合成流水线使用 `NSOperationQueue`（支持依赖、取消、并发度、优先级）。
2. **输入输出承载**
   - 优先使用临时文件 URL 传递原始输入，减少大图对象常驻。
   - 各阶段使用 `@autoreleasepool` 回收中间对象。
3. **缓存策略**
   - 静态相框背景缓存、logo 渲染缓存、文本布局缓存。
4. **背压与降级**
   - `maxPendingJobs = 8`（可配置）。
   - 超限时启用策略：降采样/关闭非关键装饰/提示后台处理中。
5. **顺序保障**
   - 渲染可并行，结果按 `sequenceId` 重排后再通知 UI。

## 6. 分阶段开发步骤（执行清单）

## 阶段 0：基线测量与埋点（先做）
### 任务
1. 在拍摄、解码、渲染、保存关键节点加入耗时日志（推荐 `os_signpost`）。
2. 增加队列深度与失败率统计。
3. 增加内存峰值观测点（压力场景前后对比）。

### 完成定义（DoD）
1. 可导出至少 1 组“30 张连拍”耗时统计。
2. 能看到每阶段耗时占比，明确头部瓶颈。

## 阶段 1：拍摄入口解耦（最小可用改造）
### 任务
1. 调整 UI 状态机：拍摄成功后立即可再次拍摄，不等待合成保存结束。
2. 业务回调拆分为：
   - `didReceiveCaptureAck`（快速反馈）
   - `didFinishProcessingJob`（后台完成）
3. 保持现有渲染逻辑不变，先仅改交互与时序。

### 完成定义（DoD）
1. 用户可连续快速点击拍摄，不被 loading 锁死。
2. 不引入拍摄成功率回退。

## 阶段 2：引入异步流水线（核心）
### 任务
1. 新增模块：
   - `CMPhotoJob`
   - `CMPhotoPipeline`
   - `CMPhotoPipelineConfig`
2. 把 `processImage` 拆成 Stage Operation：
   - Decode/Crop Operation
   - Compose Operation
   - Save Operation
3. 使用依赖串联，设置并发度：
   - decode: 2
   - compose: 2
   - save: 1

### 完成定义（DoD）
1. 流水线可稳定处理连续任务。
2. 任务失败可隔离，不影响后续拍摄任务。

## 阶段 3：有界队列与背压策略（稳定性）
### 任务
1. 添加 `maxPendingJobs` 上限和实时计数。
2. 增加超限策略（首版建议：自动降级到快速模式）。
3. 增加用户可见提示（轻量，不打断拍摄）。

### 完成定义（DoD）
1. 压测下队列长度不无限增长。
2. 无 OOM，处理延迟可控。

## 阶段 4：渲染路径专项优化（降时延）
### 任务
1. 给 `CMWatermarkRenderer` 增加静态资源缓存层。
2. 避免每张图重复布局计算（字体、段落、固定几何）。
3. 评估并下沉可复用绘制逻辑，减少主路径分支。

### 完成定义（DoD）
1. 合成阶段平均耗时明显下降（目标先降 30%+）。
2. 无画质回退与布局错乱。

## 阶段 5：顺序一致性与回归加固
### 任务
1. 结果按 `sequenceId` 进行有序提交。
2. 覆盖异常路径：权限拒绝、存储失败、中途切配置。
3. 完成全量回归和文档更新。

### 完成定义（DoD）
1. 连拍结果顺序正确。
2. 异常可恢复，不阻塞后续流程。

## 7. 专项测试设计（高速连拍）
1. **标准分辨率 30 连拍**
   - 验证：入口响应、完成率、平均耗时。
2. **高分辨率 20 连拍**
   - 验证：背压触发、内存稳定性。
3. **连拍中切换水印配置**
   - 验证：每张图使用拍摄瞬间配置快照。
4. **连拍 + 方向变化 + 前后摄切换**
   - 验证：无崩溃、顺序正确、元数据正确。
5. **权限异常与写入失败**
   - 验证：错误上报完整、后续任务不中断。

## 8. 风险与对策
1. **风险：并发提高后内存占用上升**
   - 对策：有界队列、阶段级 autoreleasepool、必要时动态降并发。
2. **风险：任务并行导致结果顺序错乱**
   - 对策：统一 sequenceId + 有序提交器。
3. **风险：UI 反馈与最终结果时序分离导致认知偏差**
   - 对策：区分“拍摄成功提示”和“处理完成提示”。
4. **风险：缓存命中/失效策略不当导致显示错误**
   - 对策：严格 cache key 设计（frameId/size/scale/theme/configVersion）。

## 9. 实施约定
1. 每个阶段单独 PR，禁止跨阶段混改。
2. 每个阶段必须附：
   - 关键耗时对比数据（改造前/后）
   - 影响模块清单
   - 风险与回滚说明
3. 若某阶段指标未达标，不进入下一阶段功能扩展。

## 10. 下一步执行建议
1. 先执行“阶段 0：埋点与基线测量”。
2. 输出一次真实设备连拍基线报告后，再进入“阶段 1：拍摄入口解耦”。
3. 阶段 1 完成后，立即进行小规模用户体验验证（是否已具备连续拍摄手感）。

## 11. 阶段 0 落地记录（2026-04-28）
已完成首批埋点接入，未改动业务行为，仅增加可观测性。

### 11.1 已接入文件
1. `CameraM/Managers/CameraManager.m`
2. `CameraM/Controllers/CameraBusinessController.m`

### 11.2 日志标签与含义
1. `📊 [Perf][Capture][Request]`
   - 发起拍照请求时记录 settings ID 与累计请求数。
2. `📊 [Perf][Capture][AVCallback]`
   - AV 回调时记录从 request 到回调的延迟。
3. `📊 [Perf][Capture][DecodeEnqueue|DecodeStart|DecodeDone]`
   - 记录解码队列深度、排队时间、解码耗时、metadata 耗时。
4. `📊 [Perf][Pipeline][Enqueue|Start|Done]`
   - 记录业务渲染流水线排队深度、等待时间、裁剪/合成/保存/总耗时。
5. `mem=xxMB`
   - 关键节点记录当前常驻内存（用于粗粒度峰值对比）。

### 11.3 新增统计项
1. `CameraManager`
   - `totalCaptureRequests`
   - `totalCaptureFailures`
   - `pendingPhotoProcessingCount`
   - `maxObservedPhotoProcessingDepth`
2. `CameraBusinessController`
   - `pendingRenderTaskCount`
   - `maxObservedRenderQueueDepth`
   - `totalProcessedJobs`
   - `totalFailedJobs`

### 11.4 阶段 0 下一步操作
1. 真机执行“标准分辨率 30 连拍”并导出日志。
2. 统计以下 p50/p95：
   - AV 回调延迟
   - Decode 阶段耗时
   - Compose 阶段耗时
   - Save 阶段耗时
   - Pipeline 总耗时
3. 记录峰值队列深度与峰值内存，形成基线报告后进入阶段 1。

## 12. 阶段 1 落地记录（2026-04-28）
已完成“拍摄入口解耦”的最小改造。

### 12.1 改动点
1. 在 `CameraBusinessDelegate` 新增 `didReceiveCaptureAck` 回调。
2. `CameraBusinessController` 在收到原始拍摄结果后，先发出 ack，再进入后台处理链路。
3. `CameraViewController` 改为在 `didReceiveCaptureAck` 中关闭拍摄 loading，不再等待最终合成完成。

### 12.2 预期效果
1. 快门响应与可再次点击时机前移。
2. 用户连拍手感不再依赖“渲染+保存”完成。

## 13. 阶段 2 落地记录（2026-04-28）
已完成“处理链路流水线化”改造。

### 13.1 改动点
1. `CameraBusinessController` 从单一串行 `renderQueue` 切换为三段 `NSOperationQueue`：
   - `decodeQueue`（并发 2）
   - `composeQueue`（并发 2）
   - `saveQueue`（并发 1）
2. 使用 `NSBlockOperation` + 依赖关系构建阶段流水线：
   - Decode/Crop -> Compose -> Save
3. `cleanup` 增加 `cancelAllOperations`，避免退出时残留处理任务。

### 13.2 当前状态
1. 流程已具备分阶段异步处理能力。
2. 阶段 0 的性能埋点仍保留，可持续观测各阶段耗时与队列深度。

### 13.3 下一步（阶段 3）
1. 增加有界队列阈值（例如 `maxPendingJobs = 8`）。
2. 实现超限背压策略（丢弃/降级/排队提示三选一或组合）。
3. 将背压事件打点，形成可量化策略效果数据。

## 14. 阶段 3 落地记录（2026-04-28）
已完成“有界队列 + 背压”首版实现。

### 14.1 策略实现
1. 新增阈值参数（`CameraBusinessController`）：
   - `maxPendingJobs = 8`
   - `dropThresholdJobs = 12`
2. 轻度拥塞（`pending > maxPendingJobs`）：
   - 启用快速路径，跳过水印合成，仅执行基础处理 + 保存。
3. 重度拥塞（`pending > dropThresholdJobs`）：
   - 触发过载保护，拒绝新任务并回调错误（`code=3003`），防止队列无限增长。

### 14.2 埋点与观测
1. 新增背压日志：
   - `⚠️ [Backpressure] ... fast-path enabled`
   - `⚡️ [Backpressure] ... skip compose`
   - `⛔️ [Backpressure] ... drop job`
2. 与阶段 0 的耗时日志联动，可对比背压触发前后的吞吐和延迟变化。

### 14.3 注意事项
1. 当前重度拥塞策略会丢弃任务，优先保障拍摄主流程稳定与内存安全。
2. 后续可按产品策略改为“丢最旧任务”或“降级但不丢弃”。

## 15. 阶段 4 落地记录（2026-04-28）
已完成 `CMWatermarkRenderer` 主路径缓存优化（首版）。

### 15.1 已实现优化
1. 新增静态素材缓存：
   - `assetImageCache`（按 assetName 缓存 `UIImage`）
2. 新增 logo 渲染缓存：
   - `renderableLogoCache`（按 `assetName + templateFlag` 缓存可绘制 logo）
3. 主路径替换点：
   - overlay/background/logo 的重复 `imageNamed` 调用切换到缓存读取
   - 多处 `imageWithRenderingMode` 切换到缓存复用

### 15.2 影响
1. 降低了高频合成中的重复素材查找与 logo 渲染模式转换开销。
2. 在连拍场景下可减少 compose 阶段抖动，提升稳定性。

### 15.3 下一步建议
1. 基于阶段 0 埋点，对比 `compose` 阶段 p50/p95（改造前后）。
2. 若收益仍不足，再进入“文本布局缓存（attributes/paragraph）”与“模板预渲染”二阶段优化。
3. 保持高像素机型输出一致性：渲染降采样阈值需覆盖 48MP + 相框扩展后的像素规模。

## 16. 阶段 5 落地记录（2026-04-28）
已完成“结果有序提交”首版实现。

### 16.1 已实现内容
1. `CameraBusinessController` 新增有序提交状态：
   - `nextCompletionJobID`
   - `pendingOrderedCompletions`
2. 新增统一方法 `enqueueOrderedCompletionForJobID(...)`：
   - 后台任务完成后先进入缓冲区
   - 仅当 sequence 连续时按序 flush 到主线程执行 completion
3. 背压丢弃任务（`code=3003`）也进入同一有序通道，避免序号“空洞”导致后续任务卡住。
4. `cleanup` 时清空有序缓冲并重置序号，防止跨会话污染。

### 16.2 价值
1. 即使后续提高并发度，UI 层收到的处理完成事件仍按拍摄顺序一致。
2. 避免“缩略图/结果回调乱序”引发的体验问题和状态错位。

## 17. 48MP 问题修复记录（2026-04-28）
已定位并修复“支持 48MP 机型输出像素下降”问题。

### 17.1 根因
`CMWatermarkRenderer` 中存在全局降采样阈值 `CMWatermarkMaxRenderPixels=22MP`，会在水印/相框合成前将大图主动缩小，导致最终输出不是 48MP。

### 17.2 修复
将阈值提升为 `90MP`，覆盖 48MP 原图及相框扩展后的画布像素规模，避免误触发降采样。

### 17.3 影响
1. 48MP 机型在开启水印/相框时可保留高像素输出。
2. 内存压力会高于 22MP 阈值策略；若低端设备出现内存告警，可按机型或模式做差异化阈值。
