# Pacote do MineServer — Minecraft 26.2

Data: 2026-11-04. Estado: desenho aprovado na conversa. Ainda não instalado.

## Objetivo

Pacote Fabric pequeno para 2 a 8 amigos, na VM Ampere futura (2 OCPUs, 12 GB). O jogo continua Minecraft. Por cima: armas e armaduras novas, uma ficha leve de habilidades, um mundo um pouco mais hostil, e chefes que o grupo escolhe enfrentar.

Sucesso: o grupo ainda joga madeira, ferro, diamante, netherite, Nether, End e o dragão. O perigo extra aparece de noite, na mina, no acampamento illager, na masmorra e no cemitério. Sem classe, sem livro de quests e sem dimensão nova.

## Plataforma

- Minecraft Java **26.2** (Chaos Cubed, 16 de junho de 2026), Fabric, **Java 25**.
- Heap alvo **6 GB**, piso **4 GB**.
- O pacote só é instalado quando a instância Ampere chamada `mineserver` existir. A porta 25565 continua fechada até lá.
- Todo mundo usa o mesmo pacote no cliente.
- As versões abaixo são as builds Fabric que estavam no Modrinth em 2026-11-04. Na instalação, usa-se essa build ou uma build mais nova do **mesmo** mod que ainda mire a 26.2.

A 26.2 traz cavernas de enxofre, gêiseres e o cubo de enxofre. A 26.3 (floresta manchada, álamo, acampamentos abandonados, almofadas, camas de palha) fica de fora, porque Illager Invasion e Skill Proficiencies param na 26.2.

## O que o jogador encontra

**No dia a dia.** O Skill Proficiencies sobe 15 habilidades fazendo a ação: minerar, cortar, lutar, pescar, agachar e craftar. O bônus soma com o encantamento. Sem classe e sem livro de quests.

O Better Combat dá alcance e golpe próprios a cada tipo de arma. O Weapons Expanded adiciona armas que se craftam. O Arsenal adiciona armas lendárias que se encontram, e não se craftam. O Immersive Armors adiciona conjuntos no visual do vanilla.

O Roughly Enough Items abre a aba lateral no inventário (tecla E). A aba lista itens e receitas do pacote, inclusive os dos mods.

**Onde aperta.** O Friends & Foes adiciona as criaturas do mob vote. O Illager Invasion deixa acampamentos e raids mais bravos, e dá para contornar. O Hostile Mobs Improve Over Time fortalece os mobs hostis conforme o mundo envelhece. A primeira semana real do mundo fica só um pouco acima do vanilla. O Dungeons and Taverns coloca masmorras e tavernas de bloco vanilla. O grupo entra quando quer. O The Graveyard coloca cemitérios com mortos-vivos e chefes nesses lugares. As cavernas de enxofre são o perigo extra debaixo da terra, e vêm do vanilla da 26.2. Nenhuma dimensão nova.

## Lista

### Jogo

| Mod | Build 26.2 | Onde roda | Função |
| --- | --- | --- | --- |
| Fabric API | 0.161.0+26.2 | cliente e servidor | API do Fabric |
| Better Combat | 3.2.2+26.2-fabric | cliente e servidor | golpe e alcance das armas |
| Weapons Expanded | 2.1.2 | cliente e servidor | armas craftáveis |
| Arsenal (RPG Series) | 1.5.1+26.2-fabric | cliente e servidor | armas lendárias encontradas |
| Immersive Armors | 1.8.2+26.2 | cliente e servidor | armaduras no visual do vanilla |
| Skill Proficiencies | 1.6.4 | cliente e servidor | 15 habilidades ao jogar |
| Friends & Foes | fabric-5.0.4+mc26.2 | cliente e servidor | criaturas do mob vote |
| Illager Invasion | 26.2.0 | cliente e servidor | acampamentos e raids illager |
| The Graveyard | 4.0.0+mc26.2-fabric | cliente e servidor | cemitérios, mortos-vivos e chefes |
| Roughly Enough Items | 26.2.820+fabric | cliente, obrigatório para a aba | aba lateral de itens e receitas |
| Hostile Mobs Improve Over Time | 2.3+mod | servidor; cliente opcional | mobs hostis escalam com a idade do mundo |
| Dungeons and Taverns | 5.3.2+mod | servidor; cliente opcional | masmorras e tavernas de bloco vanilla |

As bibliotecas que esses mods exigem vão junto. Elas não adicionam jogo.

### Performance

| Mod | Build 26.2 | Onde roda | Função |
| --- | --- | --- | --- |
| Lithium | mc26.2-0.25.3-fabric | cliente e servidor | custo de tick e de lógica |
| FerriteCore | 9.0.0-fabric | cliente e servidor | memória |
| Krypton | 0.3.1 | cliente e servidor | rede |
| Clumps | 26.2.1 | cliente e servidor | junta orbes de XP |
| ServerCore | 1.5.19+26.2 | só servidor | custo do servidor, com distância de mob do vanilla |
| Sodium | mc26.2-0.9.2-fabric | só cliente | quadros |
| Entity Culling | 1.11.3 | só cliente | não desenha entidade escondida |
| ImmediatelyFast | 1.16.5+26.2-fabric | só cliente | render imediato |
| BadOptimizations | 2.4.1 | só cliente | custo do cliente fora do render |
| Dynamic FPS | 3.11.9 | só cliente | custo com a janela em segundo plano |

## Travas

- O ServerCore não encurta a distância em que os mobs existem. Distância de simulação e alcance de ativação dos mobs ficam nos valores do vanilla. Ele pode cortar custo de rede e de chunk.
- A curva do Hostile Mobs Improve Over Time começa leve. A primeira fase cobre no mínimo os primeiros 7 dias reais depois da criação do mundo, não 7 dias de Minecraft. Se o padrão do mod já cumpre isso, fica o padrão. Se o padrão dispara dentro dessa semana, a taxa inicial desce até a primeira semana real ficar só um pouco acima do vanilla.
- Uma só leva de estruturas: Dungeons and Taverns. Moog's Voyager Structures fica de fora.
- Sem segundo sistema de armadura e sem berloque neste pacote. A armadura é o Immersive Armors. A ficha é o Skill Proficiencies.

## Fora deste pacote

- Qualquer dimensão nova, inclusive Deeper and Darker e o Otherside.
- Minecraft 26.3 e os snapshots da 26.4.
- Simply Swords, LevelZ, Bosses of Mass Destruction e When Dungeons Arise. Não têm build Fabric para a 26.2.
- EMI e JEI. Não têm build Fabric para a 26.2. A aba de itens é o REI.
- Mythic Metals, Aether, mods de magia, classes e livro de quests.
- Armory, Relics, Combat Roll, Mod Menu, ModernFix, Noisium e ScalableLux.
- Abrir a porta do jogo, ou instalar o pacote, antes de a VM Ampere existir.

## Checagem na instalação, quando a VM existir

1. O servidor sobe na 26.2 com Fabric, Java 25 e heap de 6 GB.
2. Um cliente com este pacote entra. Um cliente sem um mod obrigatório dos dois lados não entra.
3. Apertar E mostra a aba do REI, com itens deste pacote.
4. Um mundo novo segue a progressão do vanilla, e a primeira noite se sobrevive de ferro.
5. Dá para achar, e dá para ignorar, um acampamento illager, uma estrutura do Dungeons and Taverns e um cemitério.
6. Lithium, FerriteCore, Krypton, Clumps e ServerCore estão no servidor. Sodium está no cliente e não está no servidor dedicado.
