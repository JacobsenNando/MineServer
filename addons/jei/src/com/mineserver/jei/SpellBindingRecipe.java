package com.mineserver.jei;

import java.util.List;
import net.minecraft.resources.Identifier;
import net.minecraft.world.item.ItemStack;

public record SpellBindingRecipe(Identifier id, List<List<ItemStack>> inputs, ItemStack output) {
}
