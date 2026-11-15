package com.mineserver.jei;

import mezz.jei.api.IModPlugin;
import mezz.jei.api.JeiPlugin;
import mezz.jei.api.registration.IRecipeCatalystRegistration;
import mezz.jei.api.registration.IRecipeCategoryRegistration;
import mezz.jei.api.registration.IAdvancedRegistration;
import mezz.jei.api.registration.ISubtypeRegistration;
import net.minecraft.resources.Identifier;
import net.spell_engine.api.spell.SpellDataComponents;
import net.spell_engine.item.SpellEngineItems;
import net.spell_engine.spellbinding.SpellBindingBlock;

@JeiPlugin
public class SpellBindingJeiPlugin implements IModPlugin {
  @Override
  public Identifier getPluginUid() {
    return Identifier.fromNamespaceAndPath("mineserver_jei", "spell_binding");
  }

  @Override
  public void registerItemSubtypes(ISubtypeRegistration registration) {
    registration.registerFromDataComponentTypes(
        SpellEngineItems.SPELL_BOOK.get(), SpellDataComponents.SPELL_CONTAINER);
    registration.registerFromDataComponentTypes(
        SpellEngineItems.SCROLL.get(), SpellDataComponents.SPELL_CONTAINER, SpellDataComponents.SPELL_CHOICE);
  }

  @Override
  public void registerCategories(IRecipeCategoryRegistration registration) {
    registration.addRecipeCategories(
        new SpellBindingCategory(registration.getJeiHelpers().getGuiHelper()));
  }

  @Override
  public void registerRecipeCatalysts(IRecipeCatalystRegistration registration) {
    registration.addCraftingStation(SpellBindingCategory.TYPE, SpellBindingBlock.ITEM);
  }

  @Override
  public void registerAdvanced(IAdvancedRegistration registration) {
    registration.addSimpleRecipeManagerPlugin(SpellBindingCategory.TYPE, new SpellBindingRecipes());
  }
}
