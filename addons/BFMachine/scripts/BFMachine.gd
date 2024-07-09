@tool
@icon("res://addons/BFMachine/assets/BFMachine.svg")
extends Resource
class_name BFMachine

## [BFMachine] is a simple BF interpreter.
## It is a single file [Resource] that holds the entire state of the machine inside it,
## and a single scene that gives that [BFInterpreter] a ui, so it can run in editor.
## Its also flexible, allowing for you to change settings on the fly, if you so choose.

#region Constants
## Enumeration defining BF opcodes, used for [member dialect] definitions.
enum BFOpcodes {
	## No OPeration. Preform no action.
	NOP = -1,
	## Tape RIGHT. Move the tape pointer forwards by one.
	TRIGHT,
	## Tape LEFT. Move the tape pointer backwards by one.
	TLEFT,
	## INCrement. Add one to the currently pointed cell.
	INC,
	## DECrement. Subtract one from the currently pointed cell.
	DEC,
	## OUTput. Output the currently pointed cell.
	OUT,
	## INput. Request input. The input will overwrite the currently pointed cell's value.
	IN,
	## Start LOOP. When the currently pointed cell is 0, begin a loop.
	## This loop must be enclosed in a SLOOP at the beginning and a ELOOP at the end.
	SLOOP,
	## End LOOP. When the currently pointed cell is not 0, return the program to the matching SLOOP.
	## This loop must be enclosed in a SLOOP at the beginning and a ELOOP at the end.
	ELOOP
}

## Enumeration defining BF error codes.
enum BFErrors {
	## No error is encountered. This is not an error, but instead a default value.
	NON_ERROR = 0,
	## The number of start and end loops are not equal.
	UNCLOSED_LOOP,
	## Used to indicate specifically when a immediately closed loop is found
	## and when that loop would be otherwise run infinity
	INFINITE_LOOP,
	## The tape pointer is outside of the bounds of the tape itself.
	TAPE_POINTER_OUT_OF_RANGE,
	## Raised when the amount of times an instruction in a loop was called surpasses the limit set
	RECURSION_TIMEOUT
}

## The official [member dialect] mapping of the language
const BASE_BF_DIALECT := {
	BFOpcodes.TRIGHT : ">",
	BFOpcodes.TLEFT : "<",
	BFOpcodes.INC : "+",
	BFOpcodes.DEC : "-",
	BFOpcodes.OUT : ".",
	BFOpcodes.IN : ",",
	BFOpcodes.SLOOP : "[",
	BFOpcodes.ELOOP : "]"
}
#endregion Constants

#region Signals
## Emitted when an [member output] is made.
signal program_outputted
## Emitted when the [member program] begins to wait for [method input].
signal awaiting_input
## Emitted when the [member program] is [member finished].
signal program_finished
## Emitted when there is a [member exception_encountered].
signal encountered_exception
## Emitted every step the [member program] makes.
signal stepped
#endregion Signals

