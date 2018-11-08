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

func _ready():
	pass

func _set_divide_by(_newval):
	if divide_by != _newval:
		divide_by = _newval
		print("Divided by %d" % divide_by)
		
func _get_divide_by():
	return divide_by
	
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

func get_vertex_from_yx_coordinates(_sqsz, _y, _x):
	return _sqsz.vertices[_y * _sqsz.x + _x]

func get_normal_from_yx_coordinates(_sqsz, _y, _x):
	return _sqsz.normals[_y * _sqsz.x + _x]

#	It adds a single square to the tile
#	_heights	is an array of arrays containing the heights of the whole tile
#				heights are represented in meters
#	_sq_y		the y coordinate of the single square
#	_sq_x		the x coordinate of the single square
#	_mt_pxl		Meters per pixel
#	_offset		the minimum height of the whole set of surfaces,
#				it simply subtracts every height
func add_single_square(_heights, sq_y : int, sq_x : int, _mt_pxl : float, _offset := 0.0):
	var sq_heights := PoolVector3Array()
	var sq_normals := PoolVector3Array()
	var sq_uvs := PoolVector3Array()
	var sq_indices := PoolIntArray()
	# if not first square we have to iterate from the previous pixels
	# so that each square is correctly joined
	var sq_heights_y_size : int = _get_square_with_size(sq_y, sq_x).y
	var sq_heights_x_size : int = _get_square_with_size(sq_y, sq_x).x
	# I need to pre store square sizes of adjacent surfaces
	var sq_11 = _get_square_with_size(sq_y-1, sq_x-1)
	var sq_01 = _get_square_with_size(sq_y, sq_x-1)
	var sq_10 = _get_square_with_size(sq_y-1, sq_x)
	# half size is used to center the geometry
	var half_y_size : float = heights_y_size*divide_by*_mt_pxl/2.0
	var half_x_size : float = heights_x_size*divide_by*_mt_pxl/2.0
	var heights_sq_x_size := float(_heights[sq_y].size())
	var heights_sq_y_size := float(_heights.size())
	var y_heights_start : int = sq_y * heights_y_size - (sq_heights_y_size - heights_y_size)
	var x_heights_start : int = sq_x * heights_x_size - (sq_heights_x_size - heights_x_size)
	var y_heights_index : float = 0
	var x_height_index : int = 0
	var index := 0

	sq_heights.resize((sq_heights_y_size)*(sq_heights_x_size))
	sq_normals.resize((sq_heights_y_size)*(sq_heights_x_size))
	sq_uvs.resize((sq_heights_y_size)*(sq_heights_x_size))
	#parsing each height belonging to the square
	for h_y in range(0,sq_heights_y_size):
		y_heights_index = y_heights_start + h_y
		# declaring variables to save processing power
		var y_heights_pos := (y_heights_index)*_mt_pxl-half_y_size
		var y_uv_pos := y_heights_index/heights_sq_y_size
		var h_y_m_size := (h_y) * (sq_heights_x_size)
		var h_y_m_size_m1 := (h_y-1) * (sq_heights_x_size)
		var h_y_m_size_m2 := (h_y-2) * (sq_heights_x_size)
		for h_x in range(0,sq_heights_x_size):
			x_height_index = x_heights_start + h_x

			#creating the vertex belonging to the MeshArray surface (the mesh is divided into divide_by * divide_by surfaces)
			sq_heights[index] = Vector3((x_height_index)*_mt_pxl-half_x_size, _heights[y_heights_index][x_height_index] - _offset, y_heights_pos)

			#Create the UVS, would be great if it could be placed only on corners of single surface
			sq_uvs[index] = Vector3(x_height_index/heights_sq_x_size, y_uv_pos, 0)

			if h_y > 0 && h_x > 0:
				# Generate the vertices indexes
				# alternating triangle drawing as follows:
				# 1-2			  2
				# |/ 	then	 /|
				# 3  	    	1-3
				# or
				# 1				1-2
				# |\	then	 \|
				# 3-2	    	  3
				if (h_x % 2 != 0 && h_y % 2 != 0) \
					|| (h_x % 2 == 0 && h_y % 2 == 0):
					sq_indices.append(h_y_m_size_m1 + h_x-1)
					sq_indices.append(h_y_m_size_m1 + h_x)
					sq_indices.append(h_y_m_size + h_x-1)
					sq_indices.append(h_y_m_size + h_x-1)
					sq_indices.append(h_y_m_size_m1 + h_x)
					sq_indices.append(h_y_m_size + h_x)
				else:
					sq_indices.append(h_y_m_size_m1 + h_x-1)
					sq_indices.append(h_y_m_size + h_x)
					sq_indices.append(h_y_m_size + h_x-1)
					sq_indices.append(h_y_m_size_m1 + h_x-1)
					sq_indices.append(h_y_m_size_m1 + h_x)
					sq_indices.append(h_y_m_size + h_x)

				# Let's try to use a proper normal calculation:
				# as we can calculate by the current vertex height plus
				# the other 4 surrounding heights, regardless vertex index
				var norm_x := Plane(sq_heights[index],
									  sq_heights[index-1],
									  sq_heights[h_y_m_size_m1 + h_x]).normal
				var norm_xp := norm_x

				var norm_a := norm_x
				var norm_b := norm_x
				var norm_c := norm_x
				var norm_d := norm_x

				if h_x > 1 && h_y > 1:
					norm_a = Plane(sq_heights[h_y_m_size_m1 + h_x-1],
									  sq_heights[h_y_m_size_m1 + h_x-2],
									  sq_heights[h_y_m_size_m2+ h_x-1]).normal
					norm_b = Plane(sq_heights[h_y_m_size_m1 + h_x-1],
									  sq_heights[h_y_m_size_m2 + h_x-1],
									  sq_heights[h_y_m_size_m1 + h_x]).normal
					norm_c = Plane(sq_heights[h_y_m_size_m1 + h_x-1],
									  sq_heights[h_y_m_size_m1 + h_x],
									  sq_heights[index-1]).normal
					norm_d = Plane(sq_heights[h_y_m_size_m1 + h_x-1],
									  sq_heights[h_y_m_size + h_x-1],
									  sq_heights[h_y_m_size_m1 + h_x-2]).normal
					norm_xp = (norm_a + norm_b + norm_c + norm_d).normalized()
				elif h_x > 1 && h_y == 1:
					norm_a = Plane(sq_heights[index-1],
									  sq_heights[index-2],
									  sq_heights[h_y_m_size_m1 + h_x-1]).normal
					norm_b = Plane(sq_heights[h_y_m_size_m1 + h_x-1],
									  sq_heights[h_y_m_size_m1 + h_x],
									  sq_heights[index-1]).normal
					norm_xp = (norm_a + norm_b).normalized()
				elif h_x == 1 && h_y > 1:
					norm_a = Plane(sq_heights[h_y_m_size_m1 + h_x],
									  sq_heights[h_y_m_size_m1 + h_x-1],
									  sq_heights[h_y_m_size_m2 + h_x-1]).normal
					norm_b = Plane(sq_heights[h_y_m_size_m1 + h_x-1],
									  sq_heights[h_y_m_size_m1 + h_x],
									  sq_heights[index-1]).normal
					norm_xp = (norm_a + norm_b).normalized()

				# here we manage normals depending on the case:
				# top left corner
				if h_y == 1 && h_x == 1:
					if sq_y > 0:
						sq_normals[0] = get_normal_from_yx_coordinates(sq_10, sq_10.y-1, sq_10.x-1)
						sq_normals[1] = get_normal_from_yx_coordinates(sq_10, sq_10.y-1, 1)
					if sq_y > 0 && sq_x > 0:
						sq_normals[0] = get_normal_from_yx_coordinates(sq_11, sq_11.y-1, sq_11.x-1)
					else:
						sq_normals[0] = norm_xp
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
					sq_normals[h_y_m_size_m1 + h_x-1] = norm_xp

			index += 1
	return {heights=sq_heights, normals=sq_normals, indices=sq_indices, uv=sq_uvs}

#	This function should convert the single array into groups of arrays 
#	each group is an 8th in width and height
#	heights should also be a square with a 2^x value, and a minimum size of 8x8
#	Ie. 8, 16, 32, 64, etc.
func heights_to_squares_array(_heights := Array(), _mat := Material.new(), _mtpxl := 1.0, _offset := 0.0):
	var startt := float(OS.get_ticks_msec())
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
			heights_squares[sq_y][sq_x] = add_single_square(_heights, sq_y, sq_x, _mtpxl, _offset)
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
