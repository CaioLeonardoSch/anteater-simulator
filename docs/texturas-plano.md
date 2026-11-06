# Texturas do cenário: plano para refinar

Guia para uma sessão local do Claude Code (com os MCPs do **Blender** e do
**Godot**) refinar as texturas do cenário, **uma superfície de cada vez**, com
foto de antes e depois para o Caio aprovar.

Página com a foto e a avaliação de cada superfície (feita em 06/11/2026):
https://claude.ai/artifact/C3ypPmHrJYadA5vkGCAL77

## Prompt para colar na sessão local

> Vamos refinar as texturas do cenário do Anteater Simulator, uma superfície
> de cada vez, até eu ficar satisfeito. Leia primeiro `docs/texturas-plano.md`
> (tem as regras do projeto, como cada superfície é feita hoje, os dois
> caminhos técnicos e a ordem) e o `README.md`. Use os MCPs do Blender e do
> Godot. Comece pela primeira da lista (o chão do cerrado): tire a foto de
> "antes", proponha em poucas linhas o que vai mudar, faça, tire a foto de
> "depois" do mesmo lugar e me mostre as duas lado a lado. Só passe para a
> próxima superfície quando eu aprovar. Fale comigo em português, sem termos
> técnicos.

## Regras do projeto

- Responda em **português**, sem termos técnicos, com atualizações curtas.
- **Uma coisa de cada vez:** uma superfície por vez; só passa para a próxima
  quando o Caio aprovar.
- **Git:**
  - Trabalhe numa branch `texturas`, criada a partir da `main` atualizada.
  - Faça um commit por superfície aprovada, com uma mensagem clara em
    português, e envie (`git push -u origin texturas`).
  - **Não abra PR** sem o Caio pedir.
- **Arquivos que não vão para o repositório:**
  - Não envie arquivos `.uid` soltos que o Godot cria sozinho. Os `.import` das
    texturas novas vão junto.
  - Deixe o `project.godot` no formato que o Godot salva. Se o editor só mudar
    a ordem das linhas ou o formato dele, descarte com
    `git checkout -- project.godot`.
- **Não mude a jogabilidade:** posições, tamanhos e colisões dos objetos, a
  economia e a interface ficam como estão. O trabalho é só o visual das
  superfícies.
- **Estilo:** o jogo tem um visual de animação, estilizado, com luz de fim de
  tarde (sol baixo, dourado). A ideia é ganhar detalhe e relevo sem virar
  realismo fotográfico nem destoar do resto.
- **Desempenho:**
  - O jogo tem 32 000 formigas e muito capim, e precisa rodar bem em
    computadores comuns.
  - Texturas de até 1024 × 1024 (2048 só para o chão e os paredões, se fizer
    diferença), comprimidas pela importação 3D do Godot.
  - Modelos: até uns 5 mil triângulos para pedras, cupinzeiros e troncos, e
    15 mil para árvores.
  - Confira o FPS antes e depois (`--stats` imprime o FPS a cada segundo).
- **Documentação:** a cada superfície aprovada, acrescente uma linha na tabela
  de histórico do `docs/DESIGN.md` (data, o que era, o que ficou) e atualize
  a lista no fim deste arquivo.

## Como o cenário é desenhado hoje

Quase nada é imagem: as superfícies são **pintadas por código** com manchas de
um ruído só (`noise_tex`, 512 px), sem relevo nenhum (nenhum material tem mapa
de relevo). Por isso tudo fica liso e com o mesmo jeito borrado.

**Atenção:** as pedras, árvores, cupinzeiros, troncos e paredões são **montados
pelo código** (`scripts/world/props.gd`, `scripts/world/cliffs.gd`) e **não têm
UV**. Uma textura comum (que depende de UV) não funciona neles. Os materiais
atuais projetam as manchas nas três direções do mundo (projeção triplanar,
`tri_noise` em `shaders/soft_surface.gdshader`). Use o mesmo jeito.