#region Settings
## Exported variables for controlling machine settings.
## It is HEAVILY advised against modifying these during runtime,
## as it will most likely cause corruption.
## However I can't tell you what to do I'm not your mom.
@export_group("Settings")
## The current dialect of BF to use,
## expressed as a [Dictionary] with keys of [enum BFOpcodes] and values of [String].
## Use [constant BASE_BF_DIALECT] if you wish to use the normal BF dialect.
@export var dialect := BASE_BF_DIALECT
## The full string of the program being run.
@export var program := ""
## The initial value of a cell on the [member tape].
## Note: A cell on the [member tape] is only first made when the [member tape_pointer] first points to it
## (and only if the [member tape_pointer] is not exceeding the [member tape_length_max]
## when its larger than -1 and not [member wrap_cell_pointer]).
@export var cell_default_value:= 0
## The maximum [member tape] length.
## If the value is negative, the [member tape] will be infinite.
## Note: A cell on the [member tape] is only first made when the [member tape_pointer] first points to it
## (and only if the [member tape_pointer] is not exceeding the [member tape_length_max]
## when its larger than -1 and not [member wrap_cell_pointer]).
@export var tape_length_max:int = -1
## If true, the [member tape_pointer] going past the max or min cell
## will result in the [member tape_pointer] wrapping around to the start,
## otherwise a [constant TAPE_POINTER_OUT_OF_RANGE] BF error will be thrown
## when the [member tape_pointer] exceeds the tape length.
@export var wrap_cell_pointer := true
## Settings related the machine's output.
#region Output
@export_subgroup("Output")
## Pause the machine when an [member output] is made.
@export var pause_on_output := false
## Clear the [member output] whenever a new [member output] is made.
@export var clear_previous_output := false
#endregion Output
#region Exceptions
## Settings related to exceptions.
@export_subgroup("Exceptions")
## When a BF error is raised, throw an asserted Godot error as well.
@export var exceptions_in_engine := true
## When an unclosed loop is encountered, throw an error.
## This is heavily advised to remain on, unless you are debugging.
@export var exception_on_unclosed_loop := true
## When an infinite loop is encountered, throw an error.
## This is heavily advised to remain on, unless you are debugging.
@export var exception_on_infinite_loop := true
## The amount of times an instructions in loops can be run before raising a recursion timeout.
## This can be set to a negative value to remove this cap.
@export var recursion_timeout_count_max := -1
#endregion Exceptions
#endregion Settings

#region State
## Exported variables for maintaining the machine's state.
@export_group("State")
## This holds the value of the tape.
## Note: A cell on the [member tape] is only first made when the [member tape_pointer] first points to it
## (and only if the [member tape_pointer] is not exceeding the [member tape_length_max]
## when its larger than -1 and not [member wrap_cell_pointer]).
@export var tape := []
## This always returns the last exception encountered,
## even when the latest step did not encounter an exception.
@export var last_exception_encountered := BFErrors.NON_ERROR
## This is used to track how many loops are currently active.
## It is heavily advised to avoid modifying this, as this is not a safe way to break a loop.
@export var loop_level := 0
## The count of the amount of time an instruction in a loop was run.
## This will still be counted even when the [member recursion_timeout_count_max]
## is not set to timeout.
@export var recursion_timeout_count := 0
#region Output
## Output and its related states.
@export_subgroup("Output")
## The output of the [member program].
@export var output := []
## Gets and sets the [member output] as a UTF8 formatted [String], taking each [int] in the [member output] as a byte.
@export var output_as_string:String:
	get:
		var _return_string = ""
		for _char in output:
			_return_string += String.chr(_char)
		return _return_string
	set(value):
		output = value.to_ascii_buffer()
## All the halting reated flags.
@export_subgroup("Halting States")
## True when the [member program] is finished.
## It is advised against modifying this.
@export var finished := false
## Raised when the [member program] is paused.
## This can and should be modified when the user wants to pause and resume the [member program].
@export var paused := false
## Raised when an exception is encountered.
## It is advised to modify this where necessary, as this allows for an exception to be bypassed.
@export var exception_encountered := false
#endregion Output
#region Pointers
## The pointers to the [member program] and the [member tape].
@export_subgroup("Pointers")
## The position on the [member tape] currently in use.
## While not advised to be modified directly,
## doing so is safe in regards to [member wrap_cell_pointer] and uninitialised cell access
## as this is handled by this value's setter.
@export var tape_pointer := 0:
	get:
		return tape_pointer
	set(value):
		tape_pointer = value
		if tape_length_max >= 0 and tape_pointer > tape_length_max:
			if wrap_cell_pointer:
				tape_pointer = wrapi(tape_pointer, 0, tape_length_max+1) # Wrap the tape pointer around if it goes out of range
			else:
				raise_BF_error(BFErrors.TAPE_POINTER_OUT_OF_RANGE) # Raise exception if tape pointer goes out of range
				return
		while tape_pointer >= tape.size():
			tape.append(cell_default_value) # Extend the tape if tape pointer exceeds tape size
