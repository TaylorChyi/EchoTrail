EchoTrail（回声轨迹）——设计与实现说明（含“动态地形”扩展）

本文件用于工程根目录的 README.md。内容覆盖：核心玩法、输入方式、音频与美术规范、难度节奏、目录结构、构建运行步骤、测试清单，以及新增的“动态地形系统”，保证一局内地图持续变化而非固定，提升可玩性与重复游玩意愿。

⸻

1. 游戏定位与目标
	•	类型：小体量网格动作类收集游戏。
	•	平台：苹果 iOS 操作系统（iOS）与苹果 macOS 操作系统（macOS）。
	•	设计目标：上手三秒内理解规则，十秒内产生“再来一把”的冲动；玩法清晰、节奏紧凑、反馈明确；离线运行，冷启动快。

⸻

2. 画面与世界
	•	俯视二维网格，尺寸 7×13。
	•	角色与元素：玩家亮青色，回声蓝色，白球浅色，金球金色，障碍深色。
	•	运动带短拖尾与粒子；字体使用 Menlo 粗体（系统等宽备用）。

⸻

3. 核心规则（玩家视角）
	1.	目标：在网格内移动并拾取球体得分，尽量生存更久，避免与回声或障碍相撞。
	2.	球体：白球固定加 10 分；金球基础 30 分，受连锁倍数影响。
	3.	回声：每 3 秒生成一个回声，精确重演玩家 3 秒前的真实坐标路径；上限 8 个。
	4.	回声合鸣：两个及以上回声在同一格相遇时触发：
	•	以该格为中心，曼哈顿距离（Manhattan Distance（水平距离与垂直距离的和））小于等于 2 的白球升级为金球；
	•	立即加分 +50，连锁倍数 +0.5，持续 5 秒（上限 4.0）；
	•	参与相遇的回声移除。
	5.	失败条件：玩家与任一回声相撞；玩家与固定或动态障碍相撞；任一回声与障碍相撞。
	6.	难度：每 10 秒提升一次时钟速率（Tick（时钟刻）频率）直至 20 次每秒；动态障碍逐步最多 4 组。
	7.	补球：每 4 秒检查补白球，场上上限 7 个。
	8.	结算信息：总分、生存时间、峰值回声数。

⸻

4. 操作与输入
	•	键盘：方向键或 W/A/S/D（上、左、下、右）为连续移动；空格为“等待”。
	•	触摸（iOS）：按住出现虚拟摇杆，拖动控制方向；回中心为“等待”；松手隐藏。
	•	阻塞提示：被墙体或障碍阻塞有短促低频音与触觉反馈（iOS）。

⸻

5. 新增：动态地形系统（一局内地图持续变化）

目标：打破“开局随机但全局静态”的单调感，在可预见与可掌控前提下制造节奏变化与路线重规划。所有变化均遵守“公平三原则”：
	•	原则一：可预告。变更前有视觉闪烁与清晰音效提示。
	•	原则二：不夹杀。变更不会在玩家或回声当前所在格直接生成障碍。
	•	原则三：保留解。任何时刻至少存在一条可行解路径（避开封死格局）。

5.1 周期门格（Pulse Gates）
	•	行为：一组“门格”周期性在“开放”和“关闭”之间切换。关闭时视为障碍；开放时可通行。
	•	建议参数：
	•	GATE_RATIO = 0.08（约占网格的 8%），从非出生区域与非当前动态障碍处抽样；
	•	GATE_PERIOD_TICKS = 24（2.4 秒，按 TICK_BASE=10 计算）；
	•	GATE_WARN_TICKS = 6（0.6 秒预告闪烁）；
	•	首次出现时间：开局 ≥ 12 秒。
	•	交互：
	•	门格不会在切换瞬间覆盖玩家或回声所处格；若切换目标与其重叠，延迟到下一周期。
	•	回声路径受门格影响，可用于“卡位”制造合鸣机会。
	•	视听提示：
	•	预告闪烁边框；切换音效建议使用 Audio/SFX/sfx_gate_toggle.wav，预告使用 sfx_gate_warn.wav。
	•	数据结构与更新：
	•	Set<IntPoint> gateCells；Bool gateOpen；
	•	tick() 中维护 gateTimer，当 gateTimer == GATE_PERIOD_TICKS - GATE_WARN_TICKS 进入预告；到期切换 gateOpen 并应用到通行判定 passable()。

