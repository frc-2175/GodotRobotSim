tool
extends CollisionShape

class_name RobotBox

export(String, "Aluminum", "Polycarb", "Steel") var material = "Aluminum"

export(Math.LengthUnit) var unit = Math.LengthUnit.Inches setget set_unit
export(float) var width = 2
export(float) var height = 1
export(float) var depth = 12

export(float, 0.03125, 0.25) var thickness_inches = 0.125
export(bool) var solid = false

func set_unit(new_unit):
	var wm = Math.length2m(width, unit)
	var hm = Math.length2m(height, unit)
	var dm = Math.length2m(depth, unit)
	width = Math.m2length(wm, new_unit)
	height = Math.m2length(hm, new_unit)
	depth = Math.m2length(dm, new_unit)
	
	unit = new_unit
	property_list_changed_notify()

func ensure_children():
	var mesh: MeshInstance = get_node_or_null(@"Mesh")
	if not mesh:
		mesh = MeshInstance.new()
		mesh.mesh = CubeMesh.new()
		mesh.name = "Mesh"
		self.add_child(mesh)
		mesh.owner = get_tree().get_edited_scene_root()

func get_mass_kg() -> float:
	var w = Math.length2m(width, unit)
	var h = Math.length2m(height, unit)
	var d = Math.length2m(depth, unit)
	var volume_m3 = w * h * d
	if not solid:
		var w2 = Math.length2m(width, unit) - Math.in2m(thickness_inches*2)
		var h2 = Math.length2m(height, unit) - Math.in2m(thickness_inches*2)
		var d2 = Math.length2m(depth, unit) - Math.in2m(thickness_inches*2)
		volume_m3 -= w2 * h2 * d2
	var density_kgpm3 = RobotUtil.get_materials()[material].density_kgpm3
	
	return volume_m3 * density_kgpm3

func _editor_process():
	ensure_children()
	
	var w = Math.length2m(width, unit)
	var h = Math.length2m(height, unit)
	var d = Math.length2m(depth, unit)
	
	if not self.shape:
		self.shape = BoxShape.new()
	RobotUtil.reset_scale(self)
	self.shape.extents = Vector3(w/2, h/2, d/2)
	
	var mesh = $Mesh as MeshInstance
	RobotUtil.reset_translation(mesh)
	RobotUtil.reset_rotation(mesh)
	RobotUtil.reset_children(mesh)
	mesh.scale = Vector3(w/2, h/2, d/2)
	
	apply_mass_to_body()

func _process(_delta):
	if Engine.editor_hint:
		_editor_process()

# Calculate and set the mass of the parent RigidBody. Every box is
# gonna do this every time, but it doesn't really matter.
func apply_mass_to_body():
	# Find containing RigidBody
	var bodyNode: Node = get_parent()
	while bodyNode:
		if bodyNode is RigidBody:
			break
		else:
			bodyNode = bodyNode.get_parent()
	
	if not bodyNode:
		printerr("Node ", self.name, " needs to be inside a RigidBody.")
		return
	
	# Set stuff
	var body: RigidBody = bodyNode
	body.mass = get_masses(body)
	body.can_sleep = false
	
# Recursively walk through a node and its children, adding up the masses
func get_masses(node: Node) -> float:
	var sum: float = 0	
	if node.has_method("get_mass_kg"):
		sum += node.get_mass_kg()
	for child in node.get_children():
		sum += get_masses(child)
	
	return sum
