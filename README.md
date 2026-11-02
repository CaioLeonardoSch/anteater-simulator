# Anteater Simulator

Um jogo **relaxante de "arrumar e limpar"**, na linha de *Leaf it Alone*: você é
um **tamanduá-bandeira** que come formigas e cupins no **cerrado**, evolui
habilidades e deixa a região **100% limpa**. Não dá para perder, e o jogo tem
fim. Para **PC (Steam)**, em **3D estilizado** com cara de filme de animação,
visto pelos olhos do tamanduá. Feito em **Godot 4.7**.

**Tudo o que foi decidido sobre o jogo está em
[`docs/DESIGN.md`](docs/DESIGN.md)**: o documento de design, o plano de
produção, os protótipos e as decisões, num lugar só.

![Tela inicial da demo](docs/screenshots/menu.jpg)

| | |
|---|---|
| ![Lambendo formigas na trilha](docs/screenshots/trilha.jpg) | ![Formigueiro escavado](docs/screenshots/formigueiro.jpg) |
| ![Árvore de habilidades da demo](docs/screenshots/arvore.jpg) | |

> Capturas feitas em um servidor sem placa de vídeo (renderização por software).
> No seu PC fica igual ou melhor.

---

## A demo jogável

Uma fase no **cerrado ao entardecer**: a colônia tem **1000 formigas**, que
saem de 5 formigueiros, andam pelas trilhas de terra e chegam em **ondas** cada
vez maiores. A cada **100 formigas** você ganha um ponto para a árvore de
habilidades. O sol vai se pondo conforme você come.

> A demo veio antes das decisões de 02/11/2026. As mudanças para alinhá-la ao
> jogo decidido (ninhos com câmaras, rainha, 5 habilidades, sem formigas-soldado,
> região de 45 a 60 minutos) estão na seção 4 do
> [`docs/DESIGN.md`](docs/DESIGN.md).

### Como rodar

1. Instale o **Godot 4.7** (versão padrão, não precisa da .NET):
   <https://godotengine.org/download>
2. No Gerenciador de Projetos, clique em **Importar** e escolha o arquivo
   `project.godot` desta pasta.
3. Aperte **F5** (ou o botão ▶). Na primeira vez o Godot importa sons e
   texturas, o que leva alguns segundos.

O projeto usa o renderizador **Forward+** (PC com placa de vídeo compatível com
Vulkan, Direct3D 12 ou Metal). Em **Configurações** dá para baixar a qualidade
gráfica se o PC sofrer.

### Controles

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

### O que tem na demo hoje

- **Trilhas e ondas:** quem volta para o formigueiro sai de novo mais tarde; só
  as que você come somem de vez. Quando restam ~90, todas saem de casa.
- **Formigas fogem** quando você chega correndo: chegue andando e lamba de longe.
- **Faro:** mostra as formigas através do capim e aponta o maior grupo na
  bússola.
- **Tanajuras** (douradas, voando) ativam o **Frenesi**: língua mais rápida e
  mais longa por 6 s.
- **Formigas-soldado** aguentam uma lambida antes de grudar (vão sair, pelas
  decisões de 02/11).
- **Árvore da demo:** 3 ramos (Língua, Garras, Corpo) com 4 níveis cada, ou
  seja, 9 pontos para 12 melhorias. Vai virar as 5 habilidades decididas.
- **Sem derrota:** o recorde de tempo fica salvo.

### Qualidade gráfica

| Preset | O que muda |
|---|---|
| Baixa | menos capim, sombras curtas, sem SSAO, resolução 3D a 80% |
| Média | SSAO, sombras médias, MSAA 2x (padrão com vídeo integrado) |
| Alta | capim denso, sombras longas (padrão com placa de vídeo dedicada) |
| Ultra | ainda mais capim, neblina volumétrica, SSIL, MSAA 4x |

A densidade do capim muda ao recomeçar a fase.

---

## Modelos 3D gerados por IA

Tudo na demo funciona com modelos **feitos por código** (formas suaves,
pelagem, folhas recortadas). Para trocar por modelos gerados por IA no mesmo
estilo:

- **[`docs/prompts-ia.md`](docs/prompts-ia.md)**: guia de estilo, paleta e o
  prompt de cada modelo.
- **[`assets/models/LEIA-ME.md`](assets/models/LEIA-ME.md)**: nomes de arquivo
  e ajustes. Basta colocar o `.glb` em `assets/models/` que o jogo troca sozinho.

O **formigueiro** já foi gerado na Artlist (Hyper3D Rodin, com a geração 3D
gratuita da conta) e está no seu histórico de lá. O download do `.glb` exige um
plano com créditos de IA; depois de baixar, salve como
`assets/models/formigueiro.glb`.

---

## Para quem mexe no código

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
docs/                    documento do jogo, prompts de IA e capturas de tela
```

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