## The position the [member program] was currently being read from.
## This position corlated to the current charater in the [member program]'s [String].
@export var program_pointer := 0
#endregion Pointers
#endregion State


## Runs a [member program] on a optionally given [member tape] with a optional [method copy] of a given machine
## Returns an [Array] containing the [member output] of the machine, then the final [member tape] of the machine
static func run(program := "", tape := [], machine:BFMachine = null) -> Array:
	if machine == null:
		machine = BFMachine.new()
	else:
		machine = machine.copy()
	
	machine.program = program
	machine.tape = tape
	
	machine.interpret()
	
	return [machine.output, machine.tape]


## Runs a saved [member program] file on a optionally given [member tape] [Array] with a optional [method copy] of a given machine
## Returns an [Array] containing the [member output] of the machine, then the final [member tape] of the machine
static func run_file(program_path:String, tape := [], machine:BFMachine = null) -> Array:
	var program := FileAccess.open(program_path, FileAccess.READ).get_as_text(false)
	return BFMachine.run(program, tape, machine)


## Initialises the machine with a optionally predefined [member program] and [member tape].
func _init(program := "", tape := []):
	program = program
	tape = tape


## Returns a deep copy of the machine.
func copy() -> BFMachine:
	var machine := BFMachine.new(self.program, self.tape)
	#So, as far as I know, there is no simple way to copy objects in GD script deeply,
	#so here's it all done manually
	machine.dialect = self.dialect.duplicate(true)
	machine.cell_default_value = self.cell_default_value
	machine.tape_length_max = self.tape_length_max
	machine.wrap_cell_pointer = self.wrap_cell_pointer
	machine.pause_on_output = self.pause_on_output
	machine.clear_previous_output = self.clear_previous_output
	machine.exceptions_in_engine = self.exceptions_in_engine
	machine.exception_on_unclosed_loop = self.exception_on_unclosed_loop
	machine.exception_on_infinite_loop = self.exception_on_infinite_loop
	machine.recursion_timeout_count_max = self.recursion_timeout_count_max
	machine.last_exception_encountered = self.last_exception_encountered
	machine.loop_level = self.loop_level
	machine.recursion_timeout_count = self.recursion_timeout_count
	machine.output = self.output.duplicate(true)
	machine.finished = self.finished
	machine.paused = self.paused
	machine.exception_encountered = self.exception_encountered
	machine.tape_pointer = self.tape_pointer
	machine.program_pointer = self.program_pointer
	
	return machine


## Used to input into the machine.
## Note: This will always unpause the machine.
func input(in_value:int):
	tape[tape_pointer] = in_value
	paused = false


## Used to raise a BF error.
func raise_BF_error(error:BFErrors):
	encountered_exception.emit()
	exception_encountered = true
	if exceptions_in_engine:
		assert(false, "BF error %s encountered!" % [error])  # If exceptions in engine, assert an error
	last_exception_encountered = error


## Used to fetch the current pointed instruction in the machine's [member program].
func pointed_instruction() -> BFOpcodes:
	for k in dialect.keys():
		if program.substr(program_pointer).begins_with(dialect[k]):
			return k
	return BFOpcodes.NOP


## Used to move the [member program_pointer] to the next instruction in the [member program].
## This will not regard any bounds of the [member program], nor will raise any exceptions.
func inc_instruction():
	var ins = pointed_instruction()
	program_pointer += dialect[ins].length() if ins != BFOpcodes.NOP else 1

## Used to move the [member program_pointer] to the previous instruction in the [member program].
## This will not regard any bounds of the [member program], nor will raise any exceptions.
func dec_instruction():
	program_pointer -= 1
	while pointed_instruction() == BFOpcodes.NOP and program_pointer >= 0:
		program_pointer -= 1

