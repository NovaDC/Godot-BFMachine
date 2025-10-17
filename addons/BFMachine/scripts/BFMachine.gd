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
	ELOOP,

	## [b]A semi standard instruction.[/b] This will print out the current cells value to godot directly, instead of sending events like the [OUTPUT] opcode
	DEBUG,
	## [b]A non standard instruction.[/b] This will prematurely end the program
	## when run.
	HALT,
	## [b]A non standard instruction.[/b] This will raise an assertion [enum BFErrors].
	FAIL,
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
	RECURSION_TIMEOUT,
	## Raised specifically when [constant BFOpcodes.FAIL] is run.
	INSTRUCTED_FAILURE
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
## The amount of cells to print (boht before and after) the current cell when debuging.
@export var debug_print_cell_count := 3
#region Output
## Settings related the machine's output.
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

# Used to normalize a file kind of paramiter into either a [FileAccess] object
# a [Error] value if nnot possible or an error was encountered.
# This will also ensure that provided [FileAccess] instances are always [method FileAccess.seek]ed
# to the start of the file.
# with errors form this process also being returned if this fails.
static func _simple_open(ref: Variant) -> Variant:
	if typeof(ref) == TYPE_OBJECT:
		ref = ref as FileAccess
		if ref == null:
			return ERR_INVALID_PARAMETER
		if not ref.is_open():
			return ERR_CANT_OPEN
		#seek back to the start and also refresh the last stored error
		ref.seek(0)
		if ref.get_error() != OK:
			return ref.get_error()
		return ref
	if typeof(ref) in [TYPE_STRING, TYPE_STRING_NAME]:
		if not FileAccess.file_exists(ref):
			return ERR_FILE_NOT_FOUND

		var fileobj = FileAccess.open(ref, FileAccess.READ)
		if fileobj == null:
			if Engine.get_singleton("FileAccess").has_method("get_open_error"):
				return Engine.get_singleton("FileAccess").call("get_open_error")
			if fileobj.get_error() != OK:
				return fileobj.get_error()
			return FAILED
		return fileobj


	return ERR_INVALID_PARAMETER
func load_tape_csv_file(file: Variant,
						delim := ",",
						line_index_start: int = 0,
						line_index_end: int = -1,
						decode_str: Callable = str_to_var
						) -> int:
	var fileobj = _simple_open(file)
	if typeof(fileobj) == TYPE_INT:
		return fileobj
	fileobj = fileobj as FileAccess

	var loaded := PackedStringArray()

	var line_index: int = 0
	if line_index_start > 0:
		# then its faster to discard parsed lines then store them all just to be sliced away later on
		while fileobj.get_position() < fileobj.get_length() and line_index < line_index_start:
			fileobj.get_line()
			if fileobj.get_error() != OK:
				return fileobj.get_error()
			line_index += 1
	while (fileobj.get_position() < fileobj.get_length() and
			(line_index_end < 0 or line_index < line_index_end)
			):
		var line := PackedStringArray()
		if not delim.is_empty():
			line = fileobj.get_csv_line(delim)
		else:
			line = fileobj.get_line()
		if fileobj.get_error() != OK:
			return fileobj.get_error()
		loaded.append_array(line)
		line_index += 1
	if line_index_start < 0 or line_index_end < 0:
		if line_index_start > 0:
			# then we already pre-sliced these, so the end and start need to be offset by the
			# pre-sliced line count (which is the exact value already in line_index_start)
			line_index_end -= sign(line_index_end) * line_index_start
			line_index_start = 0
		loaded = loaded.slice(line_index_start, line_index_end)

	tape = Array(loaded).map(decode_str)
	return OK

func load_tape_binary_file(file: Variant,
							bit_size: int = 0,
							floating := false,
							signed := false,
							start_index: int = 0,
							end_index: int = -1
							) -> int:
	var fileobj = _simple_open(file)
	if typeof(fileobj) == TYPE_INT:
		return fileobj
	fileobj = fileobj as FileAccess

	# [FileAccess] doesn't have getting methods that decern signed and unsigned
	# int types for every int size
	# unlike a PackedByteArray, so lets just pass the files content through
	var bin:PackedByteArray = fileobj.get_buffer(fileobj.get_length())
	if fileobj.get_error() != OK:
		return fileobj.get_error()

	return load_tape_raw_bytes(bin, bit_size, floating, signed, start_index, end_index)


