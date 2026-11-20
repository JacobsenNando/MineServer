package com.mineserver.encantamentos;

import it.unimi.dsi.fastutil.objects.Object2IntMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.item.v1.ItemTooltipCallback;
import net.minecraft.ChatFormatting;
import net.minecraft.core.Holder;
import net.minecraft.core.component.DataComponents;
import net.minecraft.locale.Language;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.enchantment.Enchantment;
import net.minecraft.world.item.enchantment.ItemEnchantments;

public final class MineServerEncantamentos implements ClientModInitializer {
  @Override
  public void onInitializeClient() {
    ItemTooltipCallback.EVENT.register(MineServerEncantamentos::addDescriptions);
  }

  private static void addDescriptions(
      ItemStack stack, Item.TooltipContext context, TooltipFlag flag, List<Component> lines) {
    describe(stack.get(DataComponents.STORED_ENCHANTMENTS), lines);
    describe(stack.get(DataComponents.ENCHANTMENTS), lines);
  }

  private static void describe(ItemEnchantments enchantments, List<Component> lines) {
    if (enchantments == null || enchantments.isEmpty()) {
      return;
    }
    Language language = Language.getInstance();
    Map<String, Component> descriptions = new HashMap<>();
    for (Object2IntMap.Entry<Holder<Enchantment>> entry : enchantments.entrySet()) {
      Holder<Enchantment> holder = entry.getKey();
      String key = descriptionKey(language, holder, entry.getIntValue());
      if (key == null) {
        continue;
      }
      String label = Enchantment.getFullname(holder, entry.getIntValue()).getString();
      descriptions.put(label, Component.translatable(key).withStyle(ChatFormatting.DARK_GRAY));
    }
    for (int i = lines.size() - 1; i >= 0; i--) {
      Component description = descriptions.get(lines.get(i).getString());
      if (description != null) {
        lines.add(i + 1, description);
      }
    }
  }

  private static String descriptionKey(Language language, Holder<Enchantment> holder, int level) {
    String base = "mineserver.enchantment." + holder.getRegisteredName().replace(':', '.');
    String leveled = base + "." + level;
    if (language.has(leveled)) {
      return leveled;
    }
    if (language.has(base)) {
      return base;
    }
    return null;
  }
}
