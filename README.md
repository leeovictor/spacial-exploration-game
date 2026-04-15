# Spacial Factory Game

Spacial Factory Game e um jogo cooperativo de simulacao espacial no Roblox focado em coleta de recursos, automacao industrial e expansao interplanetaria. A direcao atual do projeto e levar o jogador de uma operacao manual em um planeta inicial ate uma cadeia de producao capaz de sustentar a construcao de um portal interdimensional.

## Status

- Projeto em fase inicial de prototipacao.
- Escopo e direcao do produto documentados em PRODUCT.md e doc/GDD.md.

## Stack

- Roblox Studio
- Luau
- Rojo
- Wally
- Aftman
- Selene
- React Lua com react e react-roblox para UI

## Pre-requisitos

- Roblox Studio instalado
- Aftman instalado e disponivel no PATH

## Setup

1. Instale as ferramentas do projeto:

	```bash
	aftman install
	```

2. Instale as dependencias Lua:

	```bash
	wally install
	```

3. Inicie o servidor do Rojo:

	```bash
	rojo serve
	```

4. Abra o projeto no Roblox Studio e conecte ao servidor do Rojo.

Depois disso, alteracoes em src/ serao sincronizadas para o Studio durante o desenvolvimento.

## Estrutura do projeto

```text
src/
  client/    # Scripts do cliente e UI
  server/    # Scripts do servidor
  shared/    # Modulos compartilhados via ReplicatedStorage
Packages/    # Dependencias instaladas pelo Wally
doc/         # Documentacao de design
PRODUCT.md   # Visao e objetivos do produto
```

## Mapeamento no Roblox

O arquivo default.project.json define o seguinte mapeamento principal:

- src/shared -> ReplicatedStorage.Shared
- Packages -> ReplicatedStorage.Packages
- src/server -> ServerScriptService.Server
- src/client -> StarterPlayer.StarterPlayerScripts.Client

## Comandos uteis

```bash
aftman install
wally install
rojo serve
selene src/
```

## Desenvolvimento

- Scripts de cliente usam a extensao .client.luau.
- Scripts de servidor usam a extensao .server.luau.
- Modulos compartilhados usam .luau.
- A UI nova deve preferir React Lua em vez de montagem imperativa de ScreenGui.

## Documentacao

- PRODUCT.md: visao do produto, pilares e loop principal.
- doc/GDD.md: definicao inicial dos sistemas, MVP e direcao de implementacao.