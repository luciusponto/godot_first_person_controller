@tool
extends EditorScript


func on_selection_requested(inst_id: int):
	var node = instance_from_id(inst_id)
	if node:
		var interface = get_editor_interface()
		var selection = interface.get_selection()
		selection.clear()
		selection.add_node(node)
