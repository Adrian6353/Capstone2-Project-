extends Node
## CutsceneManager — Autoloaded singleton that orchestrates CutscenePlayer.
##
## Usage (fire-and-forget with callback):
##   CutsceneManager.play_chapter_intro(1, func(): ...)
##   CutsceneManager.play_map_intro(1, 2, func(): ...)
##   CutsceneManager.play_boss_intro(1, func(): ...)
##   CutsceneManager.play_chapter_outro(1, func(): ...)
##   CutsceneManager.play_prologue(func(): ...)
##
## Usage with await in a coroutine:
##   CutsceneManager.play_boss_intro_async(ch)
##   await CutsceneManager.cutscene_done
##
##   CutsceneManager.play_chapter_outro_async(ch)
##   await CutsceneManager.cutscene_done

## Emitted when an _async variant finishes (for use with await in GameScene).
signal cutscene_done

const _CutscenePlayerGD := preload("res://Scenes/UIScenes/CutscenePlayer.gd")
var _player: CanvasLayer = null

# ---------------------------------------------------------------------------
# Player lifecycle
# ---------------------------------------------------------------------------

func _get_player() -> CanvasLayer:
	if not is_instance_valid(_player):
		_player = CanvasLayer.new()
		_player.set_script(_CutscenePlayerGD)
		get_tree().root.add_child(_player)
	return _player

# ---------------------------------------------------------------------------
# Core internal play method (fire-and-forget with callback)
# ---------------------------------------------------------------------------

func _play(key: String, callback: Callable) -> void:
	# Silently skip in co-op — cutscenes are single-player only.
	if CoopManager.is_coop_active:
		callback.call()
		return

	if not StoryData.has_sequence(key):
		# No content defined for this key — proceed immediately.
		callback.call()
		return

	var player := _get_player()
	player.play_sequence(StoryData.get_sequence(key))
	# Await in a fire-and-forget coroutine so the caller is not blocked.
	_await_and_callback(player, callback)

func _await_and_callback(player: CanvasLayer, callback: Callable) -> void:
	await player.sequence_finished
	callback.call()

# ---------------------------------------------------------------------------
# Async variants — used with `await CutsceneManager.cutscene_done`
# ---------------------------------------------------------------------------

func _play_async(key: String) -> void:
	if CoopManager.is_coop_active or not StoryData.has_sequence(key):
		cutscene_done.emit()
		return
	var player := _get_player()
	player.play_sequence(StoryData.get_sequence(key))
	await player.sequence_finished
	cutscene_done.emit()

# ---------------------------------------------------------------------------
# Public API — callback variants
# ---------------------------------------------------------------------------

## Plays the prologue sequence, then calls callback.
func play_prologue(callback: Callable) -> void:
	_play("prologue", callback)

## Plays the chapter intro sequence for the given chapter, then calls callback.
func play_chapter_intro(chapter: int, callback: Callable) -> void:
	_play("ch%d_intro" % chapter, callback)

## Plays the per-map intro sequence, then calls callback.
func play_map_intro(chapter: int, map_idx: int, callback: Callable) -> void:
	_play("ch%d_map%d" % [chapter, map_idx], callback)

## Plays the boss intro sequence, then calls callback.
func play_boss_intro(chapter: int, callback: Callable) -> void:
	_play("ch%d_boss_intro" % chapter, callback)

## Plays the chapter outro sequence, then calls callback.
func play_chapter_outro(chapter: int, callback: Callable) -> void:
	_play("ch%d_outro" % chapter, callback)

# ---------------------------------------------------------------------------
# Public API — async variants (use with `await CutsceneManager.cutscene_done`)
# ---------------------------------------------------------------------------

## Async boss intro — emits cutscene_done when finished.
## Example:
##   CutsceneManager.play_boss_intro_async(ch)
##   await CutsceneManager.cutscene_done
func play_boss_intro_async(chapter: int) -> void:
	await _play_async("ch%d_boss_intro" % chapter)

## Async chapter outro — emits cutscene_done when finished.
func play_chapter_outro_async(chapter: int) -> void:
	await _play_async("ch%d_outro" % chapter)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns true if a sequence exists for the given key.
func has_sequence(key: String) -> bool:
	return StoryData.has_sequence(key)
