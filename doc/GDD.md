# GDD - Spacial Factory Game

## Status

Draft v0.1

## Objective

Este documento descreve um Game Design Document inicial para *Spacial Factory Game*, focado em sistemas, mecânicas e roadmap do MVP. O objetivo é transformar a direção definida em [PRODUCT.md](../PRODUCT.md) em uma base prática para prototipação, implementação e priorização.

## High Concept

*Spacial Factory Game* é um jogo cooperativo de simulação espacial em que jogadores iniciam em um planeta-base, coletam recursos, constroem estruturas produtivas, automatizam cadeias industriais e expandem a operação para outro planeta, com a meta de estabelecer a fundação de um portal interdimensional.

O coração do jogo é a transição de trabalho manual para infraestrutura automatizada em escala crescente.

## Design Goals

- entregar um loop inicial simples e compreensível em poucos minutos;
- criar progressão visível por expansão física da base;
- fazer automação parecer uma conquista, não uma obrigação burocrática;
- fazer exploração ter impacto real na produção;
- reforçar cooperação por meio de objetivos compartilhados e papéis naturais.

## Target Experience

O jogador deve passar por esta curva de experiência:

1. aprender a sobreviver e produzir no planeta inicial;
2. perceber gargalos operacionais e necessidade de automação;
3. otimizar a base local até liberar tecnologia espacial;
4. alcançar o segundo planeta e descobrir recursos exclusivos;
5. conectar produção planetária e logística entre mundos;
6. iniciar a construção de uma megaestrutura ligada ao portal.

## Core Game Loop

### Macro Loop

1. explorar;
2. coletar recursos;
3. construir estruturas;
4. automatizar produção;
5. pesquisar tecnologia;
6. expandir para outro planeta;
7. escalar logística e produção;
8. avançar a construção do portal.

### Moment-to-Moment Loop

1. identificar uma necessidade da base;
2. obter recursos, energia ou componentes;
3. posicionar ou ajustar estruturas;
4. validar fluxo de entrada, processamento e saída;
5. resolver gargalos;
6. desbloquear o próximo objetivo.

## MVP Definition

O MVP deve provar que o jogo já entrega sua fantasia principal. Para isso, ele precisa incluir:

- 2 planetas jogáveis;
- coleta manual funcional;
- produção básica e processamento de recursos;
- automação inicial de extração e transporte local;
- pesquisa com recursos;
- desbloqueio de voo individual do jogador;
- logística automatizada interplanetária em uma forma inicial;
- uma construção inicial do portal como objetivo coletivo de médio prazo.

## Core Systems

## 1. Resource System

### Purpose

Sustentar produção, progressão tecnológica e expansão espacial.

### MVP Requirements

- recursos primários extraídos do ambiente;
- recursos processados em estruturas de fabricação;
- pelo menos um recurso exclusivo no segundo planeta;
- diferenciação clara entre materiais básicos, intermediários e avançados.

### Suggested Resource Layers

- básicos: minério, pedra, gelo, biomassa ou equivalente;
- refinados: placas, ligas, combustível, componentes energéticos;
- avançados: materiais raros usados em voo, logística espacial e portal.

## 2. Building System

### Purpose

Permitir que o jogador transforme terreno e recursos em infraestrutura funcional.

### MVP Requirements

- posicionamento de estruturas no mundo;
- validação simples de colocação;
- remoção ou reposicionamento controlado;
- feedback visual de área ocupada e conexão funcional.

### Structure Categories

- coleta: mineradoras, extratores, bombas;
- produção: fornalhas, refinarias, montadoras;
- logística: esteiras, tubos, drones, pads, contêineres;
- energia: geradores básicos, baterias, distribuidores;
- utilidade: armazenamento, hubs, terminais de pesquisa;
- endgame: plataforma ou núcleo do portal.

## 3. Automation System

### Purpose

Converter tarefas repetitivas em fluxos produtivos escaláveis.

### MVP Requirements

- extração automática de pelo menos um recurso;
- transporte automático local entre estruturas;
- processamento contínuo sem intervenção manual constante;
- visualização clara do fluxo produtivo.

### Automation Progression

1. coleta manual;
2. máquinas de extração básicas;
3. transporte local automatizado;
4. cadeias de produção em múltiplos passos;
5. envio automatizado entre planetas.

## 4. Technology and Research System

### Purpose

Estruturar o avanço do jogador por marcos de produção e investimento em recursos.

### MVP Requirements

- árvore ou trilha inicial de pesquisa;
- custos em recursos para desbloquear novas receitas e estruturas;
- dependências simples entre tiers;
- desbloqueio explícito do voo individual;
- desbloqueio explícito da logística interplanetária.

### Suggested MVP Tiers

- Tier 0: coleta manual e estruturas iniciais;
- Tier 1: refino básico, energia simples e armazenamento;
- Tier 2: automação local e produção intermediária;
- Tier 3: voo pessoal e expansão espacial;
- Tier 4: logística interplanetária e fundação do portal.

