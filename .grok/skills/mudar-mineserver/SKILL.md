---
name: mudar-mineserver
description: Use when changing MineServer mods, jars, installers, configs, classes, recipes, death loot, the skill tree, docs, or anything friends install. Also when asked about the change process, versioning, approval before push, or updating GitHub after a pack change.
---

# Mudar o MineServer

Toda mudança segue esta ordem. O commit no GitHub é a versão. O nome dos jars permanece.

## Ordem

1. Brainstorm só se houver mais de um desenho razoável, ou se a mudança mexe em classe, morte, instalador, mundo, ou algo difícil de desfazer. Um pedido fechado segue direto para o ajuste.
2. Ajustar a origem (código, config, texto). Deixar o servidor ligado. Não rodar `instalar.sh` nem `scripts/sync_requirements.py` no servidor ao vivo.
3. Testar o que dá para testar daqui (compilação, checagem, `bash -n`, hash). Dizer o que não foi testado no jogo. Um teste só conta com a saída do comando.
4. Se o teste falhar, ajustar e testar de novo.
5. Mostrar o resultado e parar. A aprovação é um sim explícito nesta conversa ("pode", "aprovado", "sobe", "commit", "manda"). O pedido inicial de fazer a mudança não publica.
6. Depois da aprovação, atualizar o que o instalador copia: `bundled/`, `patches/`, `instalar.sh` e `instalar.ps1` juntos, `requirements/` quando entrar ou sair mod, e a mesma cópia local em `~/Games/mineserver/client/mods` e `server/mods` que esse jar já usa. Documentar só o que o jogador passa a ver (README, manual, REQUISITOS).
7. Commit só desses arquivos. `bot-avatar.jpg` e `docs/apresentacao/` ficam de fora. Push em `origin/master`.

Não reiniciar o servidor salvo pedido explícito.

## Versão

Não criar número de versão do pack. Não renomear `mineserver-classes-1.0.0.jar`, `mineserver-jei-1.0.0.jar` nem `mineserver-atributos-1.0.0.jar`. O instalador já compara o commit de `master` com `.mineserver-rev`. A nota para a galera, quando ele pedir, vai em português no #chat da Domingueira Gamer.

## Desvios

| Desculpa | Fato |
| --- | --- |
| O pedido já mandou fazer, então publico | Publicar espera o sim depois do teste. |
| O jar no servidor já vale | O processo aberto continua no jar antigo até o próximo início. |
| Falta versão para a galera achar | O commit é a versão que o instalador baixa. |
| Só o Linux precisa do instalador | `instalar.ps1` recebe a mesma mudança. |