| Superfície | Onde é montada | Material (em `scripts/world/materials.gd`) | Shader |
|---|---|---|---|
| Chão do cerrado e trilhas | `scripts/world/terrain.gd` | `terrain` (a máscara das trilhas vem do terreno) | `shaders/terrain.gdshader` (projeção de cima, em XZ do mundo) |
| Paredões de arenito | `scripts/world/cliffs.gd` | `cliff` (faixas pintadas por vértice) | `shaders/soft_surface.gdshader` |
| Chão da mata (caminho para a área 2) | `scripts/world/vegetation.gd` (`ChaoDaMata`) | `cliff` | `soft_surface` |
| Pedras | `props.gd` `build_rock` | `rock` | `soft_surface` |
| Cupinzeiros | `props.gd` `build_termite_mound` | `clay` | `soft_surface` |
| Casca das árvores e arbustos | `props.gd` `build_tree`, `build_shrub` | `bark` | `soft_surface` |
| Troncos caídos | `props.gd` `build_log` | `log_bark` | `soft_surface` |
| Formigueiros e tampas das câmaras | `scripts/world/nest.gd` | `nest_soil`, `nest_cap` | `soft_surface` |
| Copas, arbustos, ipês | `props.gd` | `leaves_*`, `shrub_*`, `ipe_*` | `shaders/foliage.gdshader` + `assets/textures/leaf_cluster.png` / `flower_cluster.png` (256 px, geradas por `tools/gen_textures.py`) |
| Lagoas | `scripts/world/world.gd` `_build_pond_water` | `StandardMaterial3D` com cor por vértice | — |
| Capim | `scripts/world/grass.gd` | `grass` | `shaders/grass.gdshader` |
| Terra ao cavar, poeira | `scripts/world/nest.gd`, `world.gd` | `StandardMaterial3D` de cor lisa | — |
| Cupinzeiro gigante no horizonte | `scripts/world/giant_mound.gd` | próprio | `shaders/landmark.gdshader` |

Os materiais `bark`, `clay`, `rock`, `cliff` e `nest_soil` usam **o mesmo
shader** (`soft_surface`) com cores e números diferentes. Mexer nele muda
todos. Para uma superfície ganhar um visual próprio, prefira um shader novo ou
parâmetros novos que só ela usa.

## Dois caminhos (escolha por superfície)

### A. Textura que se repete, feita no Blender (chão, paredões, pedras, cascas)

1. No Blender, monte um material procedural da superfície (por exemplo,
   arenito em camadas, terra com torrões e pedrinhas, casca rachada).
2. "Asse" (bake) num plano, em imagens que se repetem sem emenda: cor, relevo
   (normal map) e aspereza (roughness), em 1024 px.
3. Salve em `assets/textures/<superficie>/` (por exemplo
   `assets/textures/chao/cor.png`, `relevo.png`, `aspereza.png`). Na importação
   do Godot, marque o relevo como **Normal Map**.
4. No shader, leia as imagens com a mesma projeção nas três direções
   (triplanar) e em coordenadas do mundo. Inclua o relevo
   (`NORMAL_MAP`, girado para cada direção da projeção). Mantenha os
   parâmetros de cor (`color_a`, `color_b`...) para ainda dar para acertar o
   tom pelo código.
5. Para não ficar repetitivo: misture duas escalas da mesma imagem e use o
   ruído atual para variar a cor e esconder a repetição.

O chão usa só a projeção de cima (XZ). Ele precisa de duas texturas, uma do
**solo de capim** e uma da **terra vermelha das trilhas**, misturadas pela
máscara que já existe (`mask_tex`).

### B. Modelo pronto, feito no Blender (pedras, cupinzeiros, troncos, árvores)

O jogo já aceita modelos prontos. Se existir
`assets/models/<nome>.glb`, ele usa o modelo no lugar do feito por código, já
no tamanho certo e com colisão (ver `assets/models/LEIA-ME.md` e
`scripts/model_library.gd`). Nomes: `pedra`, `cupinzeiro`, `tronco_caido`,
`arvore_cerrado`, `ipe_amarelo`, `ipe_roxo`, `arbusto`, `formigueiro`.

