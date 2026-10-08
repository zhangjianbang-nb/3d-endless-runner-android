# 变更快照：WO-30c6339e 第 6 轮返工 —— 修复 validate.py 编译错误

- 日期：2026-10-08 19:55 UTC
- 部门：coding
- 失败维度：build（`python3 -m compileall -q .` 退出码 1，分类 compile_error）

## 根因

`scripts/validate.py` 第 72–73 行存在一处损坏的代码块，第 73 行 `cwd=str=ROOT` 是非法语法
（关键字参数值中不允许再出现 `=`），`python3 -m compileall -q .` 在编译该文件时报
SyntaxError，使 build 维度门控整体退出码为 1。第 72 行同区块的 `str(probe.name)` 亦有语义
问题（`--check-only --script` 需要完整脚本路径而非裸文件名）。

## 改动

| 文件 | 改动 |
|---|---|
| `scripts/validate.py:71-73` | `str(probe.name)` → `str(probe)`（传完整路径）；`cwd=str=ROOT` → `cwd=ROOT`（消除 SyntaxError） |

未改动任何其他文件；玩法脚本（.gd）、场景、测试均未触碰。

## 验证

- `grep -cnE '=[A-Za-z_]+=' *.py` → 仅 validate.py 命中 1 处（修复前），test_project_validation.py 为 0。
- 修复后该模式全仓 .py 命中 0。
- 门控 build 维度由编排器以真实退出码复跑判定。
