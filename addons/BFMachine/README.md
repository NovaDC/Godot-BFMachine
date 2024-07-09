# BFMachine

BFMachine is a simple BF interpreter for Godot 4. It is a single file ``Resource`` that holds the entire state of the machine inside it, and a single scene that gives that interpreter a ui, so it can run in editor. Its also flexible, allowing for you to change settings on the fly, if you so choose. As this script is fully documented in Godot, you can refer to that for more detailed information on each setting and function.

## Features

* **In Engine Execution**: Run and edit BF programs right in the Godot editor!
* **Customizable Dialects**: Redefine the traditional BF commands to anything you want, making this compatable with many other BF language vairants
* **Program Execution**: Execute BF programs step by step with the ability to pause, resume, or halt.
* **Exception Handling**: Detect and handle errors such as unclosed loops or tape pointer out-of-range situations.
