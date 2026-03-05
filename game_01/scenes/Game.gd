extends Control

# -------------------------------------------------------
# Game.gd — UI logic only.
# Calls GameManager for all state changes.
# Listens to EventBus signals to redraw.
# -------------------------------------------------------

@onready var resource_label: Label         = $VBox/ResourceLabel
@onready var per_sec_label:  Label         = $VBox/PerSecLabel
@onready var tap_button:     Button        = $VBox/TapButton
@onready var asset_list:     VBoxContainer = $VBox/ScrollContainer/UpgradeList


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.passive_rate_changed.connect(_on_passive_rate_changed)
	EventBus.asset_purchased.connect(_on_asset_purchased)
	EventBus.multiplier_purchased.connect(_on_multiplier_purchased)
	EventBus.offline_income_collected.connect(_on_offline_income)

	tap_button.pressed.connect(_on_tap_pressed)

	_build_lists()
	_refresh_ui()

	# Debug cheat — debug builds only, never in release APK
	if OS.is_debug_build():
		var cheat := Button.new()
		cheat.text = "[DEBUG] +$1,000,000"
		cheat.pressed.connect(func() -> void: GameManager.add_resources(1_000_000.0))
		$VBox.add_child(cheat)


# -------------------------------------------------------
# Input
# -------------------------------------------------------

func _on_tap_pressed() -> void:
	GameManager.tap()


func _on_asset_pressed(index: int) -> void:
	GameManager.buy_asset(index)


func _on_multiplier_pressed(index: int) -> void:
	GameManager.buy_multiplier(index)


# -------------------------------------------------------
# EventBus handlers
# -------------------------------------------------------

func _on_resource_changed(amount: float) -> void:
	resource_label.text = "$" + _fmt(amount)
	_refresh_buttons()


func _on_passive_rate_changed(rate: float) -> void:
	if rate > 0.0:
		per_sec_label.text = "$%s / sec" % _fmt(rate)
	else:
		per_sec_label.text = ""


func _on_asset_purchased(index: int) -> void:
	_refresh_asset_button(index)


func _on_multiplier_purchased(index: int) -> void:
	_refresh_multiplier_button(index)


func _on_offline_income(amount: float) -> void:
	resource_label.text = "+$%s while away!" % _fmt(amount)
	await get_tree().create_timer(2.5).timeout
	resource_label.text = "$" + _fmt(GameManager.resources)


# -------------------------------------------------------
# UI builders
# -------------------------------------------------------

func _build_lists() -> void:
	for child in asset_list.get_children():
		child.queue_free()

	# Section: Assets (repeatable)
	var asset_header := Label.new()
	asset_header.text = "── INVESTMENTS ──"
	asset_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asset_list.add_child(asset_header)

	for i in range(GameManager.ASSETS.size()):
		var btn := Button.new()
		btn.name = "Asset_%d" % i
		btn.custom_minimum_size = Vector2(0, 80)
		btn.pressed.connect(_on_asset_pressed.bind(i))
		asset_list.add_child(btn)
		_refresh_asset_button(i)

	# Section: Multipliers (one-time)
	var mult_header := Label.new()
	mult_header.text = "── STRATEGIES ──"
	mult_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asset_list.add_child(mult_header)

	for i in range(GameManager.MULTIPLIERS.size()):
		var btn := Button.new()
		btn.name = "Multiplier_%d" % i
		btn.custom_minimum_size = Vector2(0, 80)
		btn.pressed.connect(_on_multiplier_pressed.bind(i))
		asset_list.add_child(btn)
		_refresh_multiplier_button(i)


func _refresh_buttons() -> void:
	for i in range(GameManager.ASSETS.size()):
		_refresh_asset_button(i)
	for i in range(GameManager.MULTIPLIERS.size()):
		_refresh_multiplier_button(i)


func _refresh_asset_button(index: int) -> void:
	var btn: Button = asset_list.get_node_or_null("Asset_%d" % index)
	if btn == null:
		return
	var a: Dictionary = GameManager.ASSETS[index]
	var owned: int = GameManager.assets_owned[index]
	var cost: float = GameManager.get_asset_cost(index)
	btn.text = "%s  [x%d]\n%s\nCost: $%s" % [a["name"], owned, a["description"], _fmt(cost)]
	btn.disabled = not GameManager.can_afford_asset(index)


func _refresh_multiplier_button(index: int) -> void:
	var btn: Button = asset_list.get_node_or_null("Multiplier_%d" % index)
	if btn == null:
		return
	var m: Dictionary = GameManager.MULTIPLIERS[index]
	if GameManager.multipliers_purchased[index]:
		btn.text = "%s\n[Purchased]" % m["name"]
		btn.disabled = true
	else:
		btn.text = "%s\n%s\nCost: $%s" % [m["name"], m["description"], _fmt(m["cost"])]
		btn.disabled = not GameManager.can_afford_multiplier(index)


func _refresh_ui() -> void:
	resource_label.text = "$" + _fmt(GameManager.resources)
	if GameManager.passive_rate > 0.0:
		per_sec_label.text = "$%s / sec" % _fmt(GameManager.passive_rate)
	_refresh_buttons()


# -------------------------------------------------------
# Number formatting — K, M, B, T, Qa
# -------------------------------------------------------

func _fmt(n: float) -> String:
	if n >= 1_000_000_000_000_000.0:
		return "%.2fQa" % (n / 1_000_000_000_000_000.0)
	elif n >= 1_000_000_000_000.0:
		return "%.2fT" % (n / 1_000_000_000_000.0)
	elif n >= 1_000_000_000.0:
		return "%.2fB" % (n / 1_000_000_000.0)
	elif n >= 1_000_000.0:
		return "%.2fM" % (n / 1_000_000.0)
	elif n >= 1_000.0:
		return "%.1fK" % (n / 1_000.0)
	else:
		return "%.2f" % n
