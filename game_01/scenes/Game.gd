extends Control

# -------------------------------------------------------
# Game.gd — UI logic only.
#
# RULE: This script never modifies game state directly.
#   - User input → calls GameManager methods
#   - EventBus signals → update labels and buttons
#
# The scene node layout this expects:
#
#   Game (Control)
#   └── VBox (VBoxContainer)
#       ├── ResourceLabel   (Label)
#       ├── PerSecLabel     (Label)
#       ├── TapButton       (Button)
#       └── ScrollContainer (ScrollContainer)
#           └── UpgradeList (VBoxContainer)
# -------------------------------------------------------

@onready var resource_label: Label        = $VBox/ResourceLabel
@onready var per_sec_label:  Label        = $VBox/PerSecLabel
@onready var tap_button:     Button       = $VBox/TapButton
@onready var upgrade_list:   VBoxContainer = $VBox/ScrollContainer/UpgradeList


func _ready() -> void:
	# Connect to signals from EventBus
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.passive_rate_changed.connect(_on_passive_rate_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.offline_income_collected.connect(_on_offline_income)

	# Connect the tap button
	tap_button.pressed.connect(_on_tap_pressed)

	# Build upgrade button list from GameManager data
	_build_upgrade_list()

	# Populate labels with current state (important after loading a save)
	_refresh_ui()

	# Debug cheat button — only visible in editor and debug builds, never in release
	if OS.is_debug_build():
		var cheat := Button.new()
		cheat.text = "[DEBUG] +10,000"
		cheat.pressed.connect(func() -> void: GameManager.add_resources(10000.0))
		$VBox.add_child(cheat)


# -------------------------------------------------------
# Input handlers — forward to GameManager, never touch state
# -------------------------------------------------------

func _on_tap_pressed() -> void:
	GameManager.tap()


func _on_upgrade_pressed(index: int) -> void:
	GameManager.buy_upgrade(index)


# -------------------------------------------------------
# EventBus signal handlers — update UI only
# -------------------------------------------------------

func _on_resource_changed(amount: float) -> void:
	resource_label.text = _format_number(amount)
	_refresh_upgrade_buttons()


func _on_passive_rate_changed(rate: float) -> void:
	if rate > 0.0:
		per_sec_label.text = "+%s / sec" % _format_number(rate)
	else:
		per_sec_label.text = ""


func _on_upgrade_purchased(_index: int) -> void:
	_refresh_upgrade_buttons()


func _on_offline_income(amount: float) -> void:
	# Simple notification — replace with a popup in Update 1
	resource_label.text = "+%s while away!" % _format_number(amount)
	await get_tree().create_timer(2.0).timeout
	resource_label.text = _format_number(GameManager.resources)


# -------------------------------------------------------
# UI builders
# -------------------------------------------------------

func _build_upgrade_list() -> void:
	# Clear any existing children (safe to call multiple times)
	for child in upgrade_list.get_children():
		child.queue_free()

	for i in range(GameManager.UPGRADES.size()):
		var upgrade: Dictionary = GameManager.UPGRADES[i]

		var btn := Button.new()
		btn.name = "Upgrade_%d" % i
		btn.custom_minimum_size = Vector2(0, 80)
		btn.text = "%s\n%s\nCost: %s" % [
			upgrade["name"],
			upgrade["description"],
			_format_number(upgrade["cost"]),
		]

		# Bind the index so each button knows which upgrade it represents
		btn.pressed.connect(_on_upgrade_pressed.bind(i))
		upgrade_list.add_child(btn)

	_refresh_upgrade_buttons()


func _refresh_upgrade_buttons() -> void:
	for i in range(GameManager.UPGRADES.size()):
		var btn: Button = upgrade_list.get_node_or_null("Upgrade_%d" % i)
		if btn == null:
			continue

		if GameManager.upgrades_purchased[i]:
			btn.disabled = true
			btn.text = GameManager.UPGRADES[i]["name"] + "\n[Purchased]"
		else:
			btn.disabled = not GameManager.can_afford(i)


func _refresh_ui() -> void:
	resource_label.text = _format_number(GameManager.resources)

	if GameManager.passive_rate > 0.0:
		per_sec_label.text = "+%s / sec" % _format_number(GameManager.passive_rate)
	else:
		per_sec_label.text = ""

	_refresh_upgrade_buttons()


# -------------------------------------------------------
# Utility
# -------------------------------------------------------

func _format_number(n: float) -> String:
	if n >= 1_000_000.0:
		return "%.2fM" % (n / 1_000_000.0)
	elif n >= 1_000.0:
		return "%.1fK" % (n / 1_000.0)
	else:
		return "%d" % int(n)
