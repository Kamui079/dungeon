# Enemy Database System

This system ensures all enemies inherit global systems like status effects, XP rewards, loot drops, and more. It's designed to be future-proof and easy to extend.

## 🎯 **What This System Provides**

### **Global Systems (Automatically Inherited)**
- ✅ **Status Effects**: Poison, ignite, stun, slow, freeze, shock, bleed, bone break
- ✅ **XP Rewards**: Automatic XP calculation and distribution on enemy death
- ✅ **Loot System**: Configurable loot tables with guaranteed and chance-based drops
- ✅ **Gold Rewards**: Base gold + variance system
- ✅ **Resistance System**: Stat-based resistances to status effects
- ✅ **Database Integration**: Easy lookup and categorization

### **Enemy Categories**
- **Beasts**: Natural creatures (rats, wolves, bears)
- **Humanoids**: Intelligent beings (goblins, orcs, humans)
- **Undead**: Resistant to poison/fire, weak to physical
- **Elementals**: Elite enemies with magical properties
- **Dragons**: Boss-level enemies with high resistances

## 🚀 **How to Create New Enemies**

### **Method 1: Using the Enemy Factory (Recommended)**

```gdscript
# Create a new enemy using the factory
var enemy_factory = EnemyFactory.new()
var new_enemy = enemy_factory.create_enemy({
    "name": "Dark Elf",
    "level": 6,
    "category": "humanoids",
    "rarity": 2,
    "base_health": 60,
    "base_mana": 40,
    "base_damage": 20,
    "damage_range": [15, 25],
    "tags": ["elf", "dark", "medium_level"],
    "loot_table": {
        "elven_weapon": 0.25,
        "dark_gem": 0.15
    }
})
```

### **Method 2: Using Predefined Templates**

```gdscript
# Create a standard goblin
var goblin = enemy_factory.create_goblin(level=5)

# Create a skeleton (undead category)
var skeleton = enemy_factory.create_skeleton(level=6)

# Create a fire elemental
var fire_elemental = enemy_factory.create_fire_elemental(level=10)
```

### **Method 3: Extending the Base Enemy Class**

```gdscript
extends CharacterBody3D
class_name MyCustomEnemy

var enemy_behavior: Node = null

func _ready():
    # Create enemy behavior component
    enemy_behavior = preload("res://enemies/enemy.gd").new()
    add_child(enemy_behavior)
    
    # Set properties
    enemy_behavior.enemy_name = "My Custom Enemy"
    enemy_behavior.enemy_level = 5
    enemy_behavior.enemy_category = "humanoids"
    enemy_behavior.enemy_rarity = 2
    
    # Set stats
    enemy_behavior.base_health = 50
    enemy_behavior.base_mana = 30
    enemy_behavior.base_damage = 18
    
    # Set status effect flags
    enemy_behavior.can_be_poisoned = true
    enemy_behavior.can_be_ignited = false  # Immune to fire
    
    # Set loot
    enemy_behavior.base_gold_reward = 10
    enemy_behavior.loot_table = {"custom_item": 0.30}
    
    # Initialize
    enemy_behavior._ready()
```

## ⚙️ **Configuration Options**

### **Status Effect Flags**
```gdscript
enemy_behavior.can_be_poisoned = true    # Can receive poison effects
enemy_behavior.can_be_ignited = false    # Immune to fire/ignite
enemy_behavior.can_be_stunned = true     # Can be stunned
enemy_behavior.can_be_slowed = true      # Can be slowed
enemy_behavior.can_be_frozen = true      # Can be frozen
enemy_behavior.can_be_shocked = true     # Can be shocked
enemy_behavior.can_be_bleeding = true    # Can bleed
enemy_behavior.can_be_bone_broken = true # Can have bones broken
```

### **Loot System**
```gdscript
# Guaranteed drops (always happen)
enemy_behavior.guaranteed_loot = ["basic_weapon", "health_potion"]

# Chance-based drops
enemy_behavior.loot_table = {
    "rare_weapon": 0.15,      # 15% chance
    "magic_gem": 0.25,        # 25% chance
    "gold_coins": 0.50        # 50% chance
}

# Loot chance multiplier (affects all drops)
enemy_behavior.loot_chance_multiplier = 1.5  # 50% better loot
```

