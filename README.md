# MineServer

Cliente de Minecraft Java 26.2 com Fabric para jogar com o grupo. Este repositório instala o cliente. O mundo e os arquivos do servidor não estão aqui.

Serve para o Minecraft oficial e para um launcher, como o SKLauncher. Os dois mostram o perfil **MineServer**.

## Linux

Na pasta baixada:

```sh
bash instalar.sh
```

O script pergunta se você quer os shaders. Enter deixa sem. `s` instala.

## Windows

Dê dois cliques em `Instalar.bat`. Não precisa instalar Python.

A mesma pergunta dos shaders aparece na janela.

## Depois de instalar

1. Abra o Minecraft oficial ou o SKLauncher.
2. Escolha o perfil MineServer.
3. O nome que você usa no launcher é o nome dentro do jogo. Use o seu nome.
4. O endereço do servidor o grupo manda no chat.

O launcher baixa o Java 25 na primeira vez que o perfil abre. O computador fica mais folgado com 8 GB de memória ou mais.

A lista do que é instalado está em [requirements/REQUISITOS.md](requirements/REQUISITOS.md).

## Quem cuida do servidor

Quando um mod mudar na pasta `mods` do servidor, na máquina de quem cuida do servidor:

```sh
python3 scripts/sync_requirements.py /caminho/da/pasta/mods
```

Isso reescreve `requirements/client.txt` e `requirements/REQUISITOS.md`. Quem só vai jogar não roda esse comando.
