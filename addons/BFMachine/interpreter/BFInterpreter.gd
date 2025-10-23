@tool
@icon("res://addons/BFMachine/assets/BFMachine.svg")
class_name BFInterpreter
extends Control

## Used to display, run, and interact with [BFMachine]s and BF programs.

## A preset program to appear in the program window.
@export_multiline var preset_program: String = ""
@export var _current_machine: BFMachine = null

@export_group("Refs")
@export var _program_box: TextEdit = null
@export var _tape_box: LineEdit = null
@export var _output_box: LineEdit = null
@export var _output_as_string_box: LineEdit = null
@export var _input_box: SpinBox = null
@export var _current_error_code: SpinBox = null
@export var _paused_check: CheckBox = null
@export var _finished_check: CheckBox = null
@export var _reset_button: Button = null
@export var _reset_program_button: Button = null
@export var _input_button: Button = null
@export var _run_button: Button = null
@export var _bypass_error_button: Button = null

@export var _trim_program_button: Button = null
@export var _save_program_button: Button = null
@export var _load_program_button: Button = null
@export var _program_path_box: LineEdit = null

func _enter_tree() -> void:
	_connect_signals()
	_on_reset_program()
	_on_reset()

func _ready() -> void:
	_connect_signals()
	_on_reset()

func _exit_tree() -> void:
	_disconnect_signals()

func _update_ui() -> void:
	if _run_button.icon == null and has_theme_icon("Play", "EditorIcons"):
		_run_button.icon = get_theme_icon("Play", "EditorIcons")
	if _reset_program_button.icon == null and has_theme_icon("Reload", "EditorIcons"):
		_reset_program_button.icon = get_theme_icon("Reload", "EditorIcons")
	if _current_machine == null:
		_current_machine = BFMachine.new()
		_current_machine.exceptions_in_engine = Engine.is_editor_hint()
		_current_machine.recursion_timeout_count_max = (0b1 << 16) - 1
	_tape_box.text = str(_current_machine.tape)
	_output_box.text = str(_current_machine.output)
	_output_as_string_box.text = str(_current_machine.output_as_string)
	_current_error_code.value = _current_machine.last_exception_encountered
	_paused_check.button_pressed = _current_machine.paused
	_finished_check.button_pressed = _current_machine.finished
	_bypass_error_button.disabled = not _current_machine.exception_encountered
	_run_button.disabled = (_current_machine.exception_encountered or
							_current_machine.finished or
							_current_machine.paused
							)
	_input_button.disabled = not _current_machine.paused
	_input_box.editable = _current_machine.paused
	_trim_program_button.disabled = _program_box.text.is_empty()
	_save_program_button.disabled = _program_box.text.is_empty()
	_load_program_button.disabled = _program_box.text.is_empty()

func _on_run() -> void:
	if _current_machine == null:
		_current_machine = BFMachine.new()
		_current_machine.exceptions_in_engine = true
		_current_machine.recursion_timeout_count_max = 255
	_current_machine.program = _program_box.text
	if _current_machine.interpret():
		_tape_box.grab_focus()
	else:
		_current_error_code.grab_focus()
	_update_ui()

func _on_input() -> void:
	_current_machine.input(_input_box.value)
	_update_ui()

func _on_paused_changed(changed_to: bool):
	_current_machine.paused = changed_to
	_update_ui()

func _on_bypass_error() -> void:
	_current_machine.exception_encountered = false
	_update_ui()

func _on_reset() -> void:
	_current_machine = null
	_update_ui()

func _on_reset_program() -> void:
	_program_box.text = preset_program
	_load_program_button.self_modulate = Color.WHITE
	_update_ui()

func _on_trim_program() -> void:
	_current_machine.program = _program_box.text
	_current_machine.trim_program_begining()
	_program_box.text = _current_machine.program
	_update_ui()

func _on_save_program() -> void:
	var file := FileAccess.open(_program_path_box.text, FileAccess.WRITE)
	var fail := false

	if (FileAccess.get_open_error() == OK) or file == null:
		fail = true
	else:
		file.store_string(_program_box.text)
		fail = (file.get_error() != OK)
		file.close()

	_save_program_button.self_modulate = Color(1.0, 0.5, 0.5, 1.0) if fail else Color.WHITE
	_update_ui()

func _on_load_program() -> void:
	if _current_machine.load_program_file(_program_path_box.text) != OK:
		_load_program_button.self_modulate = Color(1.0, 0.5, 0.5, 1.0)
	else:
		_save_program_button.self_modulate = Color.WHITE
		_program_box.text = _current_machine.program
	_update_ui()

func _connect_signals() -> void:
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
	if not _trim_program_button.pressed.is_connected(_on_trim_program):
		_trim_program_button.pressed.connect(_on_trim_program)
	if not _save_program_button.pressed.is_connected(_on_save_program):
		_save_program_button.pressed.connect(_on_save_program)
	if not _load_program_button.pressed.is_connected(_on_load_program):
		_load_program_button.pressed.connect(_on_load_program)

func _disconnect_signals() -> void:
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
	if _trim_program_button.pressed.is_connected(_on_trim_program):
		_trim_program_button.pressed.disconnect(_on_trim_program)
	if _save_program_button.pressed.is_connected(_on_save_program):
		_save_program_button.pressed.disconnect(_on_save_program)
	if _load_program_button.pressed.is_connected(_on_load_program):
		_load_program_button.pressed.disconnect(_on_load_program)
