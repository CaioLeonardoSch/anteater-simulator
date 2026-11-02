# Anteater Simulator: demo

Você é um **tamanduá-bandeira** faminto, em **primeira pessoa**, no **cerrado ao
entardecer**. A colônia tem **1000 formigas** saindo pelas trilhas e em ondas
cada vez maiores. Coma todas, e a cada **100 formigas** ganhe um ponto para a
**árvore de habilidades**.

Visual 3D estilizado, com cara de filme de animação (nada de pixel art, nada de
low poly), feito em **Godot 4.7**.

![Tela inicial](docs/screenshots/menu.jpg)

| | |
|---|---|
| ![Lambendo formigas na trilha](docs/screenshots/trilha.jpg) | ![Formigueiro escavado](docs/screenshots/formigueiro.jpg) |
| ![Árvore de habilidades](docs/screenshots/arvore.jpg) | |

> Capturas feitas em um servidor sem placa de vídeo (renderização por software).
> No seu PC fica igual ou melhor.

---

## Como rodar

1. Instale o **Godot 4.7** (versão padrão, não precisa da .NET):
   <https://godotengine.org/download>
2. No Gerenciador de Projetos, clique em **Importar** e escolha o arquivo
   `project.godot` desta pasta.
3. Aperte **F5** (ou o botão ▶). Na primeira vez o Godot importa sons e
   texturas, o que leva alguns segundos.

O projeto usa o renderizador **Forward+** (PC com placa de vídeo compatível com
Vulkan, Direct3D 12 ou Metal). Em **Configurações** dá para baixar a qualidade
gráfica se o PC sofrer.

## Controles

| Ação | Teclado e mouse | Controle |
|---|---|---|
| Andar | `W` `A` `S` `D` | analógico esquerdo |
| Olhar | mouse | analógico direito |
| Correr | `Shift` | clicar o analógico esquerdo |
| **Lamber** (segure) | clique esquerdo | `RT` |
| Farejar | `Q` ou clique direito | `LT` |
| Cavar formigueiro* | segure `E` | `X` |
| Tremor* | `Espaço` | `A` |
| Árvore de habilidades | `Tab` | `Back` |
| Pausa | `Esc` | `Start` |

\* liberados pela árvore de habilidades.

## A fase: Cerrado ao Entardecer

- **1000 formigas na colônia.** Elas saem de 5 formigueiros, andam pelas trilhas
  de terra até os arbustos, cortam folhas e voltam carregando-as. Quem entra de
  novo no formigueiro sai mais tarde; só as que você come somem de vez.
- **Ondas**: a cada ~40 s um formigueiro despeja uma coluna de formigas, e cada
  onda é maior que a anterior. A bússola no topo da tela mostra de onde vem.
- **Reta final**: quando restam ~90, todas saem de casa e não voltam mais.
- **Formigas fogem** quando você chega correndo. Chegue andando e lamba de longe.
- **Soldados** (cabeçudos, vermelho-escuro) aguentam uma lambida antes de grudar.
- **Tanajuras** (douradas, voando) ativam o **Frenesi**: língua mais rápida e
  mais longa por 6 s.
- **Faro**: mostra as formigas através do capim e aponta o maior grupo na bússola.
- **Sem derrota**: é uma demo para relaxar. O sol vai se pondo conforme você
  come, e no fim aparecem os vaga-lumes. O recorde de tempo fica salvo.

## Árvore de habilidades

A cada 100 formigas você ganha **1 ponto**: são **9 pontos** para **12
habilidades**, então não dá para pegar tudo. Cada ramo é aprendido em ordem.

