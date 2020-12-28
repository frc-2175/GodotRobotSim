extends Spatial

class_name RobotLauncher

enum MechanismType { Solenoid, TalonFX, TalonSRX, VictorSPX, PWM_Motor }
enum SolenoidShootMode { On, Off }
enum MotorShootMode { GreaterThan, LessThan }

# Launch the projectile with this velocity.
export(float) var velocity_meters_per_second = 6
# The type of robot mechanism that activates a shot. For example, the solenoid
# that pushes a game piece into the shooter, or the motor powering a
# feeder wheel.
export(MechanismType) var mechanism_type = MechanismType.Solenoid
# The ID of the device to watch (for all types of mechanisms)
export(int) var device_id
# For solenoids only: shoot when the solenoid enters this state.
export(SolenoidShootMode) var solenoid_shoot_when = SolenoidShootMode.On
# For motors only: shoot when the motor value is this relative to the threshold.
export(MotorShootMode) var motor_shoot_when = MotorShootMode.GreaterThan
# For motors only: the speed that the motor must be greater than or less than to
# count as a shot.
export(float) var motor_shoot_speed_threshold = 0

var stored = []
var launch_active = false

onready var sim: RobotSim = RobotUtil.find_parent_by_script(self, RobotSim) as RobotSim
var velocity_haver: Node

func _ready():
	var current = get_parent()
	while current:
		if current.has_method("get_linear_velocity"):
			velocity_haver = current
			break
		current = current.get_parent()

func _new_stored_body(body: RigidBody):
	return [body, body.collision_layer, body.collision_mask]

func _process(_delta):
	var do_launch = should_launch()
	if not launch_active and do_launch:
		launch()
	launch_active = do_launch

func store(body: RigidBody):
	stored.append(_new_stored_body(body))
	body.visible = false
	body.collision_layer = 0
	body.collision_mask = 0
	body.sleeping = true

func launch():
	if len(stored) == 0:
		return
	var entry = stored.pop_front()
	var body: RigidBody = entry[0]
	body.collision_layer = entry[1]
	body.collision_mask = entry[2]
	body.global_transform.origin = self.global_transform.origin
	body.visible = true
	body.sleeping = false
	
	var self_velocity: Vector3 = velocity_haver.get_linear_velocity() if velocity_haver else Vector3(0, 0, 0)
	var launch_velocity: Vector3 = velocity_meters_per_second * self.global_transform.basis.x
	body.linear_velocity = self_velocity + launch_velocity

func should_launch() -> bool:
	match mechanism_type:
		MechanismType.Solenoid:
			var solenoid_on = sim.get_data("PCM", str(0), "<solenoid_output_" + str(device_id), false)
			match solenoid_shoot_when:
				SolenoidShootMode.On:
					return solenoid_on
				SolenoidShootMode.Off:
					return not solenoid_on
		MechanismType.TalonFX, MechanismType.TalonSRX, MechanismType.VictorSPX, MechanismType.PWM_Motor:
			var motor_value = 0
			match mechanism_type:
				MechanismType.TalonFX:
					motor_value = sim.get_data("SimDevices", "Talon FX[%d]" % device_id, "<>Motor Output", 0)
				MechanismType.TalonSRX:
					motor_value = sim.get_data("SimDevices", "Talon SRX[%d]" % device_id, "<>Motor Output", 0)
				MechanismType.VictorSPX:
					motor_value = sim.get_data("SimDevices", "Victor SPX[%d]" % device_id, "<>Motor Output", 0)
				MechanismType.PWM_Motor:
					motor_value = sim.get_data("PWM", str(device_id), "<speed", 0)
			match motor_shoot_when:
				MotorShootMode.GreaterThan:
					return motor_value > motor_shoot_speed_threshold
				MotorShootMode.LessThan:
					return motor_value < motor_shoot_speed_threshold
	
	printerr("RobotLauncher '%s' has a bug! Could not decide whether or not to launch a game piece." % self.name)
	return false
