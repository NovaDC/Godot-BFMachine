@tool
@icon("./bf_machine.svg")
extends EditorPlugin

const PLUGIN_NAME := "bf_machine"

const PLUGIN_ICON := preload("./bf_machine.svg")

const INTERPRETER_SCENE = preload("./bf_interpreter.tscn")

const ENSURE_SCRIPT_DOCS: Array[Script] = [
	preload("./bf_machine.gd"),
]

var _interpreter: BFInterpreter = null
var _loader: BFProgramLoader = null

# Every once ands a while the script docs simply refuse to update properly.
# This nudges the docs into a ensuring that the important scripts added by
# this addon are actually loaded.
func _ensure_script_docs():
	var edit := get_editor_interface().get_script_editor()
	for scr in ENSURE_SCRIPT_DOCS:
		edit.update_docs_from_script(scr)

func _enter_tree() -> void:
	_ensure_script_docs()
	if EditorInterface.is_plugin_enabled(PLUGIN_NAME):
		_init_plugin()

func _exit_tree() -> void:
	_deinit_plugin()

func _enable_plugin() -> void:
	_ensure_script_docs()
	_init_plugin()

func _disable_plugin() -> void:
	_deinit_plugin()

func _get_plugin_name() -> String:
	return PLUGIN_NAME

func _get_plugin_icon() -> Texture2D:
	return PLUGIN_ICON

func _init_plugin() -> void:
	if _interpreter == null and INTERPRETER_SCENE != null:
		_interpreter = INTERPRETER_SCENE.instantiate()
		add_control_to_bottom_panel(_interpreter, _interpreter.name)
	if _loader == null:
		_loader = BFProgramLoader.new()
		add_import_plugin(_loader)

func _deinit_plugin() -> void:
	if _interpreter != null:
		remove_control_from_bottom_panel(_interpreter)
		_interpreter.queue_free()
		_interpreter = null
	if _loader != null:
		remove_import_plugin(_loader)
		_loader = null
