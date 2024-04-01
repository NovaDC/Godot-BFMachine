@tool
@icon("res://addons/BF_machine/assets/BF_machine.svg")
extends Control
class_name BFInterpreter

## BFMachine is a simple BF interpreter for Godot 4.
## It is a single file ``Resource`` that holds the entire state of the machine inside it,
## and a single scene that gives that interpreter a ui, so it can run in editor.
## Its also flexible, allowing for you to change settings on the fly, if you so choose.

@export var current_machine:BFMachine = null
@export_multiline var preset_program:String = ""

@export_group("Refs")
@export var program_box:TextEdit = null
@export var tape_box:LineEdit = null
@export var output_box:LineEdit = null
@export var output_as_string_box:LineEdit = null
@export var input_box:SpinBox = null
@export var current_error_code:SpinBox = null
@export var paused_check:CheckBox = null
@export var finished_check:CheckBox = null
@export var reset_button:Button = null
@export var reset_program_button:Button = null
@export var input_button:Button = null
@export var run_button:Button = null
@export var bypass_error_button:Button = null


func _enter_tree():
	connect_signals()
	on_reset_program()
	on_reset()


func _ready():
	connect_signals()
	on_reset()


func _exit_tree():
	disconnect_signals()


func _update_ui():
	if current_machine == null:
		current_machine = BFMachine.new()
		current_machine.exceptions_in_engine = Engine.is_editor_hint()
	tape_box.text = str(current_machine.tape)
	output_box.text = str(current_machine.output)
	output_as_string_box.text = str(current_machine.output_as_string)
	current_error_code.value = current_machine.last_exception_encountered
	paused_check.button_pressed = current_machine.paused
	finished_check.button_pressed = current_machine.finished
	bypass_error_button.disabled = not current_machine.exception_encountered
	reset_button.disabled = not (current_machine.exception_encountered or current_machine.finished or current_machine.paused)
	run_button.disabled = (current_machine.exception_encountered or current_machine.finished or current_machine.paused)
	input_button.disabled = not current_machine.paused
	input_box.editable = current_machine.paused


func on_run():
	if current_machine == null:
		current_machine = BFMachine.new()
		current_machine.exceptions_in_engine = Engine.is_editor_hint()
	current_machine.program = program_box.text
	current_machine.interpret()
	_update_ui()
	print(current_machine.loop_level)


func on_input():
	current_machine.input(input_box.value)
	_update_ui()


func on_paused_changed(changed_to:bool):
	current_machine.paused = changed_to
	_update_ui()


func on_bypass_error():
	current_machine.exception_encountered = false
	_update_ui()


func on_reset():
	current_machine = null
	_update_ui()


func on_reset_program():
	program_box.text = preset_program
	_update_ui()


func connect_signals():
	if not run_button.pressed.is_connected(on_run):
		run_button.pressed.connect(on_run)
	if not input_button.pressed.is_connected(on_input):
		input_button.pressed.connect(on_input)
	if not paused_check.toggled.is_connected(on_paused_changed):
		paused_check.toggled.connect(on_paused_changed)
	if not bypass_error_button.pressed.is_connected(on_bypass_error):
		bypass_error_button.pressed.connect(on_bypass_error)
	if not reset_button.pressed.is_connected(on_reset):
		reset_button.pressed.connect(on_reset)
	if not reset_program_button.pressed.is_connected(on_reset_program):
		reset_program_button.pressed.connect(on_reset_program)


func disconnect_signals():
	if run_button.pressed.is_connected(on_run):
		run_button.pressed.disconnect(on_run)
	if input_button.pressed.is_connected(on_input):
		input_button.pressed.disconnect(on_input)
	if paused_check.toggled.is_connected(on_paused_changed):
		paused_check.toggled.disconnect(on_paused_changed)
	if bypass_error_button.pressed.is_connected(on_bypass_error):
		bypass_error_button.pressed.disconnect(on_bypass_error)
	if reset_button.pressed.is_connected(on_reset):
		reset_button.pressed.disconnect(on_reset)
	if reset_program_button.pressed.is_connected(on_reset_program):
		reset_program_button.pressed.disconnect(on_reset_program)
