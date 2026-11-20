package com.mineserver.atributos;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.player.Player;

/** A ficha lê os atributos que o jogo já somou: equipamento, árvore e efeitos. */
public final class AttributeSheetScreen extends Screen {
  public AttributeSheetScreen() {
    super(Component.literal("Atributos"));
  }

  private static final int PANEL_WIDTH = 280;
  private static final int ROW = 13;
  private static final int HEADER = 28;
  private static final int BOTTOM = 10;

  private int scroll;

  @Override
  public boolean isPauseScreen() {
    return false;
  }

  @Override
  public boolean mouseScrolled(double mouseX, double mouseY, double scrollX, double scrollY) {
    this.scroll -= (int) Math.signum(scrollY) * ROW;
    return true;
  }

  @Override
  public void extractRenderState(GuiGraphicsExtractor graphics, int mouseX, int mouseY, float partialTick) {
    this.extractTransparentBackground(graphics);
    Player player = this.minecraft.player;
    if (player == null) {
      return;
    }
    List<Line> lines = lines(player);
    int content = lines.size() * ROW;
    int panelHeight = Math.min(HEADER + content + BOTTOM, Math.max(HEADER + ROW + BOTTOM, this.height - 24));
    int maxScroll = Math.max(0, content - (panelHeight - HEADER - BOTTOM));
    if (this.scroll < 0) {
      this.scroll = 0;
    }
    if (this.scroll > maxScroll) {
      this.scroll = maxScroll;
    }
    int x = (this.width - PANEL_WIDTH) / 2;
    int y = Math.max(12, (this.height - panelHeight) / 2);
    graphics.fill(x, y, x + PANEL_WIDTH, y + panelHeight, 0xE0101210);
    graphics.fill(x, y, x + PANEL_WIDTH, y + 2, 0xFFE6C98A);
    graphics.centeredText(this.font, this.title, this.width / 2, y + 8, 0xFFF4F1E8);
    int textTop = y + HEADER - 2;
    int textBottom = y + panelHeight - 4;
    graphics.enableScissor(x, textTop, x + PANEL_WIDTH, textBottom);
    int textY = y + 26 - this.scroll;
    for (Line line : lines) {
      if (line.value == null) {
        graphics.text(this.font, Component.literal(line.label), x + 12, textY, 0xFFE6C98A);
      } else {
        graphics.text(this.font, Component.literal(line.label), x + 12, textY, 0xFFD7D0C4);
        int valueWidth = this.font.width(line.value);
        graphics.text(this.font, Component.literal(line.value), x + PANEL_WIDTH - 12 - valueWidth, textY, 0xFFF4F1E8);
      }
      textY += ROW;
    }
    graphics.disableScissor();
  }

  private static List<Line> lines(Player player) {
    List<Line> lines = new ArrayList<>();
    lines.add(new Line("Corpo", null));
    lines.add(new Line("Vida", whole(player.getHealth()) + " / " + whole(value(player, Attributes.MAX_HEALTH))));
    lines.add(new Line("Corações", hearts(value(player, Attributes.MAX_HEALTH))));
    lines.add(new Line("Armadura", whole(value(player, Attributes.ARMOR))));
    lines.add(new Line("Resistência", one(value(player, Attributes.ARMOR_TOUGHNESS))));
    lines.add(new Line("Absorção", whole(player.getAbsorptionAmount()) + " / " + whole(value(player, Attributes.MAX_ABSORPTION))));
    lines.add(new Line("Arma na mão", null));
    lines.add(new Line("Dano", one(value(player, Attributes.ATTACK_DAMAGE))));
    lines.add(new Line("Ataques por segundo", one(value(player, Attributes.ATTACK_SPEED))));
    lines.add(new Line("Empurrão", one(value(player, Attributes.ATTACK_KNOCKBACK))));
    lines.add(new Line("Dano em área", percent(value(player, Attributes.SWEEPING_DAMAGE_RATIO))));
    lines.add(new Line("Movimento", null));
    lines.add(new Line("Velocidade", percent(value(player, Attributes.MOVEMENT_SPEED) / 0.1)));
    lines.add(new Line("Pulo", one(value(player, Attributes.JUMP_STRENGTH))));
    lines.add(new Line("Passo", one(value(player, Attributes.STEP_HEIGHT))));
    lines.add(new Line("Queda segura", one(value(player, Attributes.SAFE_FALL_DISTANCE))));
    lines.add(new Line("Mundo", null));
    lines.add(new Line("Sorte", one(value(player, Attributes.LUCK))));
    lines.add(new Line("Alcance", one(value(player, Attributes.BLOCK_INTERACTION_RANGE))));
    lines.add(new Line("Alcance de criatura", one(value(player, Attributes.ENTITY_INTERACTION_RANGE))));
    List<Line> magic = magic(player);
    if (!magic.isEmpty()) {
      lines.add(new Line("Magia", null));
      lines.addAll(magic);
    }
    return lines;
  }

  private static List<Line> magic(Player player) {
    List<Line> lines = new ArrayList<>();
    for (AttributeInstance instance : player.getAttributes().getSyncableAttributes()) {
      String id = instance.getAttribute().getRegisteredName();
      if (!id.startsWith("spell_power:")) {
        continue;
      }
      if (Math.abs(instance.getValue()) < 0.001) {
        continue;
      }
      String path = id.substring("spell_power:".length());
      lines.add(new Line(magicLabel(path), magicValue(path, instance.getValue())));
    }
    lines.sort((left, right) -> left.label.compareTo(right.label));
    return lines;
  }

  private static String magicLabel(String path) {
    return switch (path) {
      case "generic" -> "Poder mágico";
      case "arcane" -> "Arcano";
      case "fire" -> "Fogo";
      case "frost" -> "Gelo";
      case "healing" -> "Cura";
      case "lightning" -> "Raio";
      case "soul" -> "Alma";
      case "air" -> "Ar";
      case "water" -> "Água";
      case "earth" -> "Terra";
      case "blood" -> "Sangue";
      case "nature" -> "Natureza";
      case "shadow" -> "Sombra";
      case "holy" -> "Sagrado";
      case "unholy" -> "Profano";
      case "critical_chance" -> "Crítico mágico";
      case "critical_damage" -> "Dano crítico mágico";
      case "haste" -> "Aceleração mágica";
      case "resistance.generic" -> "Resistência mágica";
      default -> path;
    };
  }

  private static String magicValue(String path, double value) {
    if (path.contains("chance") || path.contains("critical_damage") || path.equals("haste") || path.contains("resistance")) {
      return percent(value);
    }
    return one(value);
  }

  private static double value(Player player, net.minecraft.core.Holder<net.minecraft.world.entity.ai.attributes.Attribute> attribute) {
    return player.getAttributeValue(attribute);
  }

  private static String whole(double value) {
    return String.format(Locale.ROOT, "%.0f", value);
  }

  private static String one(double value) {
    if (Math.abs(value - Math.rint(value)) < 0.05) {
      return whole(value);
    }
    return String.format(Locale.ROOT, "%.1f", value);
  }

  private static String hearts(double health) {
    return one(health / 2.0);
  }

  private static String percent(double value) {
    return String.format(Locale.ROOT, "%.0f%%", value * 100.0);
  }

  private record Line(String label, String value) {}
}