## Executes a single instruction on the machine,
## optionally with it also stepping the [member program_pointer].
## [param step_pointer] will be ignored for any instruction that may modify the [member program_pointer] manually.
## (excluding nop instructions).
func interpret_instruction(opcode:BFOpcodes, step_pointer := false):
	if tape.size() <= 0:
		tape = [cell_default_value]
	
	match(opcode):
		BFOpcodes.TRIGHT:
			tape_pointer += 1
			if step_pointer: inc_instruction()
		BFOpcodes.TLEFT:
			tape_pointer -= 1
			if step_pointer: inc_instruction()
		BFOpcodes.INC:
			tape[tape_pointer] += 1
			if step_pointer: inc_instruction()
		BFOpcodes.DEC:
			tape[tape_pointer] -= 1
			if step_pointer: inc_instruction()
		BFOpcodes.SLOOP:
			if tape[tape_pointer] == 0: #ignore this loop
				inc_instruction()
				program_pointer -= 1
				
				var loop_counter = 1
				while loop_counter > 0:
					program_pointer += 1
					if exception_on_unclosed_loop and program_pointer >= program.length():
						raise_BF_error(BFErrors.UNCLOSED_LOOP)
					elif pointed_instruction() == BFOpcodes.SLOOP:
						loop_counter += 1
					elif pointed_instruction() == BFOpcodes.ELOOP:
						loop_counter -= 1
				program_pointer += dialect[BFOpcodes.ELOOP].length()
			else: #enter this loop
				loop_level += 1
				if exception_on_infinite_loop:
					var next_instruction_pointer = program_pointer + dialect[BFOpcodes.SLOOP].length()
					if next_instruction_pointer < program.length():
						if pointed_instruction() == BFOpcodes.ELOOP:
							raise_BF_error(BFErrors.INFINITE_LOOP)
				program_pointer += dialect[BFOpcodes.SLOOP].length()
		BFOpcodes.ELOOP:
			if tape[tape_pointer] != 0: #continue this loop
				var loop_counter = 1
				while loop_counter > 0:
					program_pointer -= 1
					if exception_on_unclosed_loop and program_pointer < 0:
						raise_BF_error(BFErrors.UNCLOSED_LOOP)
					elif pointed_instruction() == BFOpcodes.SLOOP:
						loop_counter -= 1
					elif pointed_instruction() == BFOpcodes.ELOOP:
						loop_counter += 1
				program_pointer += dialect[BFOpcodes.SLOOP].length()
			else: #exit this loop
				loop_level -= 1
				program_pointer += dialect[BFOpcodes.ELOOP].length()
		BFOpcodes.OUT:
			if clear_previous_output:
				output = []
			output.append(tape[tape_pointer])
			program_outputted.emit(output)
			if pause_on_output:
				paused = true
			if step_pointer: inc_instruction()
		BFOpcodes.IN:
			paused = true
			awaiting_input.emit()
			if step_pointer: inc_instruction()
		_:
			inc_instruction()

	if loop_level > 0:
		recursion_timeout_count += 1
		if recursion_timeout_count_max >= 0 and recursion_timeout_count >= recursion_timeout_count_max:
			raise_BF_error(BFErrors.RECURSION_TIMEOUT)
	else:
		recursion_timeout_count = 0

## Steps through the [member program] once.
## Returns true if the [member program] is halted before or after this step was executed.
func interpret_step() -> bool:
	if exception_encountered or paused or finished:
		return true
	
	interpret_instruction(pointed_instruction(), true)
	stepped.emit() #Emit the stepped signal after each program step
	
	if program_pointer >= program.length() and not exception_encountered:
		finished = true
		program_finished.emit()
		return true
	
	return exception_encountered or paused


## Steps through the [member program] until it halts, for whatever reason.
## Returns true if the program is [member finished]
## (specifically [member finished] and not any other form of halt).
func interpret() -> bool:
	while (program_pointer >= 0 and program_pointer < program.length()) and not (interpret_step()):
		pass
	
	return finished
