extends SceneTree

var _ran: bool = false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: godot --headless --path . --script res://tests/run_one.gd -- res://tests/test_foo.gd")
		quit(2)
		return true
	var script_path: String = args[0]
	var scr: Script = load(script_path) as Script
	if scr == null or not scr.can_instantiate():
		printerr("FAIL: could not load %s" % script_path)
		quit(1)
		return true
	var suite: Variant = scr.new()
	if suite == null or not suite.has_method("run"):
		printerr("FAIL: %s must define func run(tree: SceneTree)" % script_path)
		quit(1)
		return true
	suite.call("run", self)
	return false
