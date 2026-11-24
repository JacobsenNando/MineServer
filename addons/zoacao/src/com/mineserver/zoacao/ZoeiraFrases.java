package com.mineserver.zoacao;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.Reader;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Escolhe a frase da zoeira.
 * Mortes seguidas da mesma causa, dentro da janela, sobem para as frases mais ácidas.
 */
public final class ZoeiraFrases {
  public record Causa(String id, List<String> linhas, List<String> seguida) {}

  private final Map<String, Causa> porId;
  private final Map<String, String> chaveParaId;
  private final Map<String, String> mobParaId;
  private final long janelaMs;
  private final int seguidaAPartirDe;
  private final long pausaMs;
  private final Map<UUID, Streak> streaks = new LinkedHashMap<>();
  private final Map<String, Integer> rotacao = new LinkedHashMap<>();

  private record Streak(String sequencia, int count, long quando) {}

  private ZoeiraFrases(
      Map<String, Causa> porId,
      Map<String, String> chaveParaId,
      Map<String, String> mobParaId,
      long janelaMs,
      int seguidaAPartirDe,
      long pausaMs) {
    this.porId = porId;
    this.chaveParaId = chaveParaId;
    this.mobParaId = mobParaId;
    this.janelaMs = janelaMs;
    this.seguidaAPartirDe = seguidaAPartirDe;
    this.pausaMs = pausaMs;
  }

  public static ZoeiraFrases carregar(Reader reader) {
    JsonObject root = JsonParser.parseReader(reader).getAsJsonObject();
    long janelaMs = root.get("janelaSegundos").getAsLong() * 1000L;
    int seguidaAPartirDe = root.get("seguidaAPartirDe").getAsInt();
    Map<String, Causa> porId = new LinkedHashMap<>();
    Map<String, String> chaveParaId = new LinkedHashMap<>();
    Map<String, String> mobParaId = new LinkedHashMap<>();
    for (JsonElement elemento : root.getAsJsonArray("causas")) {
      JsonObject objeto = elemento.getAsJsonObject();
      String id = objeto.get("id").getAsString();
      Causa causa = new Causa(id, textos(objeto, "linhas"), textos(objeto, "seguida"));
      if (causa.linhas.isEmpty()) {
        throw new IllegalArgumentException("causa sem linhas: " + id);
      }
      porId.put(id, causa);
      indexar(objeto, "chaves", id, chaveParaId);
      indexar(objeto, "mobs", id, mobParaId);
    }
    if (!porId.containsKey("geral")) {
      throw new IllegalArgumentException("falta a causa geral");
    }
    return new ZoeiraFrases(porId, chaveParaId, mobParaId, janelaMs, seguidaAPartirDe, 1000L);
  }

  public int causas() {
    return porId.size();
  }

  public Causa causa(String id) {
    return porId.get(id);
  }

  public String pool(String deathKey, String mobDescId, boolean outroJogador) {
    if (outroJogador && porId.containsKey("jogador")) {
      return "jogador";
    }
    if (mobDescId != null && mobParaId.containsKey(mobDescId)) {
      return mobParaId.get(mobDescId);
    }
    String familia = familia(deathKey);
    if (chaveParaId.containsKey(familia)) {
      return chaveParaId.get(familia);
    }
    if (mobDescId != null && !mobDescId.isBlank() && porId.containsKey("outros")) {
      return "outros";
    }
    return "geral";
  }

  /**
   * Devolve a frase crua, ainda com {jogador}, ou null se essa morte repetiu dentro da pausa.
   * {@code sequencia} é o mob ou o jogador. Outra causa zera a contagem.
   */
  public String escolher(UUID jogador, String pool, String sequencia, long agora) {
    Streak anterior = streaks.get(jogador);
    if (anterior != null && agora - anterior.quando < pausaMs) {
      return null;
    }
    Causa causa = porId.getOrDefault(pool, porId.get("geral"));
    boolean seguidaNaSequencia = anterior != null
        && anterior.sequencia.equals(sequencia)
        && agora - anterior.quando <= janelaMs;
    int count = seguidaNaSequencia ? anterior.count + 1 : 1;
    boolean harsh = count >= seguidaAPartirDe && !causa.seguida.isEmpty();
    List<String> lista = harsh ? causa.seguida : causa.linhas;
    int indice = proximoIndice(jogador, pool, harsh, lista.size());
    streaks.put(jogador, new Streak(sequencia, count, agora));
    return lista.get(indice);
  }

  public static String formatar(String molde, String jogador, String assassino, String arma) {
    String alvo = limpar(jogador);
    String quem = limpar(vazio(assassino) ? "alguém" : assassino);
    String com = limpar(vazio(arma) ? "as próprias mãos" : arma);
    return molde
        .replace("{jogador}", alvo)
        .replace("{assassino}", quem)
        .replace("{arma}", com);
  }

  static String familia(String deathKey) {
    String chave = deathKey == null ? "" : deathKey;
    while (chave.endsWith(".player") || chave.endsWith(".item")) {
      chave = chave.substring(0, chave.lastIndexOf('.'));
    }
    return chave;
  }

  private int proximoIndice(UUID jogador, String pool, boolean harsh, int tamanho) {
    String chave = jogador + "|" + pool + "|" + harsh;
    int atual = rotacao.getOrDefault(chave, 0);
    rotacao.put(chave, atual + 1);
    return Math.floorMod(atual, tamanho);
  }

  private static void indexar(JsonObject objeto, String campo, String id, Map<String, String> destino) {
    if (!objeto.has(campo)) {
      return;
    }
    for (JsonElement elemento : objeto.getAsJsonArray(campo)) {
      destino.put(elemento.getAsString(), id);
    }
  }

  private static List<String> textos(JsonObject objeto, String campo) {
    List<String> linhas = new ArrayList<>();
    if (!objeto.has(campo)) {
      return linhas;
    }
    JsonArray array = objeto.getAsJsonArray(campo);
    for (JsonElement elemento : array) {
      String texto = elemento.getAsString().trim();
      if (!texto.isEmpty()) {
        linhas.add(texto);
      }
    }
    return List.copyOf(linhas);
  }

  private static boolean vazio(String texto) {
    return texto == null || texto.isBlank();
  }

  private static String limpar(String texto) {
    return texto.replace("§", "").replace("\n", " ").trim();
  }
}
