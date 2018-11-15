tool
extends CSGMesh

export(Texture) var HeightMap setget _setHeightMap, _getHeightMap
var arrayMeshHelper : = load("res://addons/TerrainPrimitive/ArrayMeshHelper.gd")
var ni = load("res://addons/TerrainPrimitive/NoiseInterpreter.gd").new()

func _ready():
	pass

func textureChanged(_texture):
	print("have you changed texture?")
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

func _set_new_hm():
	if HeightMap != null:
		var hm = ni.GenerateHeightMap(HeightMap)
		if self.mesh == null:
			self.mesh = arrayMeshHelper.new()
		if self.mesh.divide_by == null:
			self.mesh.divide_by = 4
		if hm != null:
			self.mesh.heights_to_squares_array(hm.heightmap, SpatialMaterial.new(), 1, hm.min_height)


