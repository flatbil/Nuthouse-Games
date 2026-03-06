extends Control

# -------------------------------------------------------
# Game.gd — UI only. Reads state via EventBus signals.
# Calls GameManager for all state changes.
# -------------------------------------------------------

@onready var resource_label: Label         = $VBox/ResourceLabel
@onready var per_sec_label:  Label         = $VBox/PerSecLabel
@onready var tap_label:      Label         = $VBox/TapLabel
@onready var tap_button:     Button        = $VBox/TapButton
@onready var upgrade_list:   VBoxContainer = $VBox/ScrollContainer/UpgradeList


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.passive_rate_changed.connect(_on_passive_rate_changed)
	EventBus.tap_value_changed.connect(_on_tap_value_changed)
	EventBus.career_purchased.connect(_on_career_purchased)
	EventBus.investment_purchased.connect(_on_investment_purchased)
	EventBus.strategy_purchased.connect(_on_strategy_purchased)
	EventBus.offline_income_collected.connect(_on_offline_income)

	tap_button.pressed.connect(_on_tap_pressed)

	_build_lists()
	_refresh_ui()

	if OS.is_debug_build():
		var cheat := Button.new()
		cheat.text = "[DEBUG] +$100,000"
		cheat.pressed.connect(func() -> void: GameManager.add_resources(100_000.0))
		$VBox.add_child(cheat)


# -------------------------------------------------------
# Input
# -------------------------------------------------------

func _on_tap_pressed() -> void:
	GameManager.tap()


# -------------------------------------------------------
# EventBus handlers
# -------------------------------------------------------

func _on_resource_changed(amount: float) -> void:
	resource_label.text = "$" + _fmt(amount)
	_refresh_all_buttons()


func _on_passive_rate_changed(rate: float) -> void:
	if rate > 0.0:
		per_sec_label.text = "$%s / sec" % _fmt(rate)
	else:
		per_sec_label.text = ""


func _on_tap_value_changed(val: float) -> void:
	tap_label.text = "$%s / tap" % _fmt(val)


func _on_career_purchased(index: int) -> void:
	_refresh_career_button(index)


func _on_investment_purchased(index: int) -> void:
	_refresh_investment_button(index)


func _on_strategy_purchased(index: int) -> void:
	_refresh_strategy_button(index)


func _on_offline_income(amount: float) -> void:
	resource_label.text = "+$%s while away!" % _fmt(amount)
	await get_tree().create_timer(2.5).timeout
	resource_label.text = "$" + _fmt(GameManager.resources)


# -------------------------------------------------------
# UI builders
# -------------------------------------------------------

func _build_lists() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()

	# --- CAREER ---
	_add_section_header("── CAREER ──")
	for i in range(GameManager.CAREERS.size()):
		var btn := Button.new()
		btn.name = "Career_%d" % i
		btn.custom_minimum_size = Vector2(0, 72)
		btn.pressed.connect(_on_career_pressed.bind(i))
		upgrade_list.add_child(btn)
		_refresh_career_button(i)

	# --- INVESTMENTS ---
	_add_section_header("── INVESTMENTS ──")
	for i in range(GameManager.INVESTMENTS.size()):
		var btn := Button.new()
		btn.name = "Investment_%d" % i
		btn.custom_minimum_size = Vector2(0, 72)
		btn.pressed.connect(_on_investment_pressed.bind(i))
		upgrade_list.add_child(btn)
		_refresh_investment_button(i)

	# --- STRATEGIES ---
	_add_section_header("── STRATEGIES ──")
	for i in range(GameManager.STRATEGIES.size()):
		var btn := Button.new()
		btn.name = "Strategy_%d" % i
		btn.custom_minimum_size = Vector2(0, 72)
		btn.pressed.connect(_on_strategy_pressed.bind(i))
		upgrade_list.add_child(btn)
		_refresh_strategy_button(i)


func _add_section_header(title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	upgrade_list.add_child(lbl)


func _on_career_pressed(index: int) -> void:
	GameManager.buy_career(index)


func _on_investment_pressed(index: int) -> void:
	GameManager.buy_investment(index)


func _on_strategy_pressed(index: int) -> void:
	GameManager.buy_strategy(index)


func _refresh_career_button(index: int) -> void:
	var btn: Button = upgrade_list.get_node_or_null("Career_%d" % index)
	if btn == null:
		return
	var c: Dictionary = GameManager.CAREERS[index]
	if GameManager.careers_purchased[index]:
		btn.text = "%s\n[Completed]" % c["name"]
		btn.disabled = true
	else:
		btn.text = "%s\n%s\nCost: $%s" % [c["name"], c["description"], _fmt(c["cost"])]
		btn.disabled = not GameManager.can_afford_career(index)


func _refresh_investment_button(index: int) -> void:
	var btn: Button = upgrade_list.get_node_or_null("Investment_%d" % index)
	if btn == null:
		return
	var inv: Dictionary = GameManager.INVESTMENTS[index]
	var owned: int = GameManager.investments_owned[index]
	var cost: float = GameManager.get_investment_cost(index)
	btn.text = "%s  [x%d]\n%s\nCost: $%s" % [inv["name"], owned, inv["description"], _fmt(cost)]
	btn.disabled = not GameManager.can_afford_investment(index)


func _refresh_strategy_button(index: int) -> void:
	var btn: Button = upgrade_list.get_node_or_null("Strategy_%d" % index)
	if btn == null:
		return
	var s: Dictionary = GameManager.STRATEGIES[index]
	if GameManager.strategies_purchased[index]:
		btn.text = "%s\n[Active]" % s["name"]
		btn.disabled = true
	else:
		btn.text = "%s\n%s\nCost: $%s" % [s["name"], s["description"], _fmt(s["cost"])]
		btn.disabled = not GameManager.can_afford_strategy(index)


func _refresh_all_buttons() -> void:
	for i in range(GameManager.CAREERS.size()):
		_refresh_career_button(i)
	for i in range(GameManager.INVESTMENTS.size()):
		_refresh_investment_button(i)
	for i in range(GameManager.STRATEGIES.size()):
		_refresh_strategy_button(i)


func _refresh_ui() -> void:
	resource_label.text = "$" + _fmt(GameManager.resources)
	tap_label.text = "$%s / tap" % _fmt(GameManager.tap_value)
	if GameManager.passive_rate > 0.0:
		per_sec_label.text = "$%s / sec" % _fmt(GameManager.passive_rate)
	_refresh_all_buttons()


# -------------------------------------------------------
# Number formatting
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
