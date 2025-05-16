extends Node

enum Severity {
	LOW,
	MED,
	HIGH,
}

const DEF_SEV = Severity.LOW
const DEF_FILTER_SEV = Severity.LOW

static var logging_enabled := true

static var _sev_filter := {}

static func set_min_severity(caller: Object, severity: Severity):
	var script_path = caller.get_script().get_path()
	_sev_filter.set(script_path, severity)
	
static func is_enabled(caller: Object, severity: Severity) -> bool:
	if not logging_enabled:
		return false
	var path = _get_script_path(caller)
	if path.is_empty():
		return false
	var filter_severity := DEF_FILTER_SEV
	if _sev_filter.has(path):
		filter_severity = _sev_filter[path]
	else:
		_sev_filter.set(path, filter_severity)
	return severity >= filter_severity
	
static func _get_script_path(caller: Object) -> String:
	var script = caller.get_script()
	if is_instance_valid(script):
		return (script as Script).get_path()
	return ""

static func _get_script_file(caller: Object) -> String:
	var script = caller.get_script()
	if is_instance_valid(script):
		return (script as Script).get_path().get_file()
	return ""

static func warn(caller: Object, message: String) -> void:
	push_warning("See below:\n%s : %s" % [_get_script_file(caller), message])

# Log message if logging is enabled for the caller and severity
static func info(caller: Object, message: String, severity := DEF_SEV) -> void:
	if is_enabled(caller, severity):
		info_always(caller, message, severity)

# Log message
static func info_always(caller: Object, message: String, severity := DEF_SEV) -> void:
	print("%s : %s" % [_get_script_file(caller), message])		
