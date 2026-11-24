package com.mineserver.zoacao;

import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

public final class TesteZoacao {
  public static void main(String[] args) throws Exception {
    ZoeiraFrases frases;
    try (var reader = new InputStreamReader(
        TesteZoacao.class.getResourceAsStream("/assets/mineserver_zoacao/zoacao.json"),
        StandardCharsets.UTF_8)) {
      frases = ZoeiraFrases.carregar(reader);
    }
    if (frases.causas() < 30) {
      throw new AssertionError("causas demais de menos: " + frases.causas());
    }
    for (String id : new String[] {
      "queda", "lava", "agua", "jogador", "warden", "creeper", "zumbi", "outros", "geral"
    }) {
      ZoeiraFrases.Causa causa = frases.causa(id);
      if (causa == null || causa.linhas().size() < 3 || causa.seguida().size() < 3) {
        throw new AssertionError("pool curto: " + id);
      }
    }
    UUID um = UUID.fromString("00000000-0000-0000-0000-000000000001");
    String queda = "death.attack.fall";
    igual("queda", frases.pool(queda, "", false));
    igual("queda", frases.pool("death.attack.fall.player", "", false));
    igual("zumbi", frases.pool("death.attack.fall.player", "entity.minecraft.zombie", false));
    igual("jogador", frases.pool("death.attack.fall.player", "entity.minecraft.player", true));
    igual("warden", frases.pool("death.attack.mob", "entity.minecraft.warden", false));
    igual("warden", frases.pool("death.attack.sonic_boom", "", false));
    igual("creeper", frases.pool("death.attack.explosion", "entity.minecraft.creeper", false));
    igual("explosao", frases.pool("death.attack.explosion", "", false));
    igual("outros", frases.pool("death.attack.mob", "entity.minecraft.wolf", false));
    igual("geral", frases.pool("death.attack.generic", "", false));

    String primeira = frases.escolher(um, "queda", "queda", 0L);
    igual(frases.causa("queda").linhas().get(0), primeira);
    igual(frases.causa("queda").linhas().get(1), frases.escolher(um, "queda", "queda", 10_000L));
    igual(frases.causa("queda").seguida().get(0), frases.escolher(um, "queda", "queda", 20_000L));
    igual(frases.causa("queda").seguida().get(1), frases.escolher(um, "queda", "queda", 30_000L));
    if (frases.escolher(um, "queda", "queda", 30_500L) != null) {
      throw new AssertionError("morte duplicada passou");
    }
    igual(frases.causa("lava").linhas().get(0), frases.escolher(um, "lava", "lava", 40_000L));
    igual(frases.causa("queda").linhas().get(2), frases.escolher(um, "queda", "queda", 40_000L + 700_000L));

    UUID dois = UUID.fromString("00000000-0000-0000-0000-000000000002");
    igual(frases.causa("jogador").linhas().get(0), frases.escolher(dois, "jogador", "jogador:maria", 0L));
    igual(frases.causa("jogador").linhas().get(1), frases.escolher(dois, "jogador", "jogador:maria", 10_000L));
    igual(frases.causa("jogador").seguida().get(0), frases.escolher(dois, "jogador", "jogador:maria", 20_000L));
    igual(frases.causa("jogador").linhas().get(2), frases.escolher(dois, "jogador", "jogador:joao", 30_000L));

    String pronta = ZoeiraFrases.formatar(
        "{assassino} matou {jogador} com {arma}.", "Jacobsen", "Maria", "Espada de diamante");
    igual("Maria matou Jacobsen com Espada de diamante.", pronta);
    igual(
        "alguém matou Jacobsen com as próprias mãos.",
        ZoeiraFrases.formatar("{assassino} matou {jogador} com {arma}.", "Jacobsen", "", ""));
    System.out.println("ok " + frases.causas() + " causas");
  }

  private static void igual(String esperado, String real) {
    if (!esperado.equals(real)) {
      throw new AssertionError("esperava [" + esperado + "] veio [" + real + "]");
    }
  }
}