5.2 行列平移（Row/Column Slide）
	•	行为：随机选择一行或一列，按固定方向逐 Tick平移一个格，持续 SLIDE_STEPS 次；行内元素随之移动（障碍、球体都会移动），越界采用回卷（Wrap）。
	•	建议参数：
	•	SLIDE_START_TIME = 20 秒；
	•	SLIDE_STEPS = 4；SLIDE_INTERVAL_TICKS = 5；
	•	行或列的选择概率各 50%；方向随机（左/右 或 上/下）。
	•	约束：
	•	不选择包含玩家当前格的行列；若选择到则换一个候选。
	•	平移过程若将球体推入障碍，优先移除障碍（让路），保证“保留解”。
	•	视听提示：
	•	被选中行/列加亮条背景；平移瞬间播放 Audio/SFX/sfx_row_slide.wav。
	•	实现要点：
	•	新增 struct SlideEvent { enum Axis { row, col }; var index:Int; var dir:Int; var stepsLeft:Int; var nextTick:Int }；
	•	tick() 到 nextTick 时触发一次平移：更新 obstStatic、balls 的键，动态障碍只在其当前占用点内平移一格；更新渲染插值起点终点以保证平滑。

5.3 衰减砖块（Decay Walls）
	•	行为：一部分固定障碍带有耐久（Durability（耐久）），受“挤压”或“靠近”会损耗，直至破裂消失。
	•	耐久与触发：
	•	初始耐久 2；当玩家相邻四方向或玩家撞上该障碍时耐久 -1；回声相邻不计减（避免过强）。
	•	破裂后该格有 50% 概率生成白球。
	•	视听提示：
	•	耐久减少：Audio/SFX/sfx_decay_crack.wav；破裂：Audio/SFX/sfx_decay_break.wav。
	•	实现要点：
	•	Dictionary<IntPoint, Int> decayHP；在 tryMove() 阻塞分支与 tick() 的邻域扫描中调用 damageDecayWall(at:)。
	•	渲染层为衰减格叠加裂纹强度（简单用 alpha 近似）。

5.4 Echo 安全轨迹（Echo Safe Trail，增强互动）
	•	行为：所有回声过去 SAFE_TICKS = 8 Tick 经过的格视为“安全轨迹”，门格不会在这些格关闭，行列平移不会将这些格推出地图，衰减砖块在这些格不会被创建。
	•	目的：让玩家“利用回声”规划更大胆的路线与合鸣引导。
	•	实现要点：
	•	Deque<[IntPoint]> echoRecentTrail，每 Tick 追加本 Tick 全体回声的格坐标；维护长度 SAFE_TICKS；合并为 Set<IntPoint> echoSafe 参与各子系统的判定。

5.5 动态地形触发节奏与叠加规则
	•	时间轴（默认，单位 Tick，TICK_BASE=10）：
	•	t=120：首次启用“周期门格”；
	•	t=200：首次触发“一次行列平移事件”（持续多步）；
	•	t=260：启用“衰减砖块”；
	•	之后每 ~12–18 秒按权重在三者中择一触发一次；极端情况下不允许连续两次触发同类事件。
	•	叠加规则：
	•	行列平移优先级最高；正在平移的行列不参与“周期门格”的切换与“衰减砖块”的生成；
	•	Echo 安全轨迹最高优先，覆盖上述三系统。

⸻

6. 音频设计（文件驱动）
	•	背景音乐（放置于 EchoTrail Shared/Audio/Music/）：
	•	bg_menu_loop.caf：未开始与暂停，动感、欢快、轻松；
	•	bg_game_loop.caf：对局中，动感、紧张。
	•	事件音效（放置于 EchoTrail Shared/Audio/SFX/）：
	•	sfx_eat_white.wav、sfx_eat_gold.wav、sfx_echo_spawn.wav、sfx_echo_fuse.wav、sfx_bump_wall.wav、sfx_game_over.wav。
	•	动态地形新增建议音效（可选，缺失不会报错，本项目代码使用“存在即播”的策略）：
	•	sfx_gate_warn.wav、sfx_gate_toggle.wav（周期门格预告与切换）
	•	sfx_row_slide.wav（行列平移）
	•	sfx_decay_crack.wav、sfx_decay_break.wav（衰减砖块减耐久与破裂）

文件格式建议：背景音乐 .caf 44.1 kHz 无缝循环；短音效 .wav 单声道，头部不留静音。

⸻

7. 数值与默认参数

项目	默认值	说明
网格	7×13	GRID_W、GRID_H
初始 Tick 频率	10/s	TICK_BASE
回声间隔	30 Tick	ECHO_DELAY
回声上限	8	ECHO_LIMIT
球体补充间隔	40 Tick	BALL_INTERVAL
球体上限	7	BALL_CAP
难度提升周期	100 Tick	SPEED_STEP
动障周期	5 Tick	KINETIC_PERIOD
合鸣加分	+50	固定值
倍数增量与时长	+0.5，5 秒	上限 4.0
周期门格比例与周期	8%，24 Tick	GATE_RATIO、GATE_PERIOD_TICKS
周期门格预告	6 Tick	GATE_WARN_TICKS
行列平移步数与间隔	4 步、5 Tick	SLIDE_STEPS、SLIDE_INTERVAL_TICKS
衰减砖块耐久	2	DECAY_HP
Echo 安全轨迹	8 Tick	SAFE_TICKS


