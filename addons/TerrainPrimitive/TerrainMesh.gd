tool
extends MeshInstance

export(Texture) var HeightMap setget _setHeightMap, _getHeightMap
export(bool) var AddCollision setget _setCollision
var arrayMeshHelper : = load("res://addons/TerrainPrimitive/ArrayMeshHelper.gd")
var ni = load("res://addons/TerrainPrimitive/NoiseInterpreter.gd").new()

func _ready():
	pass
	
func textureChanged(_texture):
	print("texture parameter changed, refreshing...")
	_set_new_hm()

func _setHeightMap(_newval):
	HeightMap = _newval
	if HeightMap != null:
		var signals = HeightMap.get_signal_connection_list("changed")
		if signals.empty():
			HeightMap.connect("changed", self, "textureChanged", [HeightMap])
		_set_new_hm()
		
func _getHeightMap():
	return HeightMap
	
func _setCollision(_newval):
	AddCollision = _newval
	if AddCollision:
		var sb = StaticBody.new()
		sb.physics_material_override = PhysicsMaterial.new()
		var coll = CollisionShape.new()
		coll.shape = ConcavePolygonShape.new()
		coll.shape.set_faces(self.mesh.get_faces())
		sb.add_child(coll)
		var tree = self.get_tree()
		var scene_root = null
		if tree != null:
			scene_root = tree.current_scene
			if scene_root == null:
				scene_root = tree.edited_scene_root
			self.add_child(sb)
			coll.set_owner(scene_root)
			sb.set_owner(scene_root)
	
func _set_new_hm():
	if HeightMap != null:
		var hm = ni.GenerateHeightMap(HeightMap)
		if self.mesh == null:
			self.mesh = arrayMeshHelper.new()
		if self.mesh.divide_by == null:
			self.mesh.divide_by = 4
		if hm != null:
			self.mesh.heights_to_squares_array(hm.heightmap, SpatialMaterial.new(), 1, hm.min_height)

	
