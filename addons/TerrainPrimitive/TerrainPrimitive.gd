tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("TerrainPrimitive", "MeshInstance", preload("res://addons/TerrainPrimitive/TerrainMesh.gd"), preload("res://addons/TerrainPrimitive/TerrainPrimitive.png"))

func _exit_tree():
	remove_custom_type("TerrainPrimitive")