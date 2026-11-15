package com.mineserver.jei;

import mezz.jei.api.gui.builder.IRecipeLayoutBuilder;
import mezz.jei.api.gui.widgets.IRecipeExtrasBuilder;
import mezz.jei.api.helpers.IGuiHelper;
import mezz.jei.api.recipe.IFocusGroup;
import mezz.jei.api.recipe.category.AbstractRecipeCategory;
import mezz.jei.api.recipe.types.IRecipeType;
import net.jewelry.blocks.JewelryBlocks;
import net.minecraft.network.chat.Component;

public class GemCuttingCategory extends AbstractRecipeCategory<GemCuttingRecipe> {
  public static final IRecipeType<GemCuttingRecipe> TYPE =
      IRecipeType.create("mineserver_jei", "gem_cutting", GemCuttingRecipe.class);

  public GemCuttingCategory(IGuiHelper guiHelper) {
    super(
        TYPE,
        Component.translatable(JewelryBlocks.JEWELERS_KIT.block().getDescriptionId()),
        guiHelper.createDrawableItemLike(JewelryBlocks.JEWELERS_KIT.item()),
        90,
        36);
  }

  @Override
  public void setRecipe(IRecipeLayoutBuilder builder, GemCuttingRecipe recipe, IFocusGroup focuses) {
    builder.addInputSlot(4, 9).setStandardSlotBackground().add(recipe.input());
    builder.addOutputSlot(58, 9).setOutputSlotBackground().add(recipe.output());
  }

  @Override
  public void createRecipeExtras(IRecipeExtrasBuilder extras, GemCuttingRecipe recipe, IFocusGroup focuses) {
    extras.addRecipeArrowWidget().setPosition(28, 9);
  }
}
