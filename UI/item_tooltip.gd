# ItemTooltip.gd
extends Control

@export var tooltip_panel: Panel
@export var item_name_label: Label
@export var item_type_label: Label
@export var item_description_label: Label
@export var item_stats_label: Label
@export var item_rarity_label: Label
@export var item_level_label: Label

var current_item: Item = null
var tooltip_visible: bool = false
var show_timer: Timer
var hover_delay: float = 0.3  # Reduced delay to 300ms for better responsiveness

func _ready():
	# Hide tooltip initially
	hide()
	
	# Ensure tooltip is always on top
	z_index = 1000
	
	# Create and set up the show timer
	show_timer = Timer.new()
	show_timer.wait_time = hover_delay
	show_timer.one_shot = true
	show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(show_timer)
	
	# Set up the tooltip panel if not assigned
	if not tooltip_panel:
		tooltip_panel = $TooltipPanel
	if not item_name_label:
		item_name_label = $TooltipPanel/VBoxContainer/ItemNameLabel
	if not item_type_label:
		item_type_label = $TooltipPanel/VBoxContainer/ItemTypeLabel
	if not item_description_label:
		item_description_label = $TooltipPanel/VBoxContainer/ItemDescriptionLabel
	if not item_stats_label:
		item_stats_label = $TooltipPanel/VBoxContainer/ItemStatsLabel
	if not item_rarity_label:
		item_rarity_label = $TooltipPanel/VBoxContainer/ItemRarityLabel
	if not item_level_label:
		item_level_label = $TooltipPanel/VBoxContainer/ItemLevelLabel

func _process(_delta):
	if tooltip_visible and current_item:
		# Follow mouse cursor
		var mouse_pos = get_viewport().get_mouse_position()
		var tooltip_size = tooltip_panel.size
		var viewport_size = get_viewport().get_visible_rect().size
		
		# Position tooltip to avoid going off-screen
		var pos_x = mouse_pos.x + 20
		var pos_y = mouse_pos.y + 20
		
		# Adjust if tooltip would go off the right edge
		if pos_x + tooltip_size.x > viewport_size.x:
			pos_x = mouse_pos.x - tooltip_size.x - 20
		
		# Adjust if tooltip would go off the bottom edge
		if pos_y + tooltip_size.y > viewport_size.y:
			pos_y = mouse_pos.y - tooltip_size.y - 20
		
		# Ensure tooltip doesn't go off the left or top edges
		pos_x = max(0, pos_x)
		pos_y = max(0, pos_y)
		
		position = Vector2(pos_x, pos_y)

func show_tooltip(item: Item):
	if not item:
		hide_tooltip()
		return
	
	# Stop any existing timer
	show_timer.stop()
	
	current_item = item
	
	# Start the timer to show the tooltip after delay
	show_timer.start()

func _on_show_timer_timeout():
	"""Called when the show timer expires"""
	if not current_item:
		return
	
	tooltip_visible = true
	
	# Set item name
	if item_name_label:
		item_name_label.text = current_item.name
		item_name_label.modulate = _get_rarity_color(current_item.rarity)
	
	# Set item type
	if item_type_label:
		var type_text = _get_item_type_text(current_item.item_type)
		if current_item is Equipment:
			type_text += " (" + current_item.get_slot_name().capitalize() + ")"
		item_type_label.text = type_text
	
	# Set description
	if item_description_label:
		item_description_label.text = current_item.description if current_item.description else "No description available."
	
	# Set stats
	if item_stats_label:
		var stats_text = _get_item_stats_text(current_item)
		item_stats_label.text = stats_text
		item_stats_label.visible = stats_text != ""
	
	# Set rarity
	if item_rarity_label:
		item_rarity_label.text = "Rarity: " + _get_rarity_text(current_item.rarity)
		item_rarity_label.modulate = _get_rarity_color(current_item.rarity)
	
	# Set level requirement
	if item_level_label:
		if current_item is Equipment and current_item.required_level > 1:
			item_level_label.text = "Required Level: " + str(current_item.required_level)
			item_level_label.visible = true
		else:
			item_level_label.visible = false
	
	# Show the tooltip
	show()

func hide_tooltip():
	current_item = null
	tooltip_visible = false
	show_timer.stop()
	hide()

func _get_item_type_text(item_type: Item.ITEM_TYPE) -> String:
	match item_type:
		Item.ITEM_TYPE.CONSUMABLE: return "Consumable"
		Item.ITEM_TYPE.EQUIPMENT: return "Equipment"
		Item.ITEM_TYPE.JUNK: return "Junk"
		_: return "Unknown"

func _get_rarity_text(rarity: Item.RARITY) -> String:
	match rarity:
		Item.RARITY.COMMON: return "Common"
		Item.RARITY.UNCOMMON: return "Uncommon"
		Item.RARITY.RARE: return "Rare"
		Item.RARITY.EPIC: return "Epic"
		Item.RARITY.LEGENDARY: return "Legendary"
		_: return "Unknown"

func _get_rarity_color(rarity: Item.RARITY) -> Color:
	match rarity:
		Item.RARITY.COMMON: return Color.WHITE
		Item.RARITY.UNCOMMON: return Color.GREEN
		Item.RARITY.RARE: return Color.BLUE
		Item.RARITY.EPIC: return Color.PURPLE
		Item.RARITY.LEGENDARY: return Color.ORANGE
		_: return Color.WHITE

func _get_item_stats_text(item: Item) -> String:
	var stats_text = ""
	
	if item is Equipment:
		var equipment = item as Equipment
		
		# Add armor/damage values
		if equipment.armor_value > 0:
			stats_text += "Armor: +" + str(equipment.armor_value) + "\n"
		if equipment.damage_value > 0:
			stats_text += "Damage: +" + str(equipment.damage_value) + "\n"
		
		# Add stat bonuses
		if equipment.stat_bonuses.size() > 0:
			for stat_name in equipment.stat_bonuses:
				var bonus = equipment.stat_bonuses[stat_name]
				var bonus_sign = "+" if bonus > 0 else ""
				stats_text += stat_name.capitalize() + ": " + bonus_sign + str(bonus) + "\n"
	
	elif item is Consumable:
		var consumable = item as Consumable
		
		# Add consumable effects
		if consumable.amount > 0:
			match consumable.consumable_type:
				Consumable.CONSUMABLE_TYPE.HEALTH:
					stats_text += "Restores " + str(consumable.amount) + " Health\n"
				Consumable.CONSUMABLE_TYPE.MANA:
					stats_text += "Restores " + str(consumable.amount) + " Mana\n"
				Consumable.CONSUMABLE_TYPE.BUFF:
					stats_text += "Provides buff effect\n"
				Consumable.CONSUMABLE_TYPE.CUSTOM:
					stats_text += "Custom effect: " + (consumable.custom_effect if consumable.custom_effect else "Unknown") + "\n"
	
	# Add stack info
	if item.max_stack > 1:
		stats_text += "Max Stack: " + str(item.max_stack)
	
	return stats_text.strip_edges()
