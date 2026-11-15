package com.mineserver.jei;

import java.util.List;
import mezz.jei.api.gui.builder.IRecipeLayoutBuilder;
import mezz.jei.api.gui.builder.IRecipeSlotBuilder;
import mezz.jei.api.gui.widgets.IRecipeExtrasBuilder;
import mezz.jei.api.helpers.IGuiHelper;
import mezz.jei.api.recipe.IFocusGroup;
import mezz.jei.api.recipe.category.AbstractRecipeCategory;
import mezz.jei.api.recipe.types.IRecipeType;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.ItemStack;
import net.spell_engine.spellbinding.SpellBindingBlock;

public class SpellBindingCategory extends AbstractRecipeCategory<SpellBindingRecipe> {
  public static final IRecipeType<SpellBindingRecipe> TYPE =
      IRecipeType.create("mineserver_jei", "spell_binding", SpellBindingRecipe.class);

  public SpellBindingCategory(IGuiHelper guiHelper) {
    super(
        TYPE,
        Component.translatable("gui.spell_engine.spell_binding.title"),
        guiHelper.createDrawableItemLike(SpellBindingBlock.ITEM),
        100,
        36);
  }

  @Override
  public void setRecipe(IRecipeLayoutBuilder builder, SpellBindingRecipe recipe, IFocusGroup focuses) {
    int x = 4;
    for (List<ItemStack> group : recipe.inputs()) {
      IRecipeSlotBuilder slot = builder.addInputSlot(x, 9).setStandardSlotBackground();
      for (ItemStack stack : group) {
        slot.add(stack);
      }
      x += 20;
    }
    builder.addOutputSlot(arrowX(recipe) + 28, 9).setOutputSlotBackground().add(recipe.output());
  }

  @Override
  public void createRecipeExtras(IRecipeExtrasBuilder extras, SpellBindingRecipe recipe, IFocusGroup focuses) {
    extras.addRecipeArrowWidget().setPosition(arrowX(recipe), 9);
  }

  private static int arrowX(SpellBindingRecipe recipe) {
    return 4 + recipe.inputs().size() * 20;
  }
}
