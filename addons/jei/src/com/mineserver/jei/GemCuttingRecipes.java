package com.mineserver.jei;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import mezz.jei.api.ingredients.ITypedIngredient;
import mezz.jei.api.recipe.advanced.ISimpleRecipeManagerPlugin;
import net.jewelry.gems.GemCut;
import net.jewelry.gems.GemCutRegistry;
import net.minecraft.client.Minecraft;
import net.minecraft.resources.Identifier;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;

public final class GemCuttingRecipes implements ISimpleRecipeManagerPlugin<GemCuttingRecipe> {
  @Override
  public boolean isHandledInput(ITypedIngredient<?> ingredient) {
    return ingredient.getItemStack().map(stack -> matchesInput(getAllRecipes(), stack)).orElse(false);
  }

  @Override
  public boolean isHandledOutput(ITypedIngredient<?> ingredient) {
    return ingredient.getItemStack().map(stack -> GemCut.of(stack).isPresent()).orElse(false);
  }

  @Override
  public List<GemCuttingRecipe> getRecipesForInput(ITypedIngredient<?> ingredient) {
    Optional<ItemStack> stack = ingredient.getItemStack();
    if (stack.isEmpty()) {
      return List.of();
    }
    List<GemCuttingRecipe> matches = new ArrayList<>();
    for (GemCuttingRecipe recipe : getAllRecipes()) {
      if (ItemStack.isSameItemSameComponents(recipe.input(), stack.get())) {
        matches.add(recipe);
      }
    }
    return matches;
  }

  @Override
  public List<GemCuttingRecipe> getRecipesForOutput(ITypedIngredient<?> ingredient) {
    Optional<ItemStack> stack = ingredient.getItemStack();
    if (stack.isEmpty()) {
      return List.of();
    }
    List<GemCuttingRecipe> matches = new ArrayList<>();
    for (GemCuttingRecipe recipe : getAllRecipes()) {
      if (ItemStack.isSameItemSameComponents(recipe.output(), stack.get())) {
        matches.add(recipe);
      }
    }
    return matches;
  }

  @Override
  public List<GemCuttingRecipe> getAllRecipes() {
    Level world = Minecraft.getInstance().level;
    if (world == null || !GemCutRegistry.isEnabled(world)) {
      return List.of();
    }
    List<GemCuttingRecipe> recipes = new ArrayList<>();
    GemCutRegistry.from(world).listElements().forEach(cut -> GemCut.idOf(cut).ifPresent(cutId -> recipes.add(
        new GemCuttingRecipe(
            Identifier.fromNamespaceAndPath(cutId.getNamespace(), "gem_cutting/" + cutId.getPath()),
            new ItemStack(cut.value().gem().value()),
            GemCut.stack(cut)))));
    return recipes;
  }

  private static boolean matchesInput(List<GemCuttingRecipe> recipes, ItemStack stack) {
    for (GemCuttingRecipe recipe : recipes) {
      if (ItemStack.isSameItemSameComponents(recipe.input(), stack)) {
        return true;
      }
    }
    return false;
  }
}
