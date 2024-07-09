@tool
@icon("res://addons/BFMachine/assets/BFMachine.svg")
extends EditorPlugin

const INTERPRETER_SCENE_REF = preload("res://addons/BFMachine/interpreter/BFInterpreter.tscn")
var current_interpreter:BFInterpreter = null
var is_added:bool = false

func add_control():
	if not is_added:
		add_control_to_bottom_panel(current_interpreter, "BF Interpreter")
		is_added = true

func remove_control():
	if is_added:
		remove_control_from_bottom_panel(current_interpreter)
		is_added = false

func _enter_tree():
	if current_interpreter == null:
		current_interpreter = INTERPRETER_SCENE_REF.instantiate()
	add_control()

func _enable_plugin():
	add_control()

func _disable_plugin():
	remove_control()

func _exit_tree():
	remove_control()
	if current_interpreter != null:
		current_interpreter.queue_free()
		current_interpreter = null
