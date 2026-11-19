class_name TestAssert
extends RefCounted

var failures: Array[String] = []
var checks: int = 0


func eq(actual: Variant, expected: Variant, label: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func is_true(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: expected true" % label)


func approx(actual: float, expected: float, eps: float, label: String) -> void:
	checks += 1
	if absf(actual - expected) > eps:
		failures.append("%s: expected ~%.4f, got %.4f" % [label, expected, actual])


func finish(tree: SceneTree, suite_name: String) -> void:
	if failures.is_empty():
		print("PASS [%s]: %d checks" % [suite_name, checks])
		tree.quit(0)
	else:
		printerr("FAIL [%s]: %d/%d failed" % [suite_name, failures.size(), checks])
		for f: String in failures:
			printerr("  - " + f)
		tree.quit(1)
