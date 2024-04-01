@tool
@icon("res://addons/BF_machine/assets/BF_machine.svg")
extends Resource
class_name BFMachine

#region Constants
## Enumeration defining BF opcodes, used for dialect definitions.
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

## The official dialect mapping of the language
const BASE_BF_DIALECT = {
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
## Emitted when an output is made.
signal program_outputted
## Emitted when the program begins to wait for input.
signal awaiting_input
## Emitted when the program finishes.
signal program_finished
## Emitted when an exception is encountered.
signal encountered_exception
## Emitted every step the program makes.
signal stepped
#endregion Signals

#region Settings
## Exported variables for controlling machine settings.
## It is HEAVILY advised against modifying these during runtime,
## as it will most likely cause corruption.
## However I can't tell you what to do I'm not your mom.
@export_group("Settings")
## The current dialect of BF to use,
## expressed as a [Dictionary] with keys of [BFOpcodes] and values of [String].
## Use [BFMachine.BASE_BF_DIALECT] if you wish to use the normal BF dialect.
@export var dialect := BASE_BF_DIALECT
## The full string of the program being run.
@export var program := ""
## The initial value of a cell on the tape.
## Note: A cell on the tape is only first made when the tape pointer first points to it
## (and only if the tape pointer is not exceeding the [BFMachine.tape_length_max] when its larger than -1 and not [BFMachine.wrap_cell_pointer]).
@export var cell_default_value:= 0
## The maximum tape length.
## If the value is negative, the tape will be infinite.
## Note: A cell on the tape is only first made when the tape pointer first points to it
## (and only if the tape pointer is not exceeding the [BFMachine.tape_length_max] when its larger than -1 and not [BFMachine.wrap_cell_pointer]).
@export var tape_length_max:int = -1
## If true, the cell pointer going past the max or min cell will result in the pointer wrapping around to the start,
## otherwise a [BFMachine.BFErrors.TAPE_POINTER_OUT_OF_RANGE] BF error will be thrown when the cell pointer exceeds the tape length.
@export var wrap_cell_pointer := true
## Settings related the machine's output.
#region Output
@export_subgroup("Output")
## Pause the machine when an output is made.
@export var pause_on_output := false
## Clear the output whenever a new output is made.
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
## Note: A cell on the tape is only first made when the tape pointer first points to it
## (and only if the tape pointer is not exceeding the [BFMachine.tape_length_max] when its larger than -1 and not [BFMachine.wrap_cell_pointer]).
@export var tape := [0]
## This always returns the last exception encountered,
## even when the last step did not encounter an exception.
@export var last_exception_encountered := BFErrors.NON_ERROR
## This is used to track how many loops are currently active.
## It is heavily advised to avoid modifying this, as this is not a safe way to break a loop.
@export var loop_level := 0
## The count of the amount of time an instruction in a loop was run.
## This will still be counted even when the [BFMachine.recursion_timeout_count_max]
## is not set to timeout.
@export var recursion_timeout_count := 0
#region Output
## Output and its related states.
@export_subgroup("Output")
## The output of the program.
@export var output := []
## Gets and sets the output as a UTF8 formatted string, taking each number in the output as a byte.
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
## True when the program is finished.
## It is advised against modifying this.
@export var finished := false
## Raised when the program is paused.
## This can and should be modified when the user wants to pause and resume the program.
@export var paused := false
## Raised when an exception is encountered.
## It is advised to modify this where necessary, as this allows for an exception to be bypassed.
@export var exception_encountered := false
#endregion Output
#region Pointers
## The pointers to the program and the tape.
@export_subgroup("Pointers")
## The position on the tape currently in use.
## While not advised to be modified directly,
## doing so is safe in regards to pointer wrapping and uninitialised cell acess
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
## The position the program was currently being read from.
## This position corlated to the current charater in the program string.
@export var program_pointer := 0
#endregion Pointers
#endregion State


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
		assert(false, "BF error encountered: " + str(error)) # If exceptions in engine, assert an error
	last_exception_encountered = error


## Steps through the program once.
## Returns true if the program is halted before or after this step was executed.
func interpret_step() -> bool:
	if exception_encountered or paused or finished:
		return true
	
	# Check each instruction and execute corresponding action
	if program.substr(program_pointer).begins_with(dialect[BFOpcodes.TRIGHT]):
		tape_pointer += 1
		program_pointer += dialect[BFOpcodes.TRIGHT].length()
	elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.TLEFT]):
		tape_pointer -= 1
		program_pointer += dialect[BFOpcodes.TLEFT].length()
	elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.INC]):
		tape[tape_pointer] += 1
		program_pointer += dialect[BFOpcodes.INC].length()
	elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.DEC]):
		tape[tape_pointer] -= 1
		program_pointer += dialect[BFOpcodes.DEC].length()
	elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.SLOOP]):
		if tape[tape_pointer] == 0: #ignore this loop
			program_pointer += dialect[BFOpcodes.SLOOP].length() - 1
			var loop_counter = 1
			while loop_counter > 0:
				program_pointer += 1
				if exception_on_unclosed_loop and program_pointer >= program.length():
					raise_BF_error(BFErrors.UNCLOSED_LOOP)
				elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.SLOOP]):
					loop_counter += 1
				elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.ELOOP]):
					loop_counter -= 1
			program_pointer += dialect[BFOpcodes.ELOOP].length()
		else: #enter this loop
			loop_level += 1
			if exception_on_infinite_loop:
				var next_instruction_pointer = program_pointer + dialect[BFOpcodes.SLOOP].length()
				if next_instruction_pointer < program.length():
					if program.substr(next_instruction_pointer).begins_with(dialect[BFOpcodes.ELOOP]):
						raise_BF_error(BFErrors.INFINITE_LOOP)
			program_pointer += dialect[BFOpcodes.SLOOP].length()
	elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.ELOOP]):
		if tape[tape_pointer] != 0: #continue this loop
			var loop_counter = 1
			while loop_counter > 0:
				program_pointer -= 1
				if exception_on_unclosed_loop and program_pointer < 0:
					raise_BF_error(BFErrors.UNCLOSED_LOOP)
				elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.SLOOP]):
					loop_counter -= 1
				elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.ELOOP]):
					loop_counter += 1
			program_pointer += dialect[BFOpcodes.SLOOP].length()
		else: #exit this loop
			loop_level -= 1
			program_pointer += dialect[BFOpcodes.ELOOP].length()
	elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.OUT]):
		if clear_previous_output:
			output = []
		output.append(tape[tape_pointer])
		program_outputted.emit(output)
		if pause_on_output:
			paused = true
		program_pointer += dialect[BFOpcodes.OUT].length()
	elif program.substr(program_pointer).begins_with(dialect[BFOpcodes.IN]):
		paused = true
		awaiting_input.emit()
		program_pointer += dialect[BFOpcodes.IN].length()
	else:
		program_pointer += 1
	
	stepped.emit() #Emit the stepped signal after each program step
	
	if loop_level > 0:
		recursion_timeout_count += 1
		if recursion_timeout_count_max >= 0 and recursion_timeout_count >= recursion_timeout_count_max:
			raise_BF_error(BFErrors.RECURSION_TIMEOUT)
	else:
		recursion_timeout_count = 0
	
	if program_pointer >= program.length() and not exception_encountered:
		finished = true
		program_finished.emit()
		return true
	
	return false


## Steps through the program until it halts, for whatever reason.
## Returns true if the program is finished (specifically finished and not halted).
func interpret() -> bool:
	while (program_pointer < program.length()) and not (interpret_step()):
		pass
	
	return finished
