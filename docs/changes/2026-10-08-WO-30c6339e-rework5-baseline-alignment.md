# 变更快照 — WO-30c6339e 第5次返工续接（需求基线对齐）

日期：2026-10-08 · 部门：Coding · trace: trace-189196b10422

## 本次改动（续接，未重复已完成工作）
- 需求 id 对齐架构基线（architect WO-67836e6d R1..R8 + DC1..DC3）：
  上次会话自造的 R9/R10 标注全部废弃，重写 `test_project_validation.py`
  的 covers 标注与断言，逐条映射基线验收标准。
- `scripts/player.gd`：基类改为 `extends CharacterBody3D`（基线 R1 验收项
  「Player（CharacterBody3D）」）；注释改为「实现 R1, R2, R3, DC1」，
  并注明相对运动设计（实体沿 +Z 移向玩家，等价于角色沿 -Z 前进）。
- `scenes/game.tscn`：Player 节点类型 Node3D → CharacterBody3D（covers R1）。
- `scripts/game.gd`：新增 `_input` 处理 `ui_cancel`（Android 返回键/Esc 暂停，
  实现基线 R8 验收项「pause + Android 返回键」）；注释改为「实现 R4-R8」。
- `scripts/sfx.gd`、`scripts/main_menu.gd`：注释按基线 id 重新标注（R8 / R7）。
- 新增 `scripts/validate.py`：DC3 要求的 headless 校验入口
  （.gd 缩进/结构、.tscn 节点完整性、project.godot 与 android 预设断言；
  环境有 godot 二进制时自动尝试 `--headless --check-only`）。
- 本次会话无 godot 二进制，DC3 的 godot --check-only 分支未实测（代码路径保留）。

## 不改动项
- 游戏玩法逻辑（变道/跳跃/计分/加速/持久化）上一轮已完成且通过静态校验，
  本轮只做需求 id 对齐与基线验收项补齐，未动玩法代码。
