"""3D 无尽跑酷 Godot 项目静态校验（python 断言脚本，covers 需求基线 R1-R8 + DC1-DC3）。

需求基线来源：architect WO-67836e6d-result.md 第 2 节。
用法：python3 -m pytest test_project_validation.py -q
每条需求至少一个测试覆盖（见各测试函数 docstring 的 covers 标注）。
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def _text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _gd_scripts() -> dict:
    return {
        p.name: p.read_text(encoding="utf-8")
        for p in sorted((ROOT / "scripts").glob("*.gd"))
    }


def _scene_paths() -> list:
    return sorted((ROOT / "scenes").glob("*.tscn"))


def test_scene_files_complete():
    """covers DC3：.tscn 场景节点完整性（头/格式/资源引用/节点块）。"""
    scenes = _scene_paths()
    assert len(scenes) >= 2, "场景文件数量不足"
    for path in scenes:
        body = path.read_text(encoding="utf-8")
        assert body.startswith("[gd_scene "), "%s 缺少 gd_scene 头" % path.name
        assert "format=3" in body, "%s 非 format=3" % path.name
        for m in re.finditer(r'\[ext_resource type="([^"]+)" path="([^"]+)"', body):
            if m.group(1) == "Script":
                script = ROOT / m.group(2).replace("res://", "")
                assert script.is_file(), "%s 引用的脚本不存在: %s" % (path.name, m.group(2))
        assert "[node " in body, "%s 无节点定义" % path.name


def test_gd_indentation_and_hygiene():
    """covers DC3：.gd 脚本使用 Tab 缩进且无遗留标记。"""
    scripts = _gd_scripts()
    assert len(scripts) >= 4, "脚本数量不足"
    for name, body in scripts.items():
        for no, line in enumerate(body.splitlines(), 1):
            assert not line.startswith(" "), "%s 第 %d 行使用空格缩进" % (name, no)
        assert "extends " in body, "%s 缺少 extends 声明" % name
        for marker in ("TODO", "FIXME", "HACK", "XXX"):
            assert marker not in body, "%s 含遗留标记 %s" % (name, marker)


def test_validate_script_exists():
    """covers DC3：scripts/validate.py headless 校验入口存在且含断言。"""
    validate = ROOT / "scripts" / "validate.py"
    assert validate.is_file(), "缺少 scripts/validate.py"
    body = validate.read_text(encoding="utf-8")
    assert "check(" in body, "缺少断言辅助函数"
    assert "SystemExit" in body, "validate.py 缺少退出码控制"


def test_r1_three_lanes():
    """covers R1：三车道跑酷（Player CharacterBody3D + 车道坐标常量 + 前进运动）。"""
    player = _text("scripts/player.gd")
    scene = _text("scenes/game.tscn")
    assert 'type="CharacterBody3D"' in scene, "游戏场景缺少 CharacterBody3D 玩家"
    assert "LANE_X" in player, "缺少三车道坐标常量"
    assert len(re.findall(r"-?\d+\.\d+", re.search(r"LANE_X := \[([^\]]+)\]", player).group(1))) == 3, \
        "车道坐标必须为 3 条"
    # 相对运动：实体沿 Z 移向玩家（等价于角色沿 -Z 前进）
    game = _text("scripts/game.gd")
    assert "position.z += speed * delta" in game, "缺少沿 Z 轴的前进运动"


def test_r2_swipe_lane_switch():
    """covers R2：左右滑变道（左滑 -1 / 右滑 +1，钳位 0..2，平滑插值）。"""
    player = _text("scripts/player.gd")
    assert "InputEventScreenTouch" in player, "缺少触屏输入处理"
    assert "move_lane" in player, "缺少变道函数"
    assert "clampi(lane + dir, 0, LANE_X.size() - 1)" in player, "缺少车道钳位"
    assert "lerpf(position.x, target_x" in player, "缺少平滑插值位移"
    assert "KEY_LEFT" in player and "KEY_RIGHT" in player, "缺少键盘备选输入"


def test_r3_swipe_jump():
    """covers R3：上滑跳跃（跳跃速度 + 重力回落 y=0）。"""
    player = _text("scripts/player.gd")
    assert "try_jump" in player, "缺少跳跃入口"
    assert "JUMP_VELOCITY" in player and "GRAVITY" in player, "缺少跳跃物理常量"
    assert "delta.y <= -SWIPE_MIN_PIXELS" in player, "缺少上滑判定"
    assert "position.y = maxf(0.0, position.y + _vy * delta)" in player, "缺少回落至 y=0"


def test_r4_obstacle_game_over():
    """covers R4：躲避障碍；碰撞触发游戏结束。"""
    game = _text("scripts/game.gd")
    scene = _text("scenes/game.tscn")
    assert '"obstacle"' in game, "缺少障碍分组"
    assert "Area3D.new()" in game and "CollisionShape3D" in game, "缺少障碍碰撞体"
    assert 'is_in_group("player")' in game, "缺少玩家碰撞判定"
    assert "_game_over" in game, "缺少游戏结束流程"


def test_r5_coin_score():
    """covers R5：金币收集计分（拾取后加分、移除、HUD 刷新）。"""
    game = _text("scripts/game.gd")
    assert '"coin"' in game, "缺少金币分组"
    assert "score += 1" in game, "缺少计分递增"
    assert "_entities.erase(entity)" in game, "缺少拾取后移除"
    assert "score_label.text" in game, "缺少 HUD 分数刷新"


def test_r6_speed_increase():
    """covers R6：速度随分数渐增且有上限。"""
    game = _text("scripts/game.gd")
    assert "SPEED_PER_SCORE" in game, "缺少加速系数"
    assert "MAX_SPEED" in game, "缺少速度上限"
    assert "minf(MAX_SPEED" in game, "缺少上限钳制"


def test_r7_score_persistence():
    """covers R7：计分累计 + 最高分经 user:// ConfigFile 读写。"""
    game = _text("scripts/game.gd")
    menu = _text("scripts/main_menu.gd")
    for name, body in (("game.gd", game), ("main_menu.gd", menu)):
        assert "ConfigFile" in body, "%s 缺少 ConfigFile" % name
        assert "user://highscore.cfg" in body, "%s 缺少存档路径" % name
    assert "cfg.save(SAVE_PATH)" in game, "缺少保存调用"
    assert "cfg.load(SAVE_PATH)" in game, "缺少读取调用"


