@tool
@icon("res://addons/BFMachine/assets/BFMachine.svg")
extends Control
class_name BFInterpreter

## Used to display, run, and interact with [BFMachine]s and BF programs.

## A preset program to appear in the program window.
@export_multiline var preset_program:String = ""
@export var _current_machine:BFMachine = null

@export_group("Refs")
@export var _program_box:TextEdit = null
@export var _tape_box:LineEdit = null
@export var _output_box:LineEdit = null
@export var _output_as_string_box:LineEdit = null
@export var _input_box:SpinBox = null
@export var _current_error_code:SpinBox = null
@export var _paused_check:CheckBox = null
@export var _finished_check:CheckBox = null
@export var _reset_button:Button = null
@export var _reset_program_button:Button = null
@export var _input_button:Button = null
@export var _run_button:Button = null
@export var _bypass_error_button:Button = null


func _enter_tree():
	_connect_signals()
	_on_reset_program()
	_on_reset()


func _ready():
	_connect_signals()
	_on_reset()


func _exit_tree():
	_disconnect_signals()


func _update_ui():
	if _current_machine == null:
		_current_machine = BFMachine.new()
		_current_machine.exceptions_in_engine = Engine.is_editor_hint()
		_current_machine.recursion_timeout_count_max = 0b1111111111111111
	_tape_box.text = str(_current_machine.tape)
	_output_box.text = str(_current_machine.output)
	_output_as_string_box.text = str(_current_machine.output_as_string)
	_current_error_code.value = _current_machine.last_exception_encountered
	_paused_check.button_pressed = _current_machine.paused
	_finished_check.button_pressed = _current_machine.finished
	_bypass_error_button.disabled = not _current_machine.exception_encountered
	_reset_button.disabled = not (_current_machine.exception_encountered or _current_machine.finished or _current_machine.paused)
	_run_button.disabled = (_current_machine.exception_encountered or _current_machine.finished or _current_machine.paused)
	_input_button.disabled = not _current_machine.paused
	_input_box.editable = _current_machine.paused


func _on_run():
	if _current_machine == null:
		_current_machine = BFMachine.new()
		_current_machine.exceptions_in_engine = true
		_current_machine.recursion_timeout_count_max = 0b1111111111111111
	_current_machine.program = _program_box.text
	_current_machine.interpret()
	_update_ui()


func _on_input():
	_current_machine.input(_input_box.value)
	_update_ui()


func _on_paused_changed(changed_to:bool):
	_current_machine.paused = changed_to
	_update_ui()


func _on_bypass_error():
	_current_machine.exception_encountered = false
	_update_ui()


func _on_reset():
	_current_machine = null
	_update_ui()


func _on_reset_program():
	_program_box.text = preset_program
	_update_ui()


func _connect_signals():
	if not _run_button.pressed.is_connected(_on_run):
		_run_button.pressed.connect(_on_run)
	if not _input_button.pressed.is_connected(_on_input):
		_input_button.pressed.connect(_on_input)
	if not _paused_check.toggled.is_connected(_on_paused_changed):
		_paused_check.toggled.connect(_on_paused_changed)
	if not _bypass_error_button.pressed.is_connected(_on_bypass_error):
		_bypass_error_button.pressed.connect(_on_bypass_error)
	if not _reset_button.pressed.is_connected(_on_reset):
		_reset_button.pressed.connect(_on_reset)
	if not _reset_program_button.pressed.is_connected(_on_reset_program):
		_reset_program_button.pressed.connect(_on_reset_program)


func _disconnect_signals():
	if _run_button.pressed.is_connected(_on_run):
		_run_button.pressed.disconnect(_on_run)
	if _input_button.pressed.is_connected(_on_input):
		_input_button.pressed.disconnect(_on_input)
	if _paused_check.toggled.is_connected(_on_paused_changed):
		_paused_check.toggled.disconnect(_on_paused_changed)
	if _bypass_error_button.pressed.is_connected(_on_bypass_error):
		_bypass_error_button.pressed.disconnect(_on_bypass_error)
	if _reset_button.pressed.is_connected(_on_reset):
		_reset_button.pressed.disconnect(_on_reset)
	if _reset_program_button.pressed.is_connected(_on_reset_program):
		_reset_program_button.pressed.disconnect(_on_reset_program)
