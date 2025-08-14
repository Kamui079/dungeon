# Chest Examples - How to create different chests for different levels
# This file shows you how to easily configure different chests

# Example 1: Early Level Chest (Current Setup)
# - Small Healing Potion (50.5% drop chance)
# - Small Mana Potion (50.5% drop chance)
# - Guaranteed minimum 1 item
# - Chest stays after opening

# Example 2: Mid Level Chest
# - Healing Potion (75% drop chance)
# - Mana Potion (75% drop chance)
# - Better Healing Potion (25% drop chance)
# - Better Mana Potion (25% drop chance)
# - Guaranteed minimum 1 item
# - Chest stays after opening

# Example 3: Boss Level Chest
# - All potions (100% drop chance each)
# - Rare Equipment (15% drop chance)
# - Epic Equipment (5% drop chance)
# - Guaranteed minimum 2 items
# - Chest destroys after opening

# Example 4: Treasure Chest
# - Gold (100% drop chance)
# - Gems (50% drop chance)
# - No guaranteed minimum (can be empty)
# - Chest stays after opening

# To use these examples in your game:

# 1. Create a new chest scene
# 2. Attach the chest.gd script
# 3. In the inspector, set the item_pool array with your items
# 4. Or use the setup_chest() method in code:

# Example usage in code:
# var chest = $Chest
# var mid_level_items = [healing_potion, mana_potion, better_healing, better_mana]
# chest.setup_chest(mid_level_items, true, false)

# Example usage in inspector:
# - Set item_pool to your array of items
# - Set ensure_at_least_one to true/false
# - Set destroy_after_open to true/false

# The system will automatically:
# - Roll each item based on its drop_chance property
# - Ensure minimum drops if configured
# - Give all successful rolls to the player
# - Handle inventory management
# - Provide detailed debug output
