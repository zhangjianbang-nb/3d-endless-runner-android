"""Godot 项目 headless 结构校验入口（实现 DC3）。

用法：python3 scripts/validate.py  （exit 0 = 通过，exit 1 = 失败）
断言项：.gd 缩进/语法结构、.tscn 场景节点完整性、
project.godot 配置与 android 导出预设存在。
若环境有 godot 二进制，额外尝试 godot --headless --check-only。
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = sys.stdout


def say(msg: str) -> None:
    OUT.write(msg + "\n")


def check(cond: bool, msg: str) -> bool:
    if not cond:
        say("FAIL: " + msg)
    return cond


def main() -> int:
    ok = True

    pg = (ROOT / "project.godot").read_text(encoding="utf-8")
    ok &= check("config_version=5" in pg, "project.godot config_version=5 缺失")
    m = re.search(r'run/main_scene="([^"]+)"', pg)
    ok &= check(m is not None, "run/main_scene 缺失")
    if m:
        ok &= check((ROOT / m.group(1).replace("res://", "")).is_file(),
                    "主场景不存在: " + m.group(1))
    ok &= check('Sfx="*res://scripts/sfx.gd"' in pg, "autoload Sfx 缺失")
    ok &= check("window/handheld/orientation=1" in pg, "竖屏方向缺失")
    ok &= check('renderer/rendering_method="mobile"' in pg, "mobile 渲染器缺失")

    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    ok &= check('platform="Android"' in presets, "Android 导出预设缺失")

    scenes = sorted((ROOT / "scenes").glob("*.tscn"))
    ok &= check(len(scenes) >= 2, "场景文件数量不足")
    for path in scenes:
        body = path.read_text(encoding="utf-8")
        ok &= check(body.startswith("[gd_scene "), path.name + " 缺少 gd_scene 头")
        ok &= check("format=3" in body, path.name + " 非 format=3")
        for res in re.finditer(r'\[ext_resource type="([^"]+)" path="([^"]+)"', body):
            if res.group(1) == "Script":
                script = ROOT / res.group(2).replace("res://", "")
                ok &= check(script.is_file(),
                            path.name + " 引用的脚本不存在: " + res.group(2))
        ok &= check("[node " in body, path.name + " 无节点定义")

    scripts = sorted((ROOT / "scripts").glob("*.gd"))
    ok &= check(len(scripts) >= 4, "脚本数量不足")
    for path in scripts:
        body = path.read_text(encoding="utf-8")
        for no, line in enumerate(body.splitlines(), 1):
            ok &= check(not line.startswith(" "),
                        path.name + " 第 " + str(no) + " 行使用空格缩进")
        ok &= check("extends " in body, path.name + " 缺少 extends 声明")

    godot = shutil.which("godot")
    if godot:
        say("发现 godot 二进制，尝试 --headless --check-only")
        probe = ROOT / "scripts" / "game.gd"
        proc = subprocess.run(
            [godot, "--headless", "--check-only", "--script", str(probe)],
            cwd=ROOT, capture_output=True, text=True, timeout=120)
        ok &= check(proc.returncode == 0, "godot --check-only 校验失败")

    say("VALIDATION " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