func load_tape_raw_bytes(bytes: PackedByteArray,
							bit_size: int = 0,
							floating := false,
							signed := false,
							start_index: int = 0,
							end_index: int = -1
							) -> int:
	bytes = bytes.slice(start_index, end_index)

	if not signed and floating:
		# godot (an most engines) don't support unsigned floats
		return ERR_METHOD_NOT_FOUND

	var method_name:StringName = ""
	if bit_size < 0:
		return ERR_PARAMETER_RANGE_ERROR
	elif bit_size == 0:
		method_name = "decode_real" if floating else "get"
	else:
		if not floating:
			method_name = "decode_{0}{1}".format(["s" if signed else "u", bit_size])
			if not ClassDB.class_has_method("PackedByteArray", method_name, false):
				if bit_size == 8:
					# we know that 8 bit unsigned values are also always given by the getter for byte arrays...
					method_name = "get"
				else:
					method_name = ""
		else:
			const BIT_SIZE_TO_NAME := {
				16: "half",
				32: "float",
				64: "double",
			}
			if bit_size in BIT_SIZE_TO_NAME.keys():
				method_name = "decode_{0}".format([BIT_SIZE_TO_NAME[bit_size]])
				if not ClassDB.class_has_method("PackedByteArray", method_name, false):
					method_name = ""

	if method_name.is_empty():
		return ERR_METHOD_NOT_FOUND

	var offset:int = 0
	var method := Callable.create(bytes, method_name)

	var byte_size:int = maxi(floori(bit_size/8), 1)

	if bytes.size() % byte_size != 0:
		return ERR_PARAMETER_RANGE_ERROR

	tape = []
	while offset < bytes.size():
		tape.append(method.call(offset))
		offset += byte_size

	return OK

func load_program_file(file: Variant, skip_cr := false) -> int:
	file = _simple_open(file)
	if typeof(file) == TYPE_INT:
		return file
	file = file as FileAccess

	var content:String = file.get_as_text(skip_cr)
	if file.get_error() != OK:
		return file.get_error()

	program = content
	return OK


func reset_machine_states():
	tape = []
	last_exception_encountered = BFErrors.NON_ERROR
	loop_level = 0
	recursion_timeout_count = 0
	output = []
	finished = false
	paused = false
	exception_encountered = false
	tape_pointer = 0
	program_pointer = 0


func trim_program_begining() -> bool:
	var hypothetical := copy()
	hypothetical.reset_machine_states()

	var modified_first_point := 0
	while (hypothetical.interpret_step() and
			hypothetical.tape.is_empty() and
			not hypothetical.paused and
			not hypothetical.exception_encountered
			):
		# the value of program_pointer will be right after
		# the last character of the last interprited instruction when run
		modified_first_point = hypothetical.program_pointer

	if modified_first_point > 0:
		program = program.substr(modified_first_point)
		return true
	return false


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
static func run_program_file(file:Variant, tape := [], machine:BFMachine = null) -> Array:
	if machine == null:
		machine = BFMachine.new()
	else:
		machine = machine.copy()

	machine.program = ""
	machine.load_program_file(file)
	machine.tape = tape

	machine.interpret()

	return [machine.output, machine.tape]


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
		BFOpcodes.HALT:
			finish()
			if step_pointer: inc_instruction()
		BFOpcodes.FAIL:
			raise_BF_error(BFErrors.INSTRUCTED_FAILURE)
			if step_pointer: inc_instruction()
		BFOpcodes.DEBUG:
			print(tape[tape_pointer])
			if step_pointer: inc_instruction()
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

func finish():
	finished = true
	program_finished.emit()

## Steps through the [member program] once.
## Returns true if the [member program] is halted before or after this step was executed.
func interpret_step() -> bool:
	if exception_encountered or paused or finished:
		return true
	
	interpret_instruction(pointed_instruction(), true)
	stepped.emit() #Emit the stepped signal after each program step
	
	if program_pointer >= program.length() and not exception_encountered:
		finish()
		return true
	
	return exception_encountered or paused


## Steps through the [member program] until it halts, for whatever reason.
## Returns true if the program is [member finished]
## (specifically [member finished] and not any other form of halt).
func interpret() -> bool:
	while (program_pointer >= 0 and program_pointer < program.length()) and not (interpret_step()):
		pass
	
	return finished
