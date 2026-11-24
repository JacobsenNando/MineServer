package com.mineserver.zoacao;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.IllegalFormatException;
import java.util.Map;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.entity.event.v1.ServerLivingEntityEvents;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.ComponentContents;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.network.chat.contents.TranslatableContents;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class MineServerZoacao implements ModInitializer {
  private static final Logger LOGGER = LoggerFactory.getLogger("mineserver_zoacao");
  private static final String RECURSO = "/assets/mineserver_zoacao/zoacao.json";

  private ZoeiraFrases frases;
  private DiscordZoador discord;
  private Map<String, String> idioma = Map.of();

  @Override
  public void onInitialize() {
    Path configDir = FabricLoader.getInstance().getConfigDir();
    frases = lerFrases(configDir.resolve("mineserver-zoacao.json"));
    idioma = lerIdioma(configDir.resolve("discord-mc-chat").resolve("26.2-pt_br.json"));
    discord = DiscordZoador.abrir(LOGGER, configDir.resolve("discord-mc-chat.json"));
    discord.carregarNome();
    ServerLivingEntityEvents.AFTER_DEATH.register(this::depoisDaMorte);
    LOGGER.info("Zoeira pronta, {} causas.", frases.causas());
  }

  private void depoisDaMorte(LivingEntity entity, DamageSource source) {
    if (!(entity instanceof ServerPlayer player) || frases == null) {
      return;
    }
    Entity killer = source.getEntity();
    boolean outroJogador = killer instanceof Player && killer != player;
    String mobId = "";
    String assassino = "";
    if (killer != null && killer != player) {
      mobId = killer.getType().getDescriptionId();
      assassino = killer instanceof Player
          ? killer.getName().getString()
          : textoDe(killer.getDisplayName());
    }
    String arma = "as próprias mãos";
    ItemStack weapon = source.getWeaponItem();
    if (weapon != null && !weapon.isEmpty()) {
      String nome = textoDe(weapon.getHoverName());
      if (!nome.isBlank()) {
        arma = nome;
      }
    }
    String chave = "death.attack." + source.getMsgId();
    Component morte = player.getCombatTracker().getDeathMessage();
    if (morte.getContents() instanceof TranslatableContents traduzivel) {
      chave = traduzivel.getKey();
    }
    String pool = frases.pool(chave, mobId, outroJogador);
    String sequencia = outroJogador
        ? "jogador:" + killer.getStringUUID()
        : (mobId.isBlank() ? pool : mobId);
    String molde = frases.escolher(player.getUUID(), pool, sequencia, System.currentTimeMillis());
    if (molde == null) {
      return;
    }
    String linha = ZoeiraFrases.formatar(molde, player.getName().getString(), assassino, arma);
    anunciarNoJogo(player, linha);
    discord.enviar(linha);
  }

  private void anunciarNoJogo(ServerPlayer player, String linha) {
    MutableComponent mensagem = Component.empty()
        .append(Component.literal("[Discord] ").withStyle(ChatFormatting.BLUE, ChatFormatting.BOLD))
        .append(Component.literal("<" + discord.nome() + "> ").withStyle(ChatFormatting.AQUA))
        .append(Component.literal(linha).withStyle(ChatFormatting.GRAY));
    player.level().getServer().getPlayerList().broadcastSystemMessage(mensagem, false);
  }

  private ZoeiraFrases lerFrases(Path destino) {
    try {
      if (!Files.exists(destino)) {
        try (InputStream entrada = MineServerZoacao.class.getResourceAsStream(RECURSO)) {
          if (entrada == null) {
            throw new IllegalStateException("zoacao.json não está no jar");
          }
          Files.copy(entrada, destino);
        }
      }
      try (Reader reader = Files.newBufferedReader(destino)) {
        return ZoeiraFrases.carregar(reader);
      }
    } catch (Exception e) {
      LOGGER.warn("Não li mineserver-zoacao.json. Uso a lista do jar.");
      try (Reader reader = new InputStreamReader(
          MineServerZoacao.class.getResourceAsStream(RECURSO), StandardCharsets.UTF_8)) {
        return ZoeiraFrases.carregar(reader);
      } catch (Exception deNovo) {
        throw new IllegalStateException("A lista de zoeira não abre.", deNovo);
      }
    }
  }

  private Map<String, String> lerIdioma(Path arquivo) {
    if (!Files.isRegularFile(arquivo)) {
      return Map.of();
    }
    try {
      JsonObject objeto = JsonParser.parseString(Files.readString(arquivo)).getAsJsonObject();
      Map<String, String> mapa = new HashMap<>();
      for (Map.Entry<String, JsonElement> entrada : objeto.entrySet()) {
        if (entrada.getValue().isJsonPrimitive()) {
          mapa.put(entrada.getKey(), entrada.getValue().getAsString());
        }
      }
      return mapa;
    } catch (Exception e) {
      LOGGER.warn("Não li o pt_br do bot. Nomes de mob ficam como o servidor manda.");
      return Map.of();
    }
  }

  private String textoDe(Component component) {
    ComponentContents conteudo = component.getContents();
    if (conteudo instanceof TranslatableContents traduzivel) {
      String molde = idioma.get(traduzivel.getKey());
      if (molde != null) {
        Object[] args = traduzivel.getArgs();
        Object[] prontos = new Object[args.length];
        for (int i = 0; i < args.length; i++) {
          Object arg = args[i];
          prontos[i] = arg instanceof Component aninhado ? textoDe(aninhado) : String.valueOf(arg);
        }
        try {
          return String.format(molde, prontos);
        } catch (IllegalFormatException e) {
          return component.getString();
        }
      }
    }
    return component.getString();
  }
}
