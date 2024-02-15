# Copyright © 2020-present Hugo Locurcio and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
@icon("interpolated_camera_3d.svg")
extends Camera3D
class_name InterpolatedCamera3D

# Whether to interpolate based on a speed value or a duration value.
enum InterpolationMode {SPEED, DURATION}
@export var interpolation_mode: InterpolationMode:
	set(mode):
		interpolation_mode = mode
		notify_property_list_changed()

# The node to target.
# Can optionally be a Camera3D to support smooth FOV and Z near/far plane distance changes.
@export var target: Node3D:
	set(value):
		if !is_inside_tree(): 
			target = value
			return
		prev_position = self.global_position
		prev_basis = self.basis
		prev_near = self.near
		prev_far = self.far
		prev_size = self.size
		prev_fov = self.fov
		target = value
		elapsed_time = 0

@export_subgroup("Translate Properties")
@export var translate_transition_type: Tween.TransitionType
@export var translate_ease_type: Tween.EaseType
# The factor to use for asymptotical translation lerping.
# If 0, the camera will stop moving. If 1, the camera will move instantly.
@export_range(0, 1, 0.001) var translate_speed := 0.95
@export var translate_duration := 1.0

@export_subgroup("Rotate Properties")
@export var rotate_transition_type: Tween.TransitionType
@export var rotate_ease_type: Tween.EaseType
# The factor to use for asymptotical rotation lerping.
# If 0, the camera will stop rotating. If 1, the camera will rotate instantly.
@export_range(0, 1, 0.001) var rotate_speed := 0.95
@export var rotate_duration := 1.0

@export_subgroup("FOV (Ortho Size) Properties")
@export var fov_transition_type: Tween.TransitionType
@export var fov_ease_type: Tween.EaseType
# The factor to use for asymptotical FOV lerping.
# If 0, the camera will stop changing its FOV. If 1, the camera will change its FOV instantly.
# Note: Only works if the target node is a Camera3D.
@export_range(0, 1, 0.001) var fov_speed := 0.95
@export var fov_duration := 1.0

@export_subgroup("Near Far Properties")
@export var near_far_transition_type: Tween.TransitionType
@export var near_far_ease_type: Tween.EaseType
# The factor to use for asymptotical Z near/far plane distance lerping.
# If 0, the camera will stop changing its Z near/far plane distance. If 1, the camera will do so instantly.
# Note: Only works if the target node is a Camera3D.
@export_range(0, 1, 0.001) var near_far_speed := 0.95
@export var near_far_duration := 1.0

func _validate_property(property: Dictionary):
	if property.name in ["translate_speed", "rotate_speed", "fov_speed", "near_far_speed"] and interpolation_mode != InterpolationMode.SPEED:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name in ["translate_duration", "rotate_duration", "fov_duration", "near_far_duration"] and interpolation_mode != InterpolationMode.DURATION:
		property.usage = PROPERTY_USAGE_NO_EDITOR

var tween: Tween


func _ready() -> void:
	prev_position = self.global_position
	prev_basis = self.basis
	prev_near = self.near
	prev_far = self.far
	prev_size = self.size
	prev_fov = self.fov
	
	if target != null:
		snap_to_target()

var elapsed_time: float = 0
var prev_position: Vector3
var prev_basis: Basis
var prev_near: float
var prev_far: float
var prev_size: float
var prev_fov: float

func _process(delta: float) -> void:
	elapsed_time += delta
	if not Engine.is_editor_hint() and prev_position != self.position: 
		print("elapsed time: " + str(elapsed_time))
	var min_duration = min(elapsed_time, translate_duration)
	self.global_position = Tween.interpolate_value(prev_position, target.global_position - prev_position, min_duration, translate_duration, translate_transition_type, translate_ease_type)
	
	var prev_quaternion = Quaternion(prev_basis.orthonormalized())
	self.set_quaternion(Tween.interpolate_value(prev_quaternion, prev_quaternion.inverse() * Quaternion(target.basis.orthonormalized()), min_duration, rotate_duration, rotate_transition_type, rotate_ease_type))

	if target is Camera3D:
		var camera_target := target as Camera3D
		self.near = Tween.interpolate_value(prev_near, camera_target.near-prev_near, min_duration, near_far_duration, near_far_transition_type, near_far_ease_type)
		self.far = Tween.interpolate_value(prev_far, camera_target.far-prev_far, min_duration, near_far_duration, near_far_transition_type, near_far_ease_type)
		if camera_target.projection == Camera3D.PROJECTION_ORTHOGONAL:
			var new_size = Tween.interpolate_value(prev_size, camera_target.size-prev_size, min_duration, fov_duration, fov_transition_type, fov_ease_type)
			self.size = abs(new_size)
		else:
			self.fov = Tween.interpolate_value(prev_fov, camera_target.fov-prev_fov, min_duration, fov_duration, fov_transition_type, fov_ease_type)

func snap_to_target():
	self.global_transform = target.global_transform
	if target is Camera3D:
		self.near = target.near
		self.far = target.far
		if target.projection == Camera3D.PROJECTION_ORTHOGONAL:
			self.size = target.size
		else:
			self.fov = target.fov
