@tool
extends Control

@onready var json_converted=load("res://addons/FancyControls/GUI/converters/json_visual_converter.gd").new()



func _input(event):
	if visible and event is InputEventKey and event.is_pressed() and event.ctrl_pressed and String(self.get_path_to(get_tree().root.gui_get_focus_owner())).begins_with("."):
		accept_event()

func _on_tab_bar_tab_selected(tab):
	$Box/MainBox.visible=tab==0
	$Box/CodeBox.visible=tab==1
	$Box/GroupsBox.visible=tab==2
	if tab==1:
		$Box/CodeBox.reload_codeview()


func _on_save_button_pressed():
	if $Box/TopBar/Label.text=="":
		$Box/TopBar/Label.grab_focus()
		return
	if FileAccess.file_exists("res://FACS/Editor/%s.FACSVis"%$Box/TopBar/Label.text):
		$ConfirmationDialog.visible=true
		
		return
	_save_confirmed()
func _save_confirmed():
	var converted_json=json_converted.convert_tree($Box/MainBox/BlockUI)
	var path_used="res://FACS/Editor/%s.FACSVis"%$Box/TopBar/Label.text
	var file=FileAccess.open(path_used,FileAccess.WRITE)
	var stored_data=JSON.stringify(converted_json).to_utf8_buffer()
	#i love compression
	var compressed_data=stored_data.compress(FileAccess.COMPRESSION_GZIP)
	var decompressed_size=len(stored_data)
	compressed_data.resize(len(compressed_data)+4)
	compressed_data.encode_s32(len(compressed_data)-4,decompressed_size)
	file.store_buffer(compressed_data)
	file.close()
	
	EditorInterface.get_resource_filesystem().update_file(path_used)
	EditorInterface.get_resource_filesystem().reimport_files(PackedStringArray([path_used]))
	


func _on_load_button_pressed():
	$ChainLoadDialog.visible=true



func _on_chain_load_dialog_file_selected(path):
	$Box/TopBar/Label.text=Array(path.split("/")).back().trim_suffix(".FACSVis")
	if not FileAccess.file_exists(path):return
	
	for child in $Box/MainBox/BlockUI.get_children():
		if child.name=="StartNode":continue
		if child.name=="StartContainerNode":continue
		$Box/MainBox/BlockUI.remove_child(child)
		child.queue_free()
	$Box/MainBox/BlockUI.clear_connections()
	await get_tree().process_frame
	var file=FileAccess.open(path,FileAccess.READ)
	#decompress the file, the last 4 bytes are listing how big it should be after decompression
	var buffer=file.get_buffer(file.get_length())
	var buffer_size=buffer.decode_s32(len(buffer)-4)
	buffer.resize(len(buffer)-4)
	buffer=buffer.decompress(buffer_size,FileAccess.COMPRESSION_GZIP)
	var file_text=buffer.get_string_from_utf8()
	
	
	json_converted.convert_json(
		JSON.parse_string(file_text),
		$Box/MainBox/BlockUI,
		$Box/MainBox/VBoxContainer/BlockList
	)
	file.close()
