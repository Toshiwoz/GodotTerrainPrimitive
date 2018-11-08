tool
extends MeshInstance

export(Texture) var HeightMap setget _setHeightMap, _getHeightMap
var arrayMeshHelper : = load("res://addons/TerrainPrimitive/ArrayMeshHelper.gd")

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
		var hm = GenerateHeightMap(HeightMap)
		if self.mesh == null:
			self.mesh = arrayMeshHelper.new()
		if self.mesh.divide_by == null:
			self.mesh.divide_by = 4
		if hm != null:
			self.mesh.heights_to_squares_array(hm.heightmap, SpatialMaterial.new(), 1, hm.min_height)

	
func GenerateHeightMap(_hm_texture : Texture):
	var hm := Array()
	var minh := 999999.0
	var maxh := -1.0
	var _hm_img : Image = _hm_texture.get_data()
	if _hm_img != null && !_hm_img.is_empty():
		var startt := float(OS.get_ticks_msec())
		var TerrainImage = _hm_img
		TerrainImage.lock()
		var width = TerrainImage.get_width()
		var heigth = TerrainImage.get_height()
		var rangeX := range(width)
		var rangeY := range(heigth)
		var pxl := Color()
		var altitude := 0.0
		hm.resize(heigth)
		for y in rangeY:
			var x_arr := Array()
			x_arr.resize(width)
			for x in rangeX:
				pxl = TerrainImage.get_pixel(x, y)
				altitude = (pxl.r8 + pxl.g8 + pxl.b8) / 10.0
				x_arr[x] =  altitude
				if altitude < minh:
					minh = altitude
				if altitude > maxh:
					maxh = altitude
			hm[y] = x_arr
		TerrainImage.unlock()
		var endtt = float(OS.get_ticks_msec())
		print("Heightmap of"
		+ " W/H: " + var2str(width) + "/" + var2str(heigth) 
		+ ", Min/Max height: " + var2str(minh) + "/" + var2str(maxh)
		+ " generated in %.2f seconds" % ((endtt - startt)/1000.0))
	return {heightmap = hm, min_height = minh, max_height = maxh}