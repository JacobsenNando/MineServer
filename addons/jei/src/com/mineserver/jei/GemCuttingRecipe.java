package com.mineserver.jei;

import net.minecraft.resources.Identifier;
import net.minecraft.world.item.ItemStack;

public record GemCuttingRecipe(Identifier id, ItemStack input, ItemStack output) {
}
