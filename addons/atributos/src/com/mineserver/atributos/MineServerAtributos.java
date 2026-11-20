package com.mineserver.atributos;

import com.mojang.blaze3d.platform.InputConstants;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keymapping.v1.KeyMappingHelper;
import net.minecraft.client.KeyMapping;

public final class MineServerAtributos implements ClientModInitializer {
  public static final KeyMapping OPEN = KeyMappingHelper.registerKeyMapping(new KeyMapping(
      "key.mineserver_atributos.open",
      InputConstants.Type.KEYSYM,
      InputConstants.KEY_J,
      KeyMapping.Category.MISC));

  @Override
  public void onInitializeClient() {
    ClientTickEvents.END_CLIENT_TICK.register(client -> {
      while (OPEN.consumeClick()) {
        if (client.player == null) {
          continue;
        }
        if (client.gui.screen() instanceof AttributeSheetScreen) {
          client.setScreenAndShow(null);
        } else if (client.gui.screen() == null) {
          client.setScreenAndShow(new AttributeSheetScreen());
        }
      }
    });
  }
}
