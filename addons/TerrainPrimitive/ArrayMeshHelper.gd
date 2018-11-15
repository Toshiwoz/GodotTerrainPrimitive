tool
extends ArrayMesh
#export(Array) var heights setget _set_heights

# The number of times a tile is subdivided
# it should always be in form of 2^x
# i.e. 2, 4, 8, 16, 32, etc.
export(int) var divide_by = 4 setget _set_divide_by, _get_divide_by

# the size of a single square
var heights_y_size = 0
var heights_x_size = 0
var heights_array := Array()

func _ready():
	pass

func _set_divide_by(_newval):
	if divide_by != _newval:
		divide_by = _newval
		print("Divided by %d" % divide_by)
		
func _get_divide_by():
	return divide_by

#	This function should convert the single array into groups of arrays 
#	each group is an 8th in width and height
#	heights should also be a square with a 2^x value, and a minimum size of 8x8
#	Ie. 8, 16, 32, 64, etc.
func heights_to_squares_array(_heights := Array(), _mat := Material.new(), _mtpxl := 1.0, _offset := 0.0):
	var startt := float(OS.get_ticks_msec())
	heights_array = _heights
	heights_y_size = _heights.size()/divide_by
	if _heights.size() > 0:
		heights_x_size = _heights[0].size()/divide_by
	# Clean up the previous mesh
	while self.get_surface_count() > 0:
		surface_remove(get_surface_count()-1)
	# Passed to property so that is globally visible
	# Always declare first the divide_by property
	# as it is used to calculate the square size
	# use self. as otherwise setget won't work
	self.divide_by = divide_by
#	self.heights = _heights
	var heights_squares := Array()
	heights_squares.resize(divide_by)
	#parsing each of the divide_by squares
	for sq_y in range(divide_by):
		heights_squares[sq_y] = Array()
		heights_squares[sq_y].resize(divide_by)
		for sq_x in range(divide_by):
			#append the fan to the squares array
			heights_squares[sq_y][sq_x] = add_single_square(sq_y, sq_x, _mtpxl, _offset)
			if heights_squares[sq_y][sq_x] == null:
				print("Array empty, aborting...")
				return
				
			var mesh_array := Array()
			mesh_array.resize(ArrayMesh.ARRAY_MAX)
			mesh_array[ArrayMesh.ARRAY_VERTEX] = heights_squares[sq_y][sq_x].heights
			mesh_array[ArrayMesh.ARRAY_NORMAL] = heights_squares[sq_y][sq_x].normals
			mesh_array[ArrayMesh.ARRAY_INDEX] = heights_squares[sq_y][sq_x].indices
			mesh_array[ArrayMesh.ARRAY_TEX_UV] = heights_squares[sq_y][sq_x].uv
			add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
			var surfidx = get_surface_count()-1
			var surfname = var2str(sq_y)+"|"+var2str(sq_x)
#			surface_set_material(surfidx, _mat)
			surface_set_name(surfidx, surfname)
	var endtt = float(OS.get_ticks_msec())
	print("Squares of heights generated in %.2f seconds" % ((endtt - startt)/1000.0))
	return heights_squares