def test_r8_ui_and_sfx_hooks():
    """covers R8：主菜单/暂停/游戏结束 UI 与音效钩子（含 Android 返回键暂停）。"""
    game_scene = _text("scenes/game.tscn")
    menu_scene = _text("scenes/main_menu.tscn")
    assert "PauseMenu" in game_scene, "缺少暂停面板"
    assert "GameOverPanel" in game_scene, "缺少结束面板"
    assert "StartButton" in menu_scene and "QuitButton" in menu_scene, "主菜单按钮缺失"
    game = _text("scripts/game.gd")
    assert "get_tree().paused" in game, "缺少暂停切换"
    assert 'is_action_pressed("ui_cancel")' in game, "缺少 Android 返回键暂停"
    sfx = _text("scripts/sfx.gd")
    assert "func play(" in sfx, "缺少 Sfx.play(name) 音效钩子接口"
    for hook in ("coin", "jump", "crash"):
        assert 'Sfx.play("%s")' % hook in game, "缺少音效钩子 %s" % hook


def test_dc1_procedural_geometry():
    """covers DC1：全部 3D 模型内置几何程序化生成，无外部资源文件。"""
    player = _text("scripts/player.gd")
    game = _text("scripts/game.gd")
    for name, body in (("player.gd", player), ("game.gd", game)):
        assert "MeshInstance3D.new()" in body, "%s 缺少程序化网格" % name
    for pattern in ("*.glb", "*.gltf", "*.obj", "*.fbx", "*.png", "*.jpg",
                     "*.wav", "*.ogg", "*.mp3"):
        assert not list(ROOT.rglob(pattern)), "存在外部资源文件 %s" % pattern


def test_dc2_android_portrait_export():
    """covers DC2：竖屏安卓导出（orientation + 720x1280 + android 预设）。"""
    pg = _text("project.godot")
    assert "window/handheld/orientation=1" in pg, "竖屏方向缺失"
    assert "viewport_width=720" in pg and "viewport_height=1280" in pg, "基准分辨率缺失"
    assert 'platform="Android"' in _text("export_presets.cfg"), "Android 预设缺失"


def test_project_godot_integrity():
    """covers DC2/DC3：project.godot 完整性（主场景/autoload/mobile 渲染）。"""
    pg = _text("project.godot")
    assert "config_version=5" in pg, "config_version=5 缺失"
    m = re.search(r'run/main_scene="([^"]+)"', pg)
    assert m, "run/main_scene 缺失"
    main_scene = ROOT / m.group(1).replace("res://", "")
    assert main_scene.is_file(), "主场景文件不存在: %s" % m.group(1)
    assert 'Sfx="*res://scripts/sfx.gd"' in pg, "autoload Sfx 缺失"
    assert 'renderer/rendering_method="mobile"' in pg, "mobile 渲染器缺失"


def test_docs_snapshot():
    """covers DC3：docs/changes 变更快照存在。"""
    docs = list((ROOT / "docs" / "changes").glob("*.md"))
    assert docs, "缺少 docs/changes 快照"
