extends Node

var id = "TreeManager"
var enabled setget tm_enable
var tree
export(NodePath) var tree_path

export(bool) var enable_lodmanager = true
export(bool) var enable_areamanager = true
export(bool) var enable_boxmesh = true
export(bool) var enable_hboxsetlod = true #set lod values for lod manager based on hitbox of mesh
export(float) var lod_aspect_ratio = 10  setget set_lod_aspect_ratio #lod set as projection of hitbox * aspect_ratio

export(NodePath) var LodManager
var scripts = {
	MeshTool = preload("res://scripts/MeshTool.gd"),
	TreeStats = preload("res://scripts/TreeStats.gd")
}
var MeshTool
var TreeStats

export(bool) var debug = false
func printd(s):
	if debug:
		print(s)

#Set root path to manage mesh instances below
func set_path():
	pass

# generate id of a tree mased on timestamps of all files
# do not detect runtime generated changes
func tree_id():
	var id
	if TreeStats:
		id = TreeStats.id_tree()
	return id

func _process(delta):
	#check active camera for the positions
	#call all other managers with new position
	pass

func hboxsetlod(node, children = true):
	var size = 0
	if node is MeshInstance:
		MeshTool.mesh = node
		size += MeshTool.hbox_surface_projection()
	if children:
		for path in utils.get_nodes(node, true):
			size += hboxsetlod(node.get_node(path), true)
	if node.is_class("MeshInstance") and size > 0:
		# do not set lod if it set manually
		if node.lod_min_distance == 0 and node.lod_max_distance == 0:
			node.lod_max_distance = lod_aspect_ratio * sqrt(size)
			printd("%s lod(%s) aspect(%s) size(%s) " % [node, node.lod_max_distance, lod_aspect_ratio, size])
	return size

func set_lod_aspect_ratio(value):
	if value > 0:
		lod_aspect_ratio = value
	if not enabled:
		return
	if enable_hboxsetlod:
		hboxsetlod(tree)
	if enable_lodmanager and get_node(LodManager):
		var lm = get_node(LodManager)
		lm.UpdateLOD()

func enable_managment():
	if tree == null:
		print("TreeManagment faield to enable, tree is not set")
		return false
	print("TreeManagment enable")
	if enable_hboxsetlod:
		printd("TM start hboxsetlod at %s" % tree.get_path())
		hboxsetlod(tree)
	if enable_lodmanager and get_node(LodManager):
		var lm = get_node(LodManager)
		printd("found LodManager at %s" % lm.get_path())
		lm.enabled = false
		lm.scene_path = lm.get_path_to(tree)
		lm.enabled = true
	else:
		print("LodManager disabled: %s %s" % [enable_lodmanager, LodManager])
		var lm = get_node(LodManager)
		lm.enabled = false

func disable_managment():
	print("TreeManagment disable")
	if get_node(LodManager):
		var lm = get_node(LodManager)
		lm.enabled = false
		printd("Disable LodManager %s" % lm.get_path())

func init_tree():
	print("Init Tree manager")
	if tree == null:
		if get_tree():
			tree = get_tree().current_scene
			printd("tree set to get_tree: %s" % tree)
	printd("=tree: %s" % tree)
	if tree:
		printd("Init meshtool and treestats scripts")
		MeshTool = scripts.MeshTool.new(tree)
		TreeStats = scripts.TreeStats.new(tree)

func _ready():
	printd("TreeManager _ready")
	if enabled:
		init_tree()
		enable_managment()

func tm_enable(enable):
	printd("Tree manager tm_enable (%s, %s)" % [enable, enabled])
	if tree == null and enable:
		init_tree()
		if tree == null:
			printd("Tree manager can't set tree, disabled")
			enabled = null
			return
		enabled = false
	if tree == null and not enable:
		if enabled == null:
			disable_managment()
			enabled = false
		return

	if enable :
		if not enabled:
			enabled = enable_managment()
	else:
		if enabled:
			disable_managment()
			enabled = false