#	It adds a single square to the tile
#	_heights	is an array of arrays containing the heights of the whole tile
#				heights are represented in meters
#	_sq_y		the y coordinate of the single square
#	_sq_x		the x coordinate of the single square
#	_mt_pxl		Meters per pixel
#	_offset		the minimum height of the whole set of surfaces,
#				it simply subtracts every height
func add_single_square(sq_y : int, sq_x : int, _mt_pxl : float, _offset := 0.0):
	if heights_array.size() == 0:
		print("Height map is empty")
		return null
		
	var sq_heights := PoolVector3Array()
	var sq_normals := PoolVector3Array()
	var sq_uvs := PoolVector2Array()
	var sq_indices := PoolIntArray()
	# if not first square we have to iterate from the previous pixels
	# so that each square is correctly joined
	var sq_heights_y_size : int = _get_square_with_size(sq_y, sq_x).y
	var sq_heights_x_size : int = _get_square_with_size(sq_y, sq_x).x
	# I need to pre store square sizes of adjacent surfaces
	var sq_11 = _get_square_with_size(sq_y-1, sq_x-1)
	var sq_01 = _get_square_with_size(sq_y, sq_x-1)
	var sq_10 = _get_square_with_size(sq_y-1, sq_x)
	var sqp_11 = null
	var sqp_01 = null
	var sqp_10 = null
	if(sq_y < divide_by && sq_x < divide_by):
		sqp_11 = _get_square_with_size(sq_y+1, sq_x+1)
	if(sq_x < divide_by):
		sqp_01 = _get_square_with_size(sq_y, sq_x+1)
	if(sq_y < divide_by):
		sqp_10 = _get_square_with_size(sq_y+1, sq_x)
		
	# half size is used to center the geometry
	var half_y_size : float = heights_y_size*divide_by*_mt_pxl/2.0
	var half_x_size : float = heights_x_size*divide_by*_mt_pxl/2.0
	var heights_sq_x_size := float(heights_array[sq_y].size())
	var heights_sq_y_size := float(heights_array.size())
	var y_heights_start : int = sq_y * heights_y_size - (sq_heights_y_size - heights_y_size)
	var x_heights_start : int = sq_x * heights_x_size - (sq_heights_x_size - heights_x_size)
	var y_heights_index : float = 0
	var x_height_index : int = 0
	var index := 0
	var vertex_index = 0
	var py1 := 1

	sq_heights.resize(sq_heights_y_size*sq_heights_x_size)
	sq_normals.resize(sq_heights_y_size*sq_heights_x_size)
	sq_uvs.resize(sq_heights_y_size*sq_heights_x_size)
	var last_x = -1
	var last_y = -1
	
	if sq_y > 0:
		last_y = -1
	elif sq_y >= divide_by-1:
		last_y = 0
		
	if sq_x > 0:
		last_x = -1
	elif sq_x >= divide_by-1:
		last_x = 0
		
	sq_indices.resize((sq_heights_y_size + last_y)*(sq_heights_x_size + last_x) * 6)
	#parsing each height belonging to the square
	for h_y in range(0,sq_heights_y_size):
		y_heights_index = y_heights_start + h_y
		# declaring variables to save processing power
		var y_heights_pos := (y_heights_index)*_mt_pxl-half_y_size
		var y_uv_pos := y_heights_index/heights_sq_y_size
		var h_y_m_size := (h_y) * (sq_heights_x_size)
		var h_y_m_size_m1 := (h_y-1) * (sq_heights_x_size)
#		var h_y_m_size_m2 := (h_y-2) * (sq_heights_x_size)
		var px1 := 1
		if y_heights_index == heights_sq_y_size - 1:
			py1 = 0
		for h_x in range(0,sq_heights_x_size):
			x_height_index = x_heights_start + h_x
			if x_height_index == heights_sq_x_size - 1:
				px1 = 0
			#creating the vertex belonging to the MeshArray surface (the mesh is divided into divide_by * divide_by surfaces)
			sq_heights[index] = Vector3((x_height_index)*_mt_pxl-half_x_size, heights_array[y_heights_index][x_height_index] - _offset, y_heights_pos)

			#Create the UVS, would be great if it could be placed only on corners of single surface
			sq_uvs[index] = Vector2(x_height_index/heights_sq_x_size, y_uv_pos)

			if h_y > 0 && h_x > 0:
				# Generate the vertices indexes
				# alternating triangle drawing as follows:
				# 1-2        2
				# |/  then  /|
				# 3        1-3
				# or
				# 1        1-2
				# |\  then  \|
				# 3-2        3
				var p_m10 = h_y_m_size_m1 + h_x
				var p_m11 = p_m10-1
				var p_m00 = h_y_m_size + h_x
				var p_m01 = p_m00-1
				var norm_x := Vector3()
