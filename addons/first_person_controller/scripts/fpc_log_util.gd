class_name FPCLogUtil
extends Object

static func prepend_time(message) -> String:
	var now: String = Time.get_time_string_from_system()
	return now + " - " + message
	
	
static func print_timed(messages: Array) -> void:
	var final_message: String = ""
	for message in messages:
		final_message += str(message)
	print(prepend_time(final_message))
