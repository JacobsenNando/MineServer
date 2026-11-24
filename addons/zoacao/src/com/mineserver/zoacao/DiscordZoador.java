package com.mineserver.zoacao;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicReference;
import org.slf4j.Logger;

/** Manda a zoeira pela conta do bot. Não devolve a mensagem pro jogo. */
final class DiscordZoador {
  private final Logger logger;
  private final HttpClient http;
  private final String token;
  private final String channelId;
  private final AtomicReference<String> nome = new AtomicReference<>("MineServer");

  private DiscordZoador(Logger logger, String token, String channelId) {
    this.logger = logger;
    this.token = token;
    this.channelId = channelId;
    this.http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
  }

  static DiscordZoador abrir(Logger logger, Path config) {
    if (!Files.isRegularFile(config)) {
      logger.warn("Sem discord-mc-chat.json, a zoeira fica só no chat do jogo.");
      return new DiscordZoador(logger, "", "");
    }
    try {
      JsonObject root = JsonParser.parseString(Files.readString(config)).getAsJsonObject();
      JsonObject generic = root.getAsJsonObject("generic");
      String token = texto(generic, "botToken");
      String channelId = texto(generic, "channelId");
      if (token.isBlank() || channelId.isBlank()) {
        logger.warn("O bot do Discord está sem token ou canal. A zoeira fica só no jogo.");
        return new DiscordZoador(logger, "", "");
      }
      return new DiscordZoador(logger, token, channelId);
    } catch (Exception e) {
      logger.warn("Não li o config do Discord. A zoeira fica só no jogo.");
      return new DiscordZoador(logger, "", "");
    }
  }

  boolean ativo() {
    return !token.isBlank() && !channelId.isBlank();
  }

  String nome() {
    return nome.get();
  }

  void carregarNome() {
    if (!ativo()) {
      return;
    }
    http.sendAsync(pedido("https://discord.com/api/v10/users/@me"), HttpResponse.BodyHandlers.ofString())
        .thenAccept(resposta -> {
          if (resposta.statusCode() != 200) {
            logger.warn("Não achei o nome do bot no Discord. Código {}.", resposta.statusCode());
            return;
          }
          JsonObject usuario = JsonParser.parseString(resposta.body()).getAsJsonObject();
          String id = texto(usuario, "id");
          String escolhido = primeiroPreenchido(texto(usuario, "global_name"), texto(usuario, "username"));
          if (!escolhido.isBlank()) {
            nome.set(escolhido);
          }
          buscarApelido(id);
        })
        .exceptionally(erro -> {
          logger.warn("Não achei o nome do bot no Discord.");
          return null;
        });
  }

  void enviar(String texto) {
    if (!ativo() || texto == null || texto.isBlank()) {
      return;
    }
    JsonObject corpo = new JsonObject();
    corpo.addProperty("content", texto);
    JsonObject mencoes = new JsonObject();
    mencoes.add("parse", new com.google.gson.JsonArray());
    corpo.add("allowed_mentions", mencoes);
    HttpRequest request = HttpRequest.newBuilder()
        .uri(URI.create("https://discord.com/api/v10/channels/" + channelId + "/messages"))
        .timeout(Duration.ofSeconds(5))
        .header("Authorization", "Bot " + token)
        .header("User-Agent", "MineServerZoeira")
        .header("Content-Type", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString(corpo.toString(), StandardCharsets.UTF_8))
        .build();
    http.sendAsync(request, HttpResponse.BodyHandlers.ofString())
        .thenAccept(resposta -> {
          int codigo = resposta.statusCode();
          if (codigo < 200 || codigo >= 300) {
            logger.warn("O Discord não publicou a zoeira. Código {}.", codigo);
          }
        })
        .exceptionally(erro -> {
          logger.warn("O Discord não publicou a zoeira.");
          return null;
        });
  }

  private void buscarApelido(String userId) {
    if (userId.isBlank()) {
      return;
    }
    http.sendAsync(
            pedido("https://discord.com/api/v10/channels/" + channelId),
            HttpResponse.BodyHandlers.ofString())
        .thenAccept(resposta -> {
          if (resposta.statusCode() != 200) {
            return;
          }
          String guildId = texto(JsonParser.parseString(resposta.body()).getAsJsonObject(), "guild_id");
          if (guildId.isBlank()) {
            return;
          }
          http.sendAsync(
                  pedido("https://discord.com/api/v10/guilds/" + guildId + "/members/" + userId),
                  HttpResponse.BodyHandlers.ofString())
              .thenAccept(membro -> {
                if (membro.statusCode() != 200) {
                  return;
                }
                String apelido = texto(JsonParser.parseString(membro.body()).getAsJsonObject(), "nick");
                if (!apelido.isBlank()) {
                  nome.set(apelido);
                }
                logger.info("A zoeira fala como {}.", nome.get());
              });
        });
  }

  private HttpRequest pedido(String url) {
    return HttpRequest.newBuilder()
        .uri(URI.create(url))
        .timeout(Duration.ofSeconds(5))
        .header("Authorization", "Bot " + token)
        .header("User-Agent", "MineServerZoeira")
        .GET()
        .build();
  }

  private static String texto(JsonObject objeto, String campo) {
    if (objeto == null || !objeto.has(campo) || objeto.get(campo).isJsonNull()) {
      return "";
    }
    return objeto.get(campo).getAsString().trim();
  }

  private static String primeiroPreenchido(String primeiro, String segundo) {
    return primeiro.isBlank() ? segundo : primeiro;
  }
}
