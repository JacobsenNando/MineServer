package com.mineserver.jei;

import mezz.jei.api.IModPlugin;
import mezz.jei.api.JeiPlugin;
import mezz.jei.api.registration.IAdvancedRegistration;
import mezz.jei.api.registration.IRecipeCatalystRegistration;
import mezz.jei.api.registration.IRecipeCategoryRegistration;
import mezz.jei.api.registration.ISubtypeRegistration;
import net.jewelry.blocks.JewelryBlocks;
import net.jewelry.gems.GemComponents;
import net.jewelry.gems.GemItem;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;

@JeiPlugin
public class GemCuttingJeiPlugin implements IModPlugin {
  @Override
  public Identifier getPluginUid() {
    return Identifier.fromNamespaceAndPath("mineserver_jei", "gem_cutting");
  }

  @Override
  public void registerItemSubtypes(ISubtypeRegistration registration) {
    BuiltInRegistries.ITEM.stream()
        .filter(item -> item instanceof GemItem)
        .forEach(item -> registration.registerFromDataComponentTypes(item, GemComponents.CUT));
  }

  @Override
  public void registerCategories(IRecipeCategoryRegistration registration) {
    registration.addRecipeCategories(
        new GemCuttingCategory(registration.getJeiHelpers().getGuiHelper()));
  }

  @Override
  public void registerRecipeCatalysts(IRecipeCatalystRegistration registration) {
    registration.addCraftingStation(GemCuttingCategory.TYPE, JewelryBlocks.JEWELERS_KIT.item());
  }

  @Override
  public void registerAdvanced(IAdvancedRegistration registration) {
    registration.addSimpleRecipeManagerPlugin(GemCuttingCategory.TYPE, new GemCuttingRecipes());
  }
}