#				var norm_xa := Vector3()
				if (h_x % 2 != 0 && h_y % 2 != 0) \
					|| (h_x % 2 == 0 && h_y % 2 == 0):
					sq_indices.set(vertex_index, p_m11)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m10)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m01)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m01)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m10)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m00)
					vertex_index += 1
#					norm_xa = Plane(sq_heights[p_m11],
#									  sq_heights[p_m10],
#									  sq_heights[p_m01]).normal
#					norm_x = Plane(sq_heights[p_m01],
#									  sq_heights[p_m10],
#									  sq_heights[p_m00]).normal
				else:
					sq_indices.set(vertex_index, p_m11)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m00)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m01)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m11)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m10)
					vertex_index += 1
					sq_indices.set(vertex_index, p_m00)
					vertex_index += 1
#					norm_xa = Plane(sq_heights[p_m11],
#									  sq_heights[p_m00],
#									  sq_heights[p_m01]).normal
#					norm_x = Plane(sq_heights[p_m11],
#									  sq_heights[p_m10],
#									  sq_heights[p_m00]).normal
#				sq_normals[p_m01] = (sq_normals[p_m01]+norm_x+norm_xa).normalized()
#				sq_normals[p_m10] = (sq_normals[p_m10]+norm_x+norm_xa).normalized()

				norm_x = calculate_normal_from_Heights8(_mt_pxl, y_heights_index, x_height_index, py1, px1)
				
				# here we manage normals depending on the case:
				# top left corner
				if h_y == 1 && h_x == 1:
					if sq_y > 0:
						sq_normals[0] = get_normal_from_yx_coordinates(sq_10, sq_10.y-1, sq_10.x-1)
						sq_normals[1] = get_normal_from_yx_coordinates(sq_10, sq_10.y-1, 1)
					if sq_y > 0 && sq_x > 0:
						sq_normals[0] = get_normal_from_yx_coordinates(sq_11, sq_11.y-1, sq_11.x-1)
					else:
						sq_normals[0] = norm_x
					sq_normals[index] = norm_x
				# top border (excluding the corner)
				elif h_y == 1 && h_x > 1:
					if sq_y > 0:
						sq_normals[h_x] = get_normal_from_yx_coordinates(sq_10, sq_10.y-1, h_x)
					else:
						sq_normals[h_x] = norm_x
					sq_normals[index] = norm_x
				# left border(excluding the corner)
				elif h_y > 1 && h_x == 1:
					if sq_x > 0:
						sq_normals[h_y_m_size_m1] = get_normal_from_yx_coordinates(sq_01, h_y-1, sq_01.x -1)
						if h_y == sq_heights_y_size - 1:
							sq_normals[h_y_m_size] = get_normal_from_yx_coordinates(sq_01, sq_01.y -1, sq_01.x -1)
					else:
						sq_normals[h_y_m_size_m1] = norm_x
					sq_normals[index] = norm_x
				# all other cases
				else:
					sq_normals[index] = norm_x

			index += 1
	return {heights=sq_heights, normals=sq_normals, indices=sq_indices, uv=sq_uvs}
	
func _get_square_with_size(_sqy, _sqx):
	var vtxs = null
	var nrmls = null
	if get_surface_count() > (_sqy * divide_by + _sqx) && (_sqy * divide_by + _sqx) >= 0:
		vtxs = surface_get_arrays(_sqy * divide_by + _sqx)[ArrayMesh.ARRAY_VERTEX]
		nrmls = surface_get_arrays(_sqy * divide_by + _sqx)[ArrayMesh.ARRAY_NORMAL]
	var y_sq_not_first = 0
	var x_sq_not_first = 0
	if _sqy > 0:
		y_sq_not_first = 1
	if _sqx > 0:
		x_sq_not_first = 1

	return {vertices = vtxs, normals = nrmls, y = heights_y_size + y_sq_not_first, x = heights_x_size + x_sq_not_first}