| Nível | Língua | Garras | Corpo |
|---|---|---|---|
| I | **Língua Comprida**: alcance +50% | **Garras Afiadas**: segure `E` num formigueiro e solte 25 formigas | **Patas Ligeiras**: +30% de velocidade |
| II | **Saliva Grudenta**: raio de captura +70% | **Escavação Profunda**: cava 2x mais rápido, solta 50 | **Pelagem Silenciosa**: as formigas só fogem de muito perto |
| III | **Lambida Dupla**: lambe 2x mais rápido | **Tremor** (`Espaço`): formigas a 6 m ficam tontas | **Disparada**: correr vira galope e não assusta as trilhas |
| IV | **Língua Chicote**: varre o caminho todo | **Terremoto**: tremor maior que puxa as formigas para a boca | **Faro Lendário**: fareja o mapa inteiro, recarga 2x |

## Modelos 3D gerados por IA

Tudo no jogo já funciona com modelos **feitos por código** (formas suaves,
pelagem com shader, folhas recortadas). Para trocar por modelos gerados por IA no
mesmo estilo:

- **[`docs/prompts-ia.md`](docs/prompts-ia.md)**: guia de estilo, paleta e o
  prompt de cada modelo (formigas, focinho, tamanduá, formigueiro, cupinzeiro,
  árvores, ipês, pedra, arbusto, tronco).
- **[`assets/models/LEIA-ME.md`](assets/models/LEIA-ME.md)**: nomes de arquivo
  e ajustes. Basta colocar o `.glb` em `assets/models/` que o jogo troca sozinho.

O **formigueiro** já foi gerado na Artlist (Hyper3D Rodin, com a geração 3D
gratuita da conta) e está no seu histórico de lá. O download do `.glb` exige um
plano com créditos de IA; depois de baixar, salve como
`assets/models/formigueiro.glb`.

## Qualidade gráfica

| Preset | O que muda |
|---|---|
| Baixa | menos capim, sombras curtas, sem SSAO, resolução 3D a 80% |
| Média | SSAO, sombras médias, MSAA 2x |
| Alta (padrão) | capim denso, sombras longas |
| Ultra | ainda mais capim, neblina volumétrica, SSIL, MSAA 4x |

A densidade do capim muda ao recomeçar a fase.

## Estrutura do projeto

```
project.godot            configuração (Forward+, autoloads, uniforms globais)
scenes/main.tscn         cena principal
scripts/
  main.gd                estados do jogo (menu, jogando, pausa, árvore, fim)
  model_library.gd       troca automática pelos modelos de IA (.glb)
  autoload/              Settings, GameState (habilidades/progresso), Sfx, DevTools
  world/                 terreno, trilhas, formigueiros, vegetação, capim, céu e sol
  ants/                  malhas das formigas, simulação do enxame, colônia e ondas
  player/                tamanduá em 1ª pessoa, focinho, patas e língua
  procedural/            construtor de malhas suaves (elipsoides, tubos, icosferas)
  ui/                    HUD, árvore de habilidades, menus e tema
shaders/                 capim, terreno, céu, folhagem, pelagem, língua, formigas...
assets/                  fontes, texturas e sons gerados, modelos de IA
tools/                   scripts Python que geram os sons e as texturas
docs/                    prompts de IA e capturas de tela
```

## Ferramentas

Sons e texturas são gerados por código (só precisam de Python 3 + numpy):

```bash
python3 tools/gen_audio.py
```

```bash
python3 tools/gen_textures.py
```

Opções de teste (depois de `--` na linha de comando do Godot):

```bash
godot --path . -- --start=play --autoplay --timescale=4 --stats
```

`--start=play|tree` pula o menu · `--autoplay` um bot joga sozinho ·
`--give=N` começa com N formigas · `--buy=lingua_1,garras_1` compra habilidades ·
`--captures=SEG:arquivo.png` tira capturas · `--quit` fecha depois.

## Créditos

- Fonte **Fredoka**: The Fredoka Project Authors, licença SIL Open Font License
  1.1 (`assets/fonts/OFL.txt`).
- Todo o resto (modelos provisórios, texturas, sons e a música de violão) é
  gerado por código neste repositório.
