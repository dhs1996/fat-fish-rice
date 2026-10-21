# 大肥鱼接米饭

大肥鱼（本 agent 的虚拟形象：**蓝色大肥鱼 / DeepSeek娘**，举着锅的 chibi 鱼娘）站在桌子上，
用锅接住天上掉下来的**饭团**。
街机式接物玩法：**接饭团加分、断连击掉倍率、被石头砸掉心、吃到辣椒操作反转**。

**形象出处**：「蓝色大肥鱼」是中文社区对 DeepSeek 蓝鲸 logo 的爱称，萌拟人形象叫
DeepSeek娘 / 鲸鱼娘（Whale-chan）——蓝色渐变长发、鲸类头鳍、鲸尾、蓝白女仆裙，
人设里就是「白米饭和 token 通吃」。做这本游戏时查过的参考：
[桌宠仓库（有 Q 版图集）](https://github.com/boyl/deepseek-blue-whale)、
[表情包合集](https://github.com/the-beating-light-of-the-nail/deepseek-chan-meme-pack)、
[萌娘百科 DeepSeek娘](https://mobile.moegirl.org.cn/DeepSeek%E5%A8%98)。
两个仓库都是 **no license**，只当参考看，游戏里的素材全部是本机 SD 重新生成的。

| 项 | 值 |
| --- | --- |
| 引擎 | Godot **4.7.2**（`config/features` 写死 `4.7`，低版本会被 `tools/verify.ps1` 拦下） |
| 语言 | GDScript（带类型，不用 Variant 兜底） |
| 渲染器 | `gl_compatibility` |
| 分辨率 | 1280×720，`canvas_items` + `keep` |
| 主场景 | `main.tscn`（根 `game/entry.gd`） |

## 玩法规则

| 掉落物 | 接住的结果 |
| --- | --- |
| 白饭团 | +1 × 倍率，连击 +1 |
| 金饭团（稀有） | +5 × 倍率，连击 +1 |
| 辣椒 | 连击清零，进入「辣到」3.5 秒：**左右操作反转** |
| 石头 | 连击清零，**心 −1**；心归零结算 |

- **倍率**：每 5 连击 +1，封顶 ×8。
- **漏接**：饭团掉到桌面只清连击，不掉心（技术门槛在「保持连击」，不在「怕漏」）。
- **波次**：每 20 秒一波，掉落更快更密、石头更多。
- **操作**：`←/→` 或 `A/D`；也可按住鼠标（触摸）拖动，锅跟着指针横向走。

数值全在 `data/rules/rice_rules.gd`，调平衡只改那一个文件。

## 目录

```
res://
  main.tscn / game/entry.gd        入口：打印启动信息 → 挂主菜单 → 跑命令行自检钩子
  core/                            框架层（只放机制，不出现业务词）
    save_sys.gd                    autoload SaveSys：只认 key + scope
    service_base.gd                状态 + 存档 + 自己的 signal
    event_bus.gd                   autoload EventBus：跨场景广播（本作暂时为空清单）
    ui_layer.gd                    autoload Ui：5 个 CanvasLayer，z 序是枚举
    panel_base.gd                  界面基类：遮罩 / 点空白关闭 / 幂等销毁 / 关闭回调
  data/rules/rice_rules.gd         玩法数值表（灰盒期形态：自己持有数据与默认值）
  services/
    save_scope_const.gd            存档分段（业务含义，住业务层）
    player/player_service.gd       autoload PlayerService：跨局永久数据（最高分/累计/局数）
  game/
    menu/main_menu.{gd,tscn}       主菜单，同时是一局的宿主
    battle/battle.{gd,tscn}        一局的表现层 + 流程（持有 RiceSim）
    battle/rice_sim.gd             **局内状态的唯一持有者**：纯逻辑，不认识 Node
    battle/fall_item.gd            单个掉落物的纯数据
    battle/fish_view.gd            主角（锅 + 米堆 + 火苗）的绘制
    battle/rice_view.gd            掉落物的绘制
    battle/scenery.gd              天空 / 云 / 桌面
    battle/hud.gd                  分数 / 连击 / 波次 / 心 / 辣到提示 / 受击红闪
    pop/game_over.{gd,tscn}        结算面板（extends PanelBase，挂 Ui.Layer.POP）
  assets/art/                      AI 生成的美术（见下）
  tools/
    check_all.gd                   全量脚本编译（在真实运行上下文里 load 每个 .gd）
    verify.ps1                     一条命令跑完四步验收（+ `-Shot` 截三张图）
    shotter.gd                     画面自检：截 菜单 / 对局 / 结算
    img_tools.gd                   美术后处理：按 alpha 边界裁切 + 等比缩放
```

## 四条设计约束（改动前先读）

1. **状态唯一。** 一局之内的分数 / 连击 / 心 / 掉落物**只在 `RiceSim` 里**；
   跨局的最高分 / 累计 / 局数**只在 `PlayerService` 里**。
   表现层（`battle.gd`）只读不写，改数值一律走它们的方法。不存在同一份数据两处各存一半。
2. **谁有状态谁 emit。** signal 声明在持有者身上并只在它内部 emit；别处只 connect。
   `battle.gd` 的 `_bind(on)` 用一个 `[signal, callable]` 表成对 connect/disconnect。
3. **仿真层不认识渲染。** `rice_sim.gd` / `fall_item.gd` 是 `RefCounted`，不碰 Node、
   不读时钟（dt 由表现层给）。这条边界让规则可以 headless 验证（见 `--demo`）。
4. **锅的判定与画面对齐。** 接饭判定线就是 `POT_RIM_DY`，锅口永远画正、不跟着身体旋转。
   让锅视觉倾斜而判定不倾斜，玩家会觉得"明明接住了却没接住"。

本作**没有**引入 ECS、TimePulse、配表管线：单场景接物游戏用不上，
框架按需加——加了的必须被下一次改动用上（见 skill `godot-core-framework` 的边界说明）。

## 美术：AI 立绘 + 程序化道具（分工是试出来的）

| 元素 | 做法 | 为什么 |
| --- | --- | --- |
| 角色立绘 `char.png` | **训练了角色 LoRA**（`bfywhale_v1`，23 张 canon Q 版图集，底模 anything-v5）→ 再用 `tmp/recolor_blue.js` 做一次蓝色加深 | 只有 LoRA 能让"同一个角色 + 指定姿势"稳定复现；纯提示词出不来 canon 的深蓝渐变发、鲸尾与鳍耳 |
| 锅 `pot_icon.png` | **独立 icon 素材**：不锈钢盆/锅（AI 生成，按参考图风格），不画在立绘里 | 锅是接饭判定的载体，必须能单独换样式、单独调锅口位置；画进立绘就只能整张重做。**锅口中心要落在 `pot_x` 上**，所以它单独有 `POT_OFFSET_X` 补偿 |
| 饭团 / 金饭团 / 石头 / 辣椒 | **程序化 `_draw`** | 画面上只有 40 多像素，AI 图的细节会糊；接物游戏最要紧的是"一眼分清这是什么"。饭团用圆角三角 + 海苔条，轮廓在这个尺寸依然清晰，也和石头/辣椒同一套 cel 描边 |
| 天空 / 云 / 桌面 | **程序化** | AI 试了两轮，出成室内场景或"画框里的天空"，构图不可用；程序化版本更干净，也不受分辨率限制 |
| 米堆 / 火苗 / 心 / HUD | **程序化** | 要跟着状态变（接得越多堆得越高），贴图做不到 |

生成与后处理脚本在**工作区 `tmp/`**（不进 `res://`，也不进导出包）：

```powershell
node D:\dev\godot\tmp\sd_gen.js D:\dev\godot\tmp\jobs2.json    # 调 /sdapi/v1/txt2img（WebUI 要带 --api 起）
node D:\dev\godot\tmp\montage.js out.png 4 240 340 *.png       # 候选拼成联系表，一次看完一批
node "D:\dev\egret\游戏开发\美术\图片素材\remove_color.js" --input <gen> --output <cut> --threshold 235
godot --headless --path <proj> --script res://tools/img_tools.gd -- --trim <cut> <final> <maxW> <maxH>
node D:\dev\godot\tmp\recolor_blue.js <in.png> <out.png> 1.35 0.80   # 蓝色区加深（只碰蓝色相、跳过极暗与极亮）
node D:\dev\godot\tmp\ref\zoom.js <shot.png> <out.png> <l> <t> <w> <h> 4   # 放大核对小物件的可读性
node D:\dev\godot\tmp\flood_bg.js <in.png> <out.png> 20                 # 四边颜色键洪泛去底（淡色/渐变背景用，remove_color 只能去近白）
node D:\dev\godot\tmp\keep_largest.js <in.png> <out.png>                # 只留最大连通块，清掉 AI 画的漂浮杂块
node D:\dev\godot\tmp\clear_rect.js <in.png> <out.png> x y w h          # 定点清矩形（杂块和身体连着时用；别压到头发）
```

- 现用的 `char.png` 就是训练期采样图 `bfywhale_v1_e000016_00_*.png`（在 `tmp/lora/output/sample/`），
  处理链：`flood_bg.js` 去淡色背景 → `keep_largest.js` 清杂点 → `img_tools.gd --trim`。
  它带白荷叶头巾 + 横向鱼鳍耳 + 鲸尾 + 双手上举，是目前最贴 canon 的一张。
- **`flood_bg.js` 的容差别给大**：这张背景是淡蓝渐变，容差 40 会把**白色荷叶头巾也啃掉**（白色和近白背景
  色距在阈值内，洪泛顺着抗锯齿边缘漏进去），实测 **20 正好**。去底后必须铺洋红底放大看一遍
  （`MONTAGE_BG=255,0,255` + `ref/zoom.js`），白衣服、白围裙最容易在这里被误删。

- `remove_color.js` 只删与四边连通的白色，图形内部的白色（围裙、荷叶边）不会被误删。
- `img_tools.gd` 负责「按 alpha 边界裁切 + 等比缩放」：每张图的边界都不一样，
  `cut.js` 的固定矩形切法会切掉头发或切进手指。
- 换素材后必须让引擎重新导入：`godot --headless --path <proj> --import`。
- 挑素材的结论记在这里，省得下次重跑：
  - 角色共试了 4 批 30 张（anything-v5 两批、QteaMix 一批、canon 关键词一批）。**只有 `char3_1`
    是整身 + 落脚 + 纯白底且去底干净**；QteaMix 的 canon 味道最足（2 头身、深蓝发、鲸鳍耳），
    但全是坐姿 + 深色底，不能当"站着举锅"的立绘；其余候选有的下半身被裁、有的带深色圆盘/彩块。
  - 锅候选 5 张全是俯视角，选 `pot_3`；后来又专门要过一次"深蓝铁锅"，全出成镜头/盘子，放弃。
  - 物品（碗装米饭 / 石头 / 辣椒）出过 3 批 20 多张：SD 反复加碗、加彩色底，且 40px 下没细节，
    最终全部改程序化。
  - 原始候选在 `tmp/gen/`，去底结果在 `tmp/cut_all/`、`tmp/cut_whale/`，联系表 `tmp/sheet_*.png`。

### 角色 LoRA（`bfywhale_v1`）

要让 SD 稳定画出**同一个**角色，只能训 LoRA，提示词做不到。这条链路的全部细节在 `tmp/lora/`：

```
tmp/lora/
  dataset/4_bfywhale/           23 张 512×512 + 23 份字幕（触发词 bfywhale）
  tokenizer/openai_clip-vit-large-patch14/   离线分词器（训练不联网）
  bfywhale.toml                 训练配置（dim32/alpha16，只训 UNET，batch1 + gradient_checkpointing）
  gen_lora2.json                用 LoRA 出图的规格（举手姿势 + EasyNegativeV2 负面）
  train_lora.ps1                一条命令跑完：查 CUDA → 卸坏 xformers → 训练 → 拷进 WebUI
  output/                       5 个快照（epoch 4/8/12/16/最终）+ sample/ 采样图
```

用本机 lora-scripts（`D:\ai\lora-scripts`，kohya sd-scripts）训练，约 40 分钟 / 1600 步。
**这五个坑都是实测撞出来的，换机重来会一模一样再撞一遍**：

1. 那个 venv 自带 `torch +cpu`（`cuda False`）→ 必须换 CUDA 版，否则在 CPU 上训。
2. 自带的 xformers 与新版 torch **ABI 不兼容**（`DLL load failed while importing _C_flashattention`）。
   `diffusers` 在 import 阶段就会去探它，所以**配置里写 `xformers = false` 不够，必须 `pip uninstall xformers`**；
   只影响这个 venv，WebUI 用自己 bundle 的 python。
3. 训练要下 CLIP 分词器，而 `requests/urllib3` 只信 certifi —— 本机 TLS 拦截证书不在里面，
   报 `SSL: CERTIFICATE_VERIFY_FAILED`（`urllib`/pip 走 Windows 证书库所以没事）。
   解法：`--tokenizer_cache_dir` 指向本地分词器 + `TRANSFORMERS_OFFLINE=1`，彻底不联网。
4. DreamBooth 模式下 kohya 只扫 `train_data_dir` 的**子目录**，且目录名必须是 `N_类名`（`4_bfywhale`）。
   图片平铺在根目录 → 子集为空 → `mean ar error: nan` / `Dataset loading failed`。
5. 出图时 LoRA 会把姿势拽回数据集里的站姿 → 用 `(both arms raised above head:1.5)` 加权 +
   LoRA 权重降到 0.6~0.65 + 负面挂 `arms down, hands on chest`，才拿到"双手举锅"。
   另外「palms up / lifting something overhead」这类词会把解剖画崩（倒置、裁头），别用。
6. 要鲸尾和鳍耳就得单独加权：`(large blue whale tail behind her:1.45)`、
   `(blue whale fin ears on the sides of her head:1.35)`，负面挂 `cat ears, animal ears, no tail`。
   **"鳍耳"不要写成 `flat fan shaped`——SD 会理解成手里拿折扇**；写 `light blue ear fins
   sticking out sideways` + `webbed ear fins with pale inner side`（鳍条、白膜），并把 LoRA
   权重降到 0.55，才拿到参照图里那种"横向外伸的鱼鳍"而不是深色尖猫耳。
7. AI 立绘常带漂浮杂块（小鲸鱼、漩涡、光点）。`tmp/keep_largest.js` 只保留最大连通块；
   若杂块和身体连着（实测只差 2px 就删不掉），用 `tmp/clear_rect.js` 定点清矩形——
   **注意矩形别压到头发/手臂**，清完必须重裁并看图确认。

### 换立绘时必须重新对齐的三处（不吃这个亏）

1. **`CHAR_HEIGHT`** — 立绘里"手"的高度决定它。手上举的图大概在顶部往下 5~14%，
   要让锅底落在手里：`FEET_Y - CHAR_HEIGHT + f*CHAR_HEIGHT = 锅底`（当前 230 / f≈0.14）。
   这只是为了"看起来是她在拿锅"，**不改变接饭判定**——判定始终是 `POT_RIM_DY`。
2. **`CHAR_OFFSET_X` / `POT_OFFSET_X`** — 两个素材各自的重心都不在图心：鲸尾让立绘左右不对称、
   锅的把手让锅心偏右。两个偏移要**同时**补，否则就是"人在左、锅在右"。
3. **`POT_RIM_DY`** — 锅口 = 接饭判定线，也是玩家眼睛盯的位置，改锅大小就要连它一起改；
   锅变高（比如从炒锅换成深盆）会让判定线上移，记得同步 `FALL_SPEED_BASE` 保住 ~1.8 秒的飞行时间。

前两条只是视觉微调，**第三条动的是玩法数值**，改完必须跑 `verify.ps1 -Shot` 看截图确认锅口仍在手上。

## 发布（导出 Windows 单文件 exe）

preset 在工程根 `export_presets.cfg`（`Windows Desktop`，x86_64，**pck 已嵌入 exe**，不修改 exe 资源）。

**一条命令（推荐）**：

```powershell
& .\tools\export_demo.ps1     # 杀残留进程 → 导出 → 跑导出包的 --demo → 截三张图
```

手工等价步骤：

```powershell
# 1) 先装导出模板（只需一次）：编辑器 Editor › 管理导出模板 › 下载并安装
#    受限环境里的做法：把官方 tpz 里的 windows_{debug,release}_x86_64.exe + version.txt
#    解到 %APPDATA%\Godot\export_templates\4.7.2.stable\
$env:APPDATA = 'D:\dev\godot\tmp\godot_userdata'
godot --headless --path D:\dev\godot\fat_fish_rice --export-release "Windows Desktop" D:/dev/godot/demo/FatFishRice.exe
# 2) 验收**导出产物**（不是工程）：退出码 + 自己截三张图
D:\dev\godot\demo\FatFishRice.exe --headless -- --demo
D:\dev\godot\demo\FatFishRice.exe -- --shot D:/dev/godot/tmp/demo_shots
```

**别在导出/验证期间用图像编辑器（SAI/PS）打开 `assets/art/*.png` 或 `demo/FatFishRice.exe`**：

- 占用 exe → 导出最后一步失败，报 `PCK 内嵌: 重命名临时文件 FatFishRice.tmp 失败`，
  **旧 exe 会留在原地**，后面的 `--demo` 静默测到上一版（这条踩过）；
- 占用 PNG → `--import` 可能静默复用旧缓存，画面不更新。

要手改素材就先把文件拷到 `tmp/work/` 改，改完再放回去；`export_demo.ps1` 已内置"先杀残留进程"。

实测数据：4.7.2 模板包 1.22 GB（下载 168 秒），`--export-release` 产出 **104.5 MB 单文件 exe**，
`-- --demo` 退出码 0，存档写到 `%APPDATA%\Godot\app_userdata\大肥鱼接米饭\saves\`。
导出时设置 `application/modify_resources=false`，否则会去找 rcedit 改 exe 资源。

## 验证

```powershell
& .\tools\verify.ps1          # import / 全量编译 / 启动冒烟 / 交互链路
& .\tools\verify.ps1 -Shot    # 再加一步：开窗口截 菜单 / 对局 / 结算 三张 PNG
```

判定规则（都是踩过的坑，别只看退出码）：

- `--import` 必须先跑，否则跨文件 `class_name` 解析不到，全量检查会假失败。
- `check_all` 的退出码不足以判定：`load()` 对解析失败的脚本仍返回非 null。
  **权威判定 = 扫日志**：出现 `SCRIPT ERROR` / `Parse Error` / `Could not find` /
  `Failed to load script` 即失败。
- 沙箱内必须把 `APPDATA` 指到可写目录，否则 Godot 建不了 `user://logs` 会直接崩溃（signal 11）。
- Windows PowerShell 5.1 下用 `*>` 重定向原生程序的输出会得到空日志、`$LASTEXITCODE` 也丢，
  所以 `verify.ps1` 里每次调用都写成 `.bat` + `> log 2>&1`，退出码取 cmd 的。
- `verify.ps1` 本身是**纯 ASCII**：PS 5.1 会把无 BOM 的 UTF-8 脚本按 ANSI 读，中文字面量必乱码。
- **中文别走 PowerShell 的读写往返**：`[System.IO.File]::ReadAllText/WriteAllText` 改完的游戏文件里
  `接` 会被写成 `住`（实测把主菜单标题改成过"大肥鱼住米饭"）。改含中文的文件一律用编辑器/edit，
  或者写完立刻读回来比对；`verify.ps1 -Shot` 的截图是最后一道人眼闸门。

手工等价命令（headless 冒烟）：

```powershell
$exe = 'C:\Users\win11\scoop\apps\godot1\4.7\godot.exe'
$env:APPDATA = 'D:\dev\godot\tmp\godot_userdata'
& $exe --headless --path D:\dev\godot\fat_fish_rice --import
& $exe --headless --path D:\dev\godot\fat_fish_rice --script res://tools/check_all.gd
& $exe --headless --path D:\dev\godot\fat_fish_rice --quit
& $exe --headless --path D:\dev\godot\fat_fish_rice -- --demo
```

`--demo` 会走一遍「开局 → 推进 8 秒 → 结算」，并断言分数/接住数确实在动、存档确实落了最高分；
失败时退出码 1。`--shot` 见 `tools/shotter.gd`（headless 下截图是空的，必须开窗口）。

## 版权与来源声明

- **游戏代码**（本仓库的 `.gd` / `.tscn` / 工具脚本）为原创，可自由参考。
- **角色形象**：主角是「蓝色大肥鱼 / DeepSeek娘（鲸鱼娘）」，即社区对 DeepSeek 蓝鲸 logo 的
  拟人二创形象，权利归 DeepSeek 及原二创作者（溟月 / ZipZipPipe 等）。本项目是**非商业同人作品**，
  与 DeepSeek 官方无关，也未获官方授权。
- **角色立绘** `assets/art/char.png` 由本地 Stable Diffusion（anything-v5 + 自训 LoRA）生成后处理而来；
  **训练数据集与 LoRA 权重不包含在本仓库内**（它们是从第三方图集衍生的，避免二次分发）。
- **锅 `pot_icon.png`、掉落物、UI、天空**：AI 生成或程序化绘制。
- 如需商用，请自行替换角色形象与相关素材。



- 美术是程序化 + 单张静态立绘，**没有角色动画**（只有发丝/尾巴/火苗的 `_draw` 微动）。
  要做跑动/受击动画需要拆件或骨骼，那是另一个任务。
- 没有音效与背景音乐。
- 退出时的 `ObjectDB instances leaked` / `resources still in use` 是 `--quit` 首帧退出的正常噪音。
- 存档在 `user://saves/player_default_meta_profile.json`（沙箱内即重定向后的 APPDATA 下）。
- 触屏只做了「按住拖动」，没有做多指与手势。
