---
name: traduzir-mineserver
description: >
  Use when MineServer still shows English, a pt_br key is missing or identical
  to en_us, or a new mod, book, item, block, or enchantment needs Portuguese.
  Triggers: traduzir, tradução, pt_br, resource pack de idioma, mineserver-idioma.
---

# Traduzir o MineServer

O cliente já está em `pt_br`. Chave ausente aparece em inglês. Publicar segue `mudar-mineserver`: mostrar o texto e parar até o sim.

## Onde gravar

Interface, nome e livro vão no resource pack `bundled/resourcepacks/mineserver-idioma`, com `min_format` e `max_format` 88. O pack só recebe a chave que falta no jar ou que ainda está igual ao inglês. A `pt_br` boa do jar fica. Não reempacotar o jar do mod.

A descrição que aparece ao passar o mouse no livro fica em `addons/encantamentos`, na lang do mod. A chave do nível é `mineserver.enchantment.<namespace>.<path>.<nível>`. A frase diz só o que aquele nível faz. Se o efeito é o mesmo em todo nível, a chave sem sufixo serve. O código procura primeiro a chave do nível.

Na árvore de habilidades a quebra de linha é `/n`. `%s`, `%d` e `%%` permanecem iguais ao inglês.

## Achar o que falta

Comparar `en_us.json` e `pt_br.json` nos jars de `~/Games/mineserver/client/mods`. Contar chave ausente e chave igual ao inglês. Repetir quando um jar entrar. Lista antiga não vale.

Traduzir nesta ordem: o que o jogador lê na partida (item, livro, botão, encantamento, mensagem), depois nome de bloco gerado, depois tela de opção. Pular livro demo, tag e chave de config que ninguém abre. Se a `pt_br` já cobre as chaves de jogo e o texto está em português, deixar o namespace.

Número sai do JSON do encantamento ou do código daquele nível. Não inventar.

## Voz

`você`. Nome de encantamento vanilla como no `pt_br` do jogo. Habilidade no estilo de título que o mod já usa.

## Prova

O JSON carrega. Toda chave nova existe no inglês ou é descrição nossa de encantamento. Os placeholders batem. Dizer o que não foi aberto no jogo.

## Desvios

| Desculpa | Fato |
| --- | --- |
| O jar já tem `pt_br`, então está pronto | Comparar com `en_us`. Chave faltando ou igual ao inglês ainda sai em inglês. |
| A tradução entra no jar do mod | O pack cobre a chave. O jar de cima não se reempacota. |
| Traduzo o mod inteiro agora | Primeiro o que o jogador lê na partida. |
| A descrição cita os outros níveis | Uma frase do nível daquela chave. |