- Modele com UV e textura própria no Blender e exporte em `.glb`.
- Faça **algumas variações** (o jogo hoje gera cada pedra diferente; com um
  `.glb` só, todas ficam iguais, só giradas e em tamanhos diferentes). Se
  precisar de variações, proponha ao Caio antes como fazer.
- Para voltar ao feito por código, é só apagar o `.glb`.

**Sugestão:** comece pelo caminho A. Ele melhora tudo o que usa aquele
material de uma vez e não muda as formas, que já funcionam no jogo. O caminho
B fica para quando a forma também incomodar (por exemplo, o cupinzeiro, que
hoje é um monte arredondado).

## Fotos de antes e depois

`tools/fotos_texturas.tscn` põe o tamanduá sempre no mesmo lugar, na frente de
cada superfície, esconde o HUD e salva as fotos (só funciona com tela):

```bash
godot --path . res://tools/fotos_texturas.tscn -- --start=play --fotos=C:/fotos/antes
```

```bash
godot --path . res://tools/fotos_texturas.tscn -- --start=play --fotos=C:/fotos/depois --so=chao,capim
```

Nomes das fotos: `arvore`, `copa`, `ipe`, `arbusto`, `cupinzeiro`, `pedra`,
`tronco`, `formigueiro`, `chao`, `capim`, `lagoa`, `penhasco`, `trilha`. Tire
o "antes" de tudo uma vez, no começo. Mostre ao Caio o antes e o depois lado a
lado. Também vale uma volta no jogo de verdade (com o MCP do Godot), porque a
foto parada não mostra a repetição da textura nem o FPS.

## Ordem e o que buscar em cada superfície

**Prioridade alta**
1. **Chão do cerrado.** Hoje é uma mancha lisa marrom-oliva. Buscar:
   - torrões, pedrinhas, folhas e capim secos no chão, com relevo;
   - a terra vermelha das trilhas um pouco rachada e pisoteada.
2. **Paredões de arenito.** Hoje são lisos, com escorridos borrados. Buscar:
   - as camadas horizontais do arenito das chapadas;
   - fendas verticais, blocos e beiradas nítidas;
   - o verde só no topo.
3. **Pedras.** Hoje o líquen amarelado está forte demais e parece esponja.
   Buscar a mesma rocha dos paredões, com rachaduras, arestas e só um pouco de
   líquen.
4. **Cupinzeiros.** Hoje são laranja saturado e lisos, com cara de massinha.
   Buscar terra seca mais apagada, áspera, com caneluras verticais e furinhos.

**Prioridade média**

5. **Casca das árvores:** grossa, de cortiça e rachada, típica do cerrado (hoje
   é clara e lisa).
6. **Troncos caídos:** casca rachada, madeira exposta nas pontas e musgo só
   embaixo (hoje o verde parece estampa de camuflagem).
7. **Formigueiros e câmaras:** grãos de terra solta, olheiros (os buraquinhos
   de entrada) e relevo.
8. **Lagoas:** reflexo do céu, ondinhas com o vento e lama molhada na beira.
9. **Copas e arbustos:** imagens de folhas maiores, com mais variação; os
   arbustos mais acinzentados e secos, diferentes das copas.
10. **Chão da mata:** um material próprio, com folhas secas (hoje usa o dos
    paredões).
11. **Terra ao cavar:** grãos e poeira macia, no lugar das caixinhas e
    bolinhas de cor lisa.

**Prioridade baixa** (já funcionam no estilo do jogo): capim, ipês, formigas,
tanajuras, focinho, língua, céu, florzinhas e o cupinzeiro gigante (este segue
o que for feito nos cupinzeiros).

## Andamento

| Superfície | Situação |
|---|---|
| Chão do cerrado | feito em 06/11/2026: `assets/textures/chao/` e `assets/textures/trilha/`, feitas por `tools/blender_chao.py` |
| Paredões de arenito | a fazer |
| Pedras | a fazer |
| Cupinzeiros | a fazer |
| Casca das árvores | a fazer |
| Troncos caídos | a fazer |
| Formigueiros e câmaras | a fazer |
| Lagoas | a fazer |
| Copas e arbustos | a fazer |
| Chão da mata | a fazer |
| Terra ao cavar | a fazer |