func calculate_normal_from_Heights(_mt_pxl, _y, _x, _py1, _px1) -> Vector3:
	return Vector3(
					heights_array[_y][_x - 1] - heights_array[_y][_x + _px1],
					_mt_pxl * 2,
					heights_array[_y - 1][_x] - heights_array[_y + _py1][_x]
					).normalized()
	
func calculate_normal_from_Heights8(_mt_pxl, _y, _x, _py1, _px1) -> Vector3:
	var x = Vector3(
					heights_array[_y - 1][_x - 1] - heights_array[_y + _py1][_x + _px1],
					_mt_pxl * 2.0,
					heights_array[_y - 1][_x + _px1] - heights_array[_y + _py1][_x - 1]
					)
	var t = Vector3(
					heights_array[_y][_x - 1] - heights_array[_y][_x + _px1],
					_mt_pxl * 2.0,
					heights_array[_y - 1][_x] - heights_array[_y + _py1][_x]
					)
	return (t+x).normalized()
	
func calculate_normal_from_Heightsm(_mt_pxl, _y, _x, _py1, _px1) -> Vector3:
	var x = Vector3(
					(heights_array[_y - 1][_x - 1] - heights_array[_y + _py1][_x + _px1])/heights_array[_y][_x],
					_mt_pxl * 2.0,
					(heights_array[_y - 1][_x + _px1] - heights_array[_y + _py1][_x - 1])/heights_array[_y][_x]
					)
	var t = Vector3(
					(heights_array[_y][_x - 1] - heights_array[_y][_x + _px1])/heights_array[_y][_x],
					_mt_pxl * 2.0,
					(heights_array[_y - 1][_x] - heights_array[_y + _py1][_x])/heights_array[_y][_x]
					)
	return ((t+x)).normalized()
	
func calculate_normal_from_Heightss(_mt_pxl, _y, _x, _py1, _px1) -> Vector3:
	var l = Vector3(-_mt_pxl, heights_array[_y][_x-1] - heights_array[_y][_x], 0)
	var tl = Vector3(-_mt_pxl, heights_array[_y-1][_x-1] - heights_array[_y][_x], -_mt_pxl)
	var t = Vector3(0, heights_array[_y-1][_x] - heights_array[_y][_x], -_mt_pxl)
	var tr = Vector3(_mt_pxl, heights_array[_y-1][_x+_px1] - heights_array[_y][_x], _mt_pxl)
	var r = Vector3(_mt_pxl, heights_array[_y][_x+_px1] - heights_array[_y][_x], 0)
	var br = Vector3(_mt_pxl, heights_array[_y+_py1][_x+_px1] - heights_array[_y][_x], _mt_pxl)
	var b = Vector3(0, heights_array[_y+_py1][_x] - heights_array[_y][_x], _mt_pxl)
	var bl = Vector3(-_mt_pxl, heights_array[_y+_py1][_x-1] - heights_array[_y][_x], _mt_pxl)
	var n1 = l.cross(tl)
	var n2 = tl.cross(t)
	var n3 = t.cross(tr)
	var n4 = tr.cross(r)
	var n5 = r.cross(br)
	var n6 = br.cross(b)
	var n7 = b.cross(bl)
	var n8 = bl.cross(l)
	return -(n1+n2+n3+n4+n5+n6+n7+n8).normalized()
	
func get_vertex_from_yx_coordinates(_sqsz, _y, _x):
	return _sqsz.vertices[_y * _sqsz.x + _x]

func get_normal_from_yx_coordinates(_sqsz, _y, _x):
	return _sqsz.normals[_y * _sqsz.x + _x]
	
#	this is not working yet
func _array_to_normalmap(_normals := PoolVector3Array(), _width := 256):
	var nmap = Image.new()
	nmap.create(_width, _normals.size()/_width, false, Image.FORMAT_RG8)
	nmap.lock()
	for hy in range(0,_normals.size()/_width):
		for hx in range(0,_width):
			nmap.set_pixel(hx, hy, Color(_normals[hy*_width+hx].x,_normals[hy*_width+hx].y,0.0))
	nmap.unlock()
	return nmap
