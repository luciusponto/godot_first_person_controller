@tool
extends EditorScript

func on_selection_requested(inst_id: int):
	var node = instance_from_id(inst_id)
	if node:
		var interface = get_editor_interface()
		var selection = interface.get_selection()
		selection.clear()
		selection.add_node(node)


func set_selection(selected_nodes: Array[Node]):
	var interface = get_editor_interface()
	var selection = interface.get_selection()
	selection.clear()
	for node in selected_nodes:
		selection.add_node(node)	


func show_selected():
	var interface = get_editor_interface()
	for node in interface.get_selection().get_selected_nodes():
		if node is Node3D:
			var node3d := node as Node3D
			if not node3d.visible:
				node3d.visible = true


func hide_selected():
	var interface = get_editor_interface()
	for node in interface.get_selection().get_selected_nodes():
		if node is Node3D:
			var node3d := node as Node3D
			if node3d.visible:
				node3d.visible = false
