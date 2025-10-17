@tool
@icon("res://addons/BFMachine/assets/BFMachine.svg")
class_name BFProgramLoader
extends EditorImportPlugin

func _get_importer_name() -> String:
    return "novadc.bfmachine"

func _get_visible_name() -> String:
    return "BF Machine"

func _get_recognized_extensions() -> PackedStringArray:
    return PackedStringArray(["bf", "brainfuck", "fuck"])

func _get_save_extension() -> String:
    return "res"

func _get_format_version() -> int:
    return 0

func _get_resource_type() -> String:
    # while not documented as of writing this,
    # Godot wants the ClassDB type, not any script defiend types.
    return "Resource"

func _get_preset_count() -> int:
    return 1

func _get_preset_name(_preset_index: int = 0) -> String:
    return "Default"

func _get_import_options(_path: String, _preset_index: int = 0) -> Array[Dictionary]:
    var scriptdata = ProjectSettings.get_global_class_list()
    scriptdata = scriptdata.filter(func(d): return d["class"] == "BFMachine")
    if scriptdata.size() != 1:
        return []
    var bfscript := load(scriptdata[0]["path"]) as Script
    if bfscript == null:
        return []
    var ret: Array[Dictionary] = bfscript.get_script_property_list()
    ret = ret.filter(func(pd): return pd["name"] not in ["program"])
    for pd in ret:
        pd["default_value"] = bfscript.get_property_default_value(pd["name"])
    ret.push_front({
        "name": "trim_begining",
        "default_value": false
    })
    return ret

func _get_option_visibility(_path: String, option_name: StringName, options: Dictionary) -> bool:
    match (str(option_name)):
        "program_pointer" when options.get("trim_begining", false):
            return false
    return true

func _import(source_file: String,
                save_path: String,
                options: Dictionary,
                _platform_variants: Array[String],
                _gen_files: Array[String]
                ) -> int:
    var bfm := BFMachine.new()

    var err := bfm.load_program_file(source_file)
    if err != OK:
        return err

    for o in options.keys():
        var value = options[o]
        match (str(o)):
            "trim_begining":
                bfm.trim_program_begining()
                bfm.program_pointer = 0
            "program_pointer" when options.get("trim_begining", false):
                if options["program_pointer"] != 0:
                    push_error("Cannot set the program pointer to anything other than the start when trimming program.")
                    return ERR_INVALID_PARAMETER
            "program":
                push_warning("Cannot set program as an option when loading BF program from a file.")
            var _ign when o in bfm:
                bfm.set(o, value)

    var filename := save_path + "." + _get_save_extension()
    return ResourceSaver.save(bfm, filename)