### **Gold Rewards**
```gdscript
enemy_behavior.base_gold_reward = 20     # Base gold amount
enemy_behavior.gold_variance = 10        # ±10 gold variance
# Final gold: 10-30 gold
```

## 🏷️ **Enemy Categories and Templates**

### **Basic Template**
- Vulnerable to most status effects
- Standard gold and loot rates
- Good for common enemies

### **Resistant Template**
- Immune to poison and fire
- Slightly better gold/loot
- Good for undead, constructs

### **Elite Template**
- Immune to stun and slow
- Better gold/loot rates
- Good for special enemies

### **Boss Template**
- Immune to most control effects
- High gold/loot rates
- Good for bosses, mini-bosses

## 📊 **Database Integration**

### **Getting Enemy Data**
```gdscript
# Get database entry for this enemy
var entry = enemy_behavior.get_database_entry()

# Load enemy from database entry
enemy_behavior.load_from_database_entry(entry)
```

### **Enemy Lookup**
```gdscript
# Find enemies by category
var beasts = get_enemies_by_category("beasts")
var low_level = get_enemies_by_category("low_level")

# Find enemies by tags
var fire_enemies = get_enemies_by_tag("fire")
var dungeon_enemies = get_enemies_by_tag("dungeon")
```

## 🔧 **Advanced Features**

### **Status Effect Resistance**
```gdscript
# Get resistance to a specific effect
var poison_resistance = enemy_behavior.get_status_effect_resistance("poison")
# Returns 0.0 (immune) to 1.0 (no resistance)

# Apply status effect with automatic resistance calculation
enemy_behavior.apply_status_effect("poison", 10, 5, source)
```

### **Custom Stat Modifiers**
```gdscript
enemy_behavior.strength_modifier = 2      # +2 strength
enemy_behavior.intelligence_modifier = 1  # +1 intelligence
enemy_behavior.speed_modifier = 3         # +3 speed
```

## 📝 **Example: Creating a New Enemy Type**

Here's how to create a "Shadow Assassin" enemy:

```gdscript
# Create the enemy
var shadow_assassin = enemy_factory.create_enemy({
    "name": "Shadow Assassin",
    "level": 8,
    "category": "humanoids",
    "rarity": 3,
    "base_health": 70,
    "base_mana": 25,
    "base_damage": 25,
    "damage_range": [20, 30],
    "move_speed": 4.0,
    "detection_range": 7.0,
    "combat_range": 2.0,
    
    # Status effects - shadow assassins are resistant to some effects
    "can_be_poisoned": false,    # Immune to poison
    "can_be_stunned": false,     # Immune to stun
    "can_be_slowed": false,      # Immune to slow
    
    # Loot and rewards
    "base_gold_reward": 35,
    "gold_variance": 15,
    "tags": ["assassin", "shadow", "stealth", "high_level"],
    "loot_table": {
        "shadow_blade": 0.20,
        "stealth_cloak": 0.15,
        "poison_dart": 0.30,
        "medium_healing_potion": 0.25
    }
})
```

## 🎮 **Testing Your Enemies**

1. **Create the enemy** using one of the methods above
2. **Add it to your scene** as a child of a CharacterBody3D
3. **Test status effects** by using poison darts, fire spells, etc.
4. **Check XP rewards** by defeating the enemy in combat
5. **Verify loot drops** by checking the console output

## 🚨 **Troubleshooting**

### **Enemy Not Receiving Status Effects**
- Check if `can_be_[effect]` is set to `true`
- Verify the StatusEffectsManager is in the scene
- Check console for error messages

### **No XP Awarded**
- Ensure the enemy has a valid `enemy_level`
- Check if the combat manager is properly connected
- Verify the player has a stats component

### **Loot Not Dropping**
- Check if `loot_table` is properly configured
- Verify `loot_chance_multiplier` is not 0
- Check console for loot roll results

## 🔮 **Future Enhancements**

- **Dynamic Difficulty**: Enemies scale with player level
- **Weather Effects**: Certain enemies stronger/weaker in different conditions
- **Faction System**: Enemies have relationships and alliances
- **Quest Integration**: Enemies tied to specific quests
- **Procedural Generation**: Random enemy creation based on area

---

**This system ensures that every enemy you create automatically gets all the global systems, making your game consistent and easy to maintain!**