⸻

8. 代码落点（实现指引）

下列均在 GameScene.swift 内完成，命名可直接采用：
	•	数据结构新增
	•	gateCells: Set<IntPoint>、gateOpen: Bool、gateTimer: Int
	•	currentSlide: SlideEvent?（见 5.2 结构定义）
	•	decayHP: [IntPoint: Int]
	•	echoRecentTrail: [[IntPoint]]、echoSafe: Set<IntPoint>
	•	关键改动点
	1.	passable(_:)：当 gateOpen == false 且坐标在 gateCells 内且不在 echoSafe 内，则不可通行。
	2.	tick()：
	•	推进 gateTimer，处理预告与切换；
	•	推进 currentSlide，到步则平移一次对应行/列；
	•	在玩家撞墙的阻塞分支中对 decayHP 扣耐久；
	•	每 Tick 记录 echoRecentTrail 并生成 echoSafe。
	3.	事件触发器：在既定时间点或冷却到期后调用 spawnGatesIfNeeded()、startRowColSlideIfReady()、enableDecayWallsIfReady()。
	4.	视听：在各事件预告或生效位置调用 playSFXIfAvailable("...") 并对对应节点增加闪烁或高亮。

⸻

9. 工程结构
	•	EchoTrail Shared
	•	GameScene.swift（含动态地形逻辑）
	•	IntPoint.swift
	•	GameAudio.swift（背景音乐交叉淡入淡出）
	•	Audio/Music/*.caf、Audio/SFX/*.wav
	•	EchoTrail iOS
	•	AppDelegate.swift（音频会话与常亮）
	•	GameViewController.swift（呈现场景）
	•	EchoTrail macOS
	•	AppDelegate.swift、GameViewController.swift

⸻

10. 构建与运行
	1.	在 Xcode 中确认所有音频文件位于 Copy Bundle Resources，并勾选 iOS 与 macOS 目标。
	2.	选择目标平台运行：未开始与暂停播放 bg_menu_loop.caf，开始对局交叉切换至 bg_game_loop.caf。
	3.	所有新增动态地形音效文件可选；未放置不会导致报错。

⸻

11. 测试清单（新增动态地形相关）
	•	周期门格：有清晰预告与切换音；切换不在玩家与回声当前格发生；关门后变为障碍，开门后可通行。
	•	行列平移：高亮行/列；元素随行/列移动；无夹杀；平移音效正常播放。
	•	衰减砖块：被玩家相邻或撞击后减耐久，有裂纹反馈与音效；破裂后概率生成白球。
	•	Echo 安全轨迹：安全格不会被门格关闭，不会被衰减砖块生成，不会被行列平移推出地图；回声路径可用于“开路”。
	•	与原有系统兼容：回声生成、合鸣、动态障碍与补球正常；结算信息准确；性能稳定。

⸻

12. 后续可选项（按投入由低到高）
	1.	门格布局权重表：靠近中心权重更高，提升决策密度。
	2.	平移事件模式：双行对称平移或“交错平移”。
	3.	主题皮肤与色盲友好模式：替换色相与亮度，不改数值。
	4.	排行榜与成就（Game Center）：提交分数与里程碑。
	5.	回放导出与分享：记录 Tick 级路径，体积极小。

⸻

13. 版权与依赖
	•	不依赖第三方框架与在线服务。
	•	所有音频需持有可商业分发授权。

⸻

附：音频文件清单（含动态地形新增，缺失可不放）

EchoTrail Shared/Audio/Music/
  bg_menu_loop.caf
  bg_game_loop.caf

EchoTrail Shared/Audio/SFX/
  sfx_eat_white.wav
  sfx_eat_gold.wav
  sfx_echo_spawn.wav
  sfx_echo_fuse.wav
  sfx_bump_wall.wav
  sfx_game_over.wav
  sfx_gate_warn.wav          // 可选：周期门格预告
  sfx_gate_toggle.wav        // 可选：周期门格切换
  sfx_row_slide.wav          // 可选：行列平移
  sfx_decay_crack.wav        // 可选：衰减砖块减少耐久
  sfx_decay_break.wav        // 可选：衰减砖块破裂

以上方案保证：地图在同一局中持续但可预见地变化；回声系统与地形变化互相耦合，形成“规划—执行—回放—合鸣—再规划”的闭环节奏；难度随时间自然提升，但始终保留可行路径与清晰的风险—收益选择。