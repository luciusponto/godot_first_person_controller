class_name SttTaskGraphics

const MODELS = [
	preload("res://addons/scene_task_tracker/model/markers/BugMarkerNew.glb"),
	preload("res://addons/scene_task_tracker/model/markers/FeatureMarker.glb"),
	preload("res://addons/scene_task_tracker/model/markers/TechImprMarker.glb"),
	preload("res://addons/scene_task_tracker/model/markers/PolishMarker.glb"),
	preload("res://addons/scene_task_tracker/model/markers/RegTestMarker.glb"),
	preload("res://addons/scene_task_tracker/model/markers/UnknownMarker.glb"),
]

const ICONS = [
	preload("res://addons/scene_task_tracker/icons/bug.svg"),
	preload("res://addons/scene_task_tracker/icons/feature.svg"),
	preload("res://addons/scene_task_tracker/icons/tech_improvement.svg"),
	preload("res://addons/scene_task_tracker/icons/polish.svg"),
	preload("res://addons/scene_task_tracker/icons/regression_test.svg"),
	preload("res://addons/scene_task_tracker/icons/unkown.svg")
]

const COLORS = [
	Color.CORAL,
	Color.AQUAMARINE,
	Color.GOLD,
	Color.MEDIUM_AQUAMARINE,
	Color.SILVER,
	Color.MAGENTA,
]

const DEFAULT_MODEL = preload("res://addons/scene_task_tracker/model/markers/UnknownMarker.glb")
const DEFAULT_ICON = preload("res://addons/scene_task_tracker/icons/unkown.svg")
const DEFAULT_COLOR = Color.MAGENTA

const FIXED_BILLBOARD = preload("res://addons/scene_task_tracker/model/markers/CheckMark.glb")

static func get_color(task: SttTaskData) -> Color:
	if task.task_type > len(COLORS) - 1:
		return DEFAULT_COLOR
	return COLORS[task.task_type]


static func get_icon(task: SttTaskData) -> Texture2D:
	if task.task_type > len(ICONS) - 1:
		return DEFAULT_ICON
	return ICONS[task.task_type]
	
static func get_model(task: SttTaskData) -> PackedScene:
	if task.task_type > len(MODELS):
		return DEFAULT_MODEL
	return MODELS[task.task_type]
