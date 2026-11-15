package com.mineserver.jei;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import mezz.jei.api.ingredients.ITypedIngredient;
import mezz.jei.api.recipe.advanced.ISimpleRecipeManagerPlugin;
import net.minecraft.client.Minecraft;
import net.minecraft.core.Holder;
import net.minecraft.resources.Identifier;
import net.minecraft.tags.TagKey;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.Level;
import net.spell_engine.SpellEngineMod;
import net.spell_engine.api.spell.Spell;
import net.spell_engine.api.spell.container.SpellContainerHelper;
import net.spell_engine.api.spell.registry.SpellRegistry;
import net.spell_engine.config.ServerConfig;
import net.spell_engine.item.ScrollItem;
import net.spell_engine.item.SpellEngineItems;
import net.spell_engine.item.UniversalSpellBookItem;
import net.spell_engine.spellbinding.SpellBinding;

public final class SpellBindingRecipes implements ISimpleRecipeManagerPlugin<SpellBindingRecipe> {
  @Override
  public boolean isHandledInput(ITypedIngredient<?> ingredient) {
    return ingredient.getItemStack().map(SpellBindingRecipes::isInput).orElse(false);
  }

  @Override
  public boolean isHandledOutput(ITypedIngredient<?> ingredient) {
    return ingredient.getItemStack().map(stack -> stack.getItem() == SpellEngineItems.SPELL_BOOK.get()).orElse(false);
  }

  @Override
  public List<SpellBindingRecipe> getRecipesForInput(ITypedIngredient<?> ingredient) {
    Optional<ItemStack> stack = ingredient.getItemStack();
    if (stack.isEmpty()) {
      return List.of();
    }
    List<SpellBindingRecipe> matches = new ArrayList<>();
    for (SpellBindingRecipe recipe : getAllRecipes()) {
      for (List<ItemStack> group : recipe.inputs()) {
        if (contains(group, stack.get())) {
          matches.add(recipe);
          break;
        }
      }
    }
    return matches;
  }

  @Override
  public List<SpellBindingRecipe> getRecipesForOutput(ITypedIngredient<?> ingredient) {
    Optional<ItemStack> stack = ingredient.getItemStack();
    if (stack.isEmpty()) {
      return List.of();
    }
    List<SpellBindingRecipe> matches = new ArrayList<>();
    for (SpellBindingRecipe recipe : getAllRecipes()) {
      if (ItemStack.isSameItemSameComponents(recipe.output(), stack.get())) {
        matches.add(recipe);
      }
    }
    return matches;
  }

  @Override
  public List<SpellBindingRecipe> getAllRecipes() {
    Level world = Minecraft.getInstance().level;
    ServerConfig config = SpellEngineMod.config;
    if (world == null || config == null) {
      return List.of();
    }
    List<SpellBindingRecipe> recipes = new ArrayList<>();
    for (TagKey<Spell> tag : SpellBinding.availableSpellBookTags(world)) {
      ItemStack emptyBook = new ItemStack(SpellEngineItems.SPELL_BOOK.get());
      if (!UniversalSpellBookItem.applyFromTag(emptyBook, tag)) {
        continue;
      }
      String pool = subId(tag.location());
      if (config.spell_book_creation_enabled) {
        recipes.add(new SpellBindingRecipe(
            id("book", pool),
            List.of(List.of(new ItemStack(Items.BOOK))),
            emptyBook.copy()));
      }
      List<Holder<Spell>> spells = SpellRegistry.entries(world, tag.location()).stream()
          .sorted(SpellContainerHelper.catalogEntrySorter)
          .toList();
      for (Holder<Spell> spellEntry : spells) {
        if (spellEntry.unwrapKey().isEmpty()) {
          continue;
        }
        Identifier spellId = spellEntry.unwrapKey().get().identifier();
        ItemStack boundBook = emptyBook.copy();
        SpellContainerHelper.addSpell(world, spellId, boundBook);
        recipes.add(new SpellBindingRecipe(
            id("spell", pool + "/" + subId(spellId)),
            List.of(List.of(emptyBook.copy()), consumables(world, spellEntry, config)),
            boundBook));
      }
    }
    return recipes;
  }

  private static List<ItemStack> consumables(Level world, Holder<Spell> spellEntry, ServerConfig config) {
    List<ItemStack> options = new ArrayList<>();
    Spell spell = spellEntry.value();
    if (spell.learn != null && spell.tier > 0) {
      int lapisCost = spell.tier * spell.learn.level_cost_per_tier * config.spell_binding_lapis_cost_multiplier;
      if (lapisCost > 0) {
        options.add(new ItemStack(Items.LAPIS_LAZULI, lapisCost));
      }
    }
    ItemStack scroll = new ItemStack(SpellEngineItems.SCROLL.get());
    ScrollItem.applySpell(scroll, spellEntry, ScrollItem.resolveSpellPool(world, spellEntry));
    options.add(scroll);
    return options;
  }

  private static boolean isInput(ItemStack stack) {
    Item item = stack.getItem();
    return item == Items.BOOK
        || item == Items.LAPIS_LAZULI
        || item == SpellEngineItems.SPELL_BOOK.get()
        || item == SpellEngineItems.SCROLL.get();
  }

  private static boolean contains(List<ItemStack> group, ItemStack stack) {
    for (ItemStack option : group) {
      if (ItemStack.isSameItemSameComponents(option, stack)) {
        return true;
      }
    }
    return false;
  }

  private static Identifier id(String type, String name) {
    return Identifier.fromNamespaceAndPath("mineserver_jei", "spell_binding/" + type + "/" + name);
  }

  private static String subId(Identifier id) {
    return id.getNamespace() + "/" + id.getPath();
  }
}