## 5. Planetary Exploration System

### Purpose

Dar valor estratégico aos planetas e criar motivação para sair da base inicial.

### MVP Requirements

- planeta inicial com recursos amplos e menor risco;
- segundo planeta com recurso exclusivo e desafio ambiental leve;
- descoberta de depósitos ou áreas de interesse;
- incentivo real para instalar infraestrutura remota.

### Planet Roles for MVP

- Planeta 1: onboarding, base principal, indústria inicial;
- Planeta 2: expansão, recurso raro, prova de logística espacial.

## 6. Travel System

### Purpose

Conectar exploração, progressão espacial e identidade de fantasia sci-fi.

### MVP Requirements

- viagem inicial limitada ao planeta inicial;
- desbloqueio de voo individual por tecnologia;
- viagem entre planetas em formato controlado e funcional;
- clareza de custo ou requisito para deslocamento.

### MVP Direction

O voo do jogador entra como conquista de progressão e ferramenta de mobilidade. Ele não substitui a logística automatizada de recursos, que deve ser mais eficiente e mais importante para o avanço industrial.

## 7. Interplanetary Logistics System

### Purpose

Criar a ponte sistêmica entre exploração espacial e crescimento industrial.

### MVP Requirements

- envio automatizado de recursos entre 2 planetas;
- estrutura de origem e destino claramente identificada;
- capacidade limitada para criar decisões de prioridade;
- dependência de energia, combustível ou cooldown simples.

### Suggested First Implementation

- launch pad ou cargo pad em cada planeta;
- rotas fixas entre origem e destino;
- fila de envio por contêineres ou cargas discretas;
- tempo de trânsito visível para reforçar escala espacial.

## 8. Energy System

### Purpose

Introduzir restrição produtiva simples e legível.

### MVP Requirements

- geração básica de energia;
- consumo por máquinas e hubs logísticos;
- feedback de falta de energia;
- expansão da capacidade por construção.

### Design Direction

No MVP, energia deve ser compreensível e evitar microgerenciamento excessivo. Ela serve como limitador de escala e não como sistema punitivo de sobrevivência.

## 9. Multiplayer and Cooperation System

### Purpose

Fazer o progresso coletivo parecer mais eficiente e mais satisfatório do que jogar isoladamente.

### MVP Requirements

- base compartilhada;
- progresso de pesquisa compartilhado ou facilmente sincronizado;
- construção cooperativa;
- visibilidade do objetivo coletivo do portal;
- divisão natural de funções sem travar jogadores em classes fixas.

### Emergent Roles

- operador de produção;
- explorador;
- engenheiro logístico;
- construtor de expansão;
- coordenador de objetivos do portal.

## 10. Portal Progression System

### Purpose

Dar contexto aspiracional ao endgame e motivar integração de todos os sistemas.

### MVP Requirements

- blueprint ou estrutura visível do portal;
- etapas iniciais de construção;
- requisitos que dependam dos 2 planetas;
- sensação de obra coletiva de grande escala.

### MVP Scope Limit

No MVP, o portal não precisa ser funcional. Basta que sua fundação ou primeiro estágio construtivo prove a direção do endgame.

## Core Mechanics

## Player Actions

- mover-se pelo planeta e interagir com nós de recurso;
- coletar materiais manualmente;
- abrir interface de construção;
- posicionar e remover estruturas;
- inserir materiais em estruturas quando necessário;
- conectar elementos logísticos locais;
- iniciar pesquisas;
- viajar para o segundo planeta após desbloqueio;
- enviar recursos por rede interplanetária;
- contribuir para a construção do portal.

## Building Mechanics

- grid ou snap placement simples;
- custo visível antes da construção;
- preview de colocação;
- bloqueio em áreas inválidas;
- desmontagem com retorno total ou parcial de recursos.

## Production Mechanics

- receitas com entrada e saída definidas;
- tempo de processamento previsível;
- estruturas pausam sem insumo ou energia;
- estoque local simples por estrutura.

## Logistics Mechanics

- transferência automática entre estruturas conectadas;
- capacidade por estrutura logística;
- congestionamento visível quando houver gargalo;
- transporte interplanetário por lotes ou cargas discretas.

## Exploration Mechanics

- identificação de biomas ou zonas de recurso;
- scanner, marcador ou descoberta visual de depósitos;
- incentivo a levar infraestrutura para novos locais.

## Survival and Failure Model

O jogo terá sobrevivência leve. Isso significa:

- pouca ou nenhuma punição severa por exploração inicial;
- risco focado em preparo operacional e não em frustração constante;
- falhas principais vindas de gargalos produtivos, falta de energia e dependências logísticas.

## World Structure

## Planet 1: Starter World

### Role

Ensinar o loop base e suportar a maior parte da infraestrutura inicial.

### Expected Characteristics

- recursos comuns abundantes;
- terreno favorável para construção;
- riscos baixos;
- espaço para expansão da base principal.

## Planet 2: Expansion World

### Role

Introduzir recurso exclusivo e validar a camada espacial do jogo.

### Expected Characteristics

- acesso posterior via pesquisa;
- ambiente menos conveniente;
- necessidade de infraestrutura dedicada;
- importância real para o avanço do portal.

## Content Scope for MVP

## Structures

Lista sugerida de estruturas do MVP:

- coletor manual ou ferramenta de coleta;
- mineradora básica;
- refinaria ou forno;
- montadora simples;
- unidade de armazenamento;
- distribuidor ou conexão de energia;
- esteira, tubo ou equivalente logístico local;
- terminal de pesquisa;
- plataforma de voo ou hangar básico;
- cargo pad interplanetário;
- fundação do portal.

## Resources

Lista sugerida de classes de recursos do MVP:

- 3 a 4 recursos básicos;
- 2 a 3 recursos refinados;
- 1 recurso raro exclusivo do segundo planeta;
- 1 componente estrutural ligado ao portal.

## UI and Player Information

O MVP deve comunicar claramente:

- objetivos atuais;
- energia disponível e consumo;
- estado das máquinas;
- filas de produção e pesquisa;
- origem e destino de recursos interplanetários;
- progresso de construção do portal.

## Success Criteria for MVP

O MVP será bem-sucedido se um grupo de jogadores conseguir:

1. iniciar no planeta base e sobreviver ao onboarding;
2. construir uma base funcional com produção automatizada básica;
3. desbloquear tecnologia suficiente para chegar ao segundo planeta;
4. instalar uma operação remota no segundo planeta;
5. transportar um recurso exclusivo de volta para a base principal;
6. iniciar a construção da primeira etapa do portal.

## Out of Scope for MVP

Para proteger o escopo, o MVP não deve depender de:

- sistema solar completo com vários planetas;
- combate profundo ou inimigos complexos;
- portal funcional com nova dimensão jogável;
- árvores tecnológicas extensas;
- economia avançada entre jogadores;
- narrativa cinematográfica extensa;
- personalização cosmética robusta.

## Production Risks

- escopo excessivo no sistema de logística interplanetária;
- excesso de tipos de recurso antes do loop base estar sólido;
- tentativa de implementar voo livre complexo cedo demais;
- energia excessivamente punitiva no início do jogo;
- falta de clareza visual nos fluxos de produção.

## MVP Roadmap

## Phase 1: Foundation Prototype

### Goal

Validar o loop local do planeta inicial.

### Deliverables

- movimentação e interação básicas;
- coleta manual;
- inventário mínimo;
- sistema de construção inicial;
- 2 a 3 estruturas básicas;
- primeiro loop de produção simples.

## Phase 2: Local Automation Slice

### Goal

Validar automação como motor de progressão.

### Deliverables

- extração automatizada;
- energia básica;
- transporte local automatizado;
- receitas intermediárias;
- UI de estado de produção.

## Phase 3: Research and Progression

### Goal

Conectar produção ao avanço tecnológico.

### Deliverables

- terminal de pesquisa;
- custos em recursos para desbloqueios;
- tiers tecnológicos iniciais;
- desbloqueio de voo pessoal.

## Phase 4: Second Planet Vertical Slice

### Goal

Provar expansão espacial com valor estratégico real.

### Deliverables

- segundo planeta jogável;
- recurso exclusivo;
- viagem funcional do jogador;
- primeiros desafios ambientais leves;
- base remota mínima.

## Phase 5: Interplanetary Logistics

### Goal

Provar a identidade interplanetária do jogo.

### Deliverables

- cargo pad ou hub de envio;
- rota entre os 2 planetas;
- transferência automatizada de recurso;
- feedback de tempo de trânsito e capacidade.

## Phase 6: Portal Milestone

### Goal

Fechar o MVP com um objetivo coletivo memorável.

### Deliverables

- estrutura visível do portal;
- requisitos de construção que usem ambos os planetas;
- milestone de progressão compartilhada;
- condição de vitória parcial do MVP.

## Open Design Questions

- o voo do jogador será livre em 3D, assistido ou baseado em rotas;
- qual recurso exclusivo do segundo planeta melhor justifica expansão;
- energia terá combustível consumível, geração passiva ou modelo híbrido;
- a logística interplanetária usará drones, foguetes, cápsulas ou outro formato;
- qual será a persistência de progresso entre sessões multiplayer.

## Recommended Next Documents

Após este GDD inicial, os documentos mais úteis são:

- especificação de recursos e receitas do MVP;
- especificação de estruturas e tiers tecnológicos;
- fluxo de UX para construção, pesquisa e logística;
- arquitetura técnica inicial para dados replicados, estado de base e multiplayer.