# Prompts para gerar os modelos 3D com IA

Este guia traz um prompt para cada modelo do jogo, todos no mesmo estilo:
**animação 3D estilizada** (cara de longa de animação), no **cerrado ao entardecer**.

O jogo já roda sem nenhum modelo de IA: tudo tem uma versão provisória feita por
código. Cada arquivo `.glb` que você colocar em `assets/models/` com o nome certo
**substitui automaticamente** a versão provisória: o modelo é centralizado,
apoiado no chão e escalado para o tamanho certo. Detalhes técnicos em
[`assets/models/LEIA-ME.md`](../assets/models/LEIA-ME.md).

---

## 1. Guia de estilo (vale para todos os modelos)

**Direção de arte**: formas esculpidas e arredondadas, proporções levemente
exageradas, silhuetas fáceis de ler, cores quentes e saturadas, textura com leve
toque pintado à mão. Nada de low poly, nada de pixel art, nada de realismo
fotográfico.

**Paleta do cerrado ao entardecer**

| Uso | Cor |
|---|---|
| Terra vermelha / barro | `#B5603A` |
| Terra batida das trilhas | `#C9956A` |
| Capim dourado | `#E8C46A` |
| Folhas (verde-oliva) | `#6A8F3A` |
| Ipê-amarelo | `#F6C431` |
| Ipê-roxo | `#C77FB0` |
| Formiga saúva (marrom-ferrugem) | `#6B2412` |
| Céu lilás do fim de tarde | `#B9A7D6` |

**Sufixo de estilo**: cole no fim de todo prompt (em inglês, que é como os
geradores entendem melhor):

```
stylized 3D animated feature film style, soft sculpted rounded forms, slightly
exaggerated proportions, appealing readable silhouette, warm saturated colors,
subtle hand-painted texture detail, even neutral lighting, no baked shadows or
highlights in the texture, clean topology, game-ready asset, single object,
centered, isolated on a plain background
```

> **Por que "even neutral lighting, no baked shadows"?** O jogo já tem o sol do
> fim de tarde, sombras e brilho. Se a textura vier com luz "pintada", o modelo
> fica com sombra dupla e destoa do cenário.

### Fluxo recomendado (melhor controle do estilo)

1. **Imagem conceito**: gere uma imagem do objeto com o prompt + sufixo de estilo,
   em vista 3/4, fundo liso, bem iluminado.
2. **Imagem → 3D**: use a imagem aprovada num gerador *image-to-3D* (Hyper3D
   Rodin, Meshy, Tripo ou Hunyuan 3D) em qualidade **alta**.
3. **Baixe em `.glb`**, renomeie conforme a tabela abaixo e coloque em
   `assets/models/`. Ao abrir o projeto, o Godot importa o arquivo sozinho.

Também dá para ir direto de texto para 3D (*text-to-3D*) com os mesmos prompts:
é mais rápido, mas o estilo varia mais entre um modelo e outro.

> **Custo de referência (Artlist):** na cotação feita durante o desenvolvimento,
> um modelo 3D em qualidade alta no Hyper3D Rodin custava **300 créditos**. O
> formigueiro saiu de graça porque usamos a geração de teste da conta.

---

## 2. Lista de modelos

| Arquivo | O que é | Onde aparece | Prioridade |
|---|---|---|---|
| `formigueiro.glb` | Monte de terra das saúvas | 5 formigueiros do mapa | **já gerado** |
| `formiga_operaria.glb` | Saúva operária | centenas na tela | alta |
| `formiga_soldado.glb` | Saúva soldado (cabeçuda) | ~10% das formigas | alta |
| `formiga_tanajura.glb` | Tanajura (rainha alada) | raras, ativam o Frenesi | média |
| `tamandua_focinho.glb` | Focinho visto pelos olhos | 1ª pessoa, o tempo todo | alta |
| `tamandua.glb` | Tamanduá-bandeira inteiro | menu inicial | média |
| `cupinzeiro.glb` | Torre de barro de cupins | ~15 no mapa | média |
| `arvore_cerrado.glb` | Árvore torta do cerrado | ~16 + horizonte | média |
| `ipe_amarelo.glb` | Ipê-amarelo florido | 3 marcos + horizonte | média |
| `ipe_roxo.glb` | Ipê-roxo florido | 1 marco | baixa |
| `pedra.glb` | Pedra arredondada | ~22 | baixa |
| `arbusto.glb` | Arbusto folhoso | ~25 (onde as saúvas cortam folhas) | baixa |
| `tronco_caido.glb` | Tronco caído | 4 | baixa |

---

## 3. Prompts

### `formigueiro.glb`: formigueiro de saúva (já gerado)

Gerado com o **Hyper3D Rodin v2.5 Fast** (text-to-3D, qualidade alta) usando a
geração 3D gratuita da conta. Ele está no seu histórico da Artlist; **para
baixar o `.glb` é preciso um plano com créditos de IA**. Depois de baixar,
renomeie para `formigueiro.glb` e coloque em `assets/models/`.

Prompt usado:

```
Stylized ant nest mound for a 3D animated feature film. A wide, low, rounded
dome of loose red-ochre Brazilian cerrado soil, sculpted from many small soft
clumps and crumbs, with five dark tunnel entrance holes, each ringed by a small
raised crater rim, spread over the surface. A few smooth rounded pebbles and
short tufts of dry golden grass at the base. Soft sculpted forms, slightly
exaggerated proportions, warm saturated terracotta and orange-brown colors,
subtle hand-painted texture detail, clean readable silhouette. Single game-ready
prop, centered, isolated, no background.
```

No jogo: ~3,8 m de largura × 0,6 m de altura (escala automática).

### `formiga_operaria.glb`: saúva operária

```
Leafcutter ant worker (Brazilian "saúva", Atta), cute but believable, large
heart-shaped head, big glossy dark eyes, small curved mandibles, slender
elbowed antennae, short thorax with two tiny spines, round glossy abdomen,
six thin legs spread wide in a symmetrical neutral standing pose with every
leg clearly separated from the body and from the other legs, rusty red-brown
glossy chitin with slightly darker abdomen, facing forward, no leaf in the
mouth, low polygon budget for crowds
```
+ sufixo de estilo.

**Importante:** pernas bem afastadas do corpo e entre si. O jogo anima as pernas
sozinho, reconhecendo-as pela posição; pernas coladas no corpo não se mexem
direito. Mantenha **até ~4 mil triângulos**, porque podem aparecer centenas ao
mesmo tempo (no gerador, use qualidade média ou peça "low polygon budget").

### `formiga_soldado.glb`: saúva soldado

```
Leafcutter ant soldier (Brazilian "saúva" soldier caste), huge heart-shaped
head almost twice the size of the body, massive curved crushing mandibles,
small dark glossy eyes, short elbowed antennae, compact thorax, six sturdy legs
spread wide in a symmetrical neutral standing pose clearly separated from the
body, deep crimson to dark brown glossy chitin, tough and grumpy but appealing,
facing forward, low polygon budget for crowds
```
+ sufixo de estilo. Mesmas regras de pernas e de polígonos da operária.

### `formiga_tanajura.glb`: tanajura (içá)

```
Winged leafcutter ant queen (Brazilian "tanajura" or "içá"), big round glossy
amber-orange abdomen with soft golden bands, heart-shaped head with big dark
eyes, elbowed antennae, four long transparent iridescent wings folded back
along the body, six legs spread wide in a symmetrical neutral pose clearly
separated from the body, warm amber and chestnut colors, charming and slightly
plump, facing forward
```
+ sufixo de estilo. Observação: num modelo único as asas ficam paradas (no
modelo feito por código elas batem). Se o gerador permitir, peça as asas com
transparência no material.

### `tamandua_focinho.glb`: focinho em primeira pessoa

```
Front part of a giant anteater head only, isolated: the long narrow tubular
snout seen from the eyes, slightly curved downward, tapering to a tiny round
mouth at the tip with two small nostrils on top, short soft grizzled fur in
warm grey-brown getting darker and almost black near the tip, smooth dark skin
at the very tip, no eyes, no ears, no body, the snout points straight forward
```
+ sufixo de estilo.

No jogo: o focinho aponta para **-Z** (para a frente), com a boca na ponta. Ele
é escalado para ~62 cm de comprimento e a ponta é encaixada onde a língua sai.
Se aparecer virado, use `rotacao_y=180` no `ajustes.cfg`.

### `tamandua.glb`: tamanduá-bandeira inteiro (menu)

```
Giant anteater (Brazilian "tamanduá-bandeira"), full body, standing on all
fours in a calm neutral pose, very long narrow tubular snout, small round ears,
small kind eyes, thick coarse grey-brown fur, the iconic diagonal black stripe
with white borders running from the chest over the shoulders, pale front legs
with a black band at the wrist and big curved claws folded under, huge bushy
fan-shaped tail, endearing and expressive like a hero character of an animated
movie
```
+ sufixo de estilo. Aparece posando ao lado da trilha na tela inicial (~2,2 m).

### `cupinzeiro.glb`: cupinzeiro

```
Tall termite mound of the Brazilian cerrado, an irregular rounded tower of
hardened red-orange clay built from stacked soft lumps, a couple of smaller
side turrets, subtle vertical streaks and darker earth patches, a few tiny
tufts of dry grass at the base
```
+ sufixo de estilo. No jogo: 0,9 a 2,4 m de altura.

### `arvore_cerrado.glb`: árvore do cerrado

```
Small twisted cerrado tree (like a pequi or lixeira tree), thick crooked trunk
with deep corky grey-brown bark, gnarled branches spreading sideways, canopy
made of a few soft rounded clumps of olive-green leaves with lighter
yellow-green edges, sparse and airy, about six meters tall
```
+ sufixo de estilo. No jogo: 4,5 a 6,5 m. Folhas com recorte (alpha) funcionam bem.

### `ipe_amarelo.glb`: ipê-amarelo florido

```
Yellow ipê tree in full bloom (Brazilian ipê-amarelo, Handroanthus), slender
dark grey trunk and upward-reaching branches, no leaves, canopy made of dense
rounded clusters of bright golden-yellow trumpet flowers, a few petals falling,
about eight meters tall
```
+ sufixo de estilo.

### `ipe_roxo.glb`: ipê-roxo florido

Mesmo prompt do ipê-amarelo, trocando as flores por:
`dense rounded clusters of pink-purple trumpet flowers (Brazilian ipê-roxo)`.

### `pedra.glb`: pedra

```
Smooth rounded sandstone boulder, soft sculpted shape, warm grey-beige stone
with a few yellow-green lichen spots on top, partially sunken base
```
+ sufixo de estilo.

### `arbusto.glb`: arbusto

```
Round leafy cerrado shrub, several soft clumps of glossy olive and fresh green
leaves on thin woody stems, a few leaves with small bite-shaped cuts made by
leafcutter ants, about one meter tall
```
+ sufixo de estilo.

### `tronco_caido.glb`: tronco caído

```
Fallen dry tree log lying on the ground, crooked and slightly twisted, thick
corky grey-brown bark peeling in places, patches of soft green moss on top, one
short broken branch sticking up, about four meters long, lying horizontally
along the X axis
```
+ sufixo de estilo.

---

## 4. Checklist antes de colocar no jogo

- [ ] Formato `.glb` (GLB binário com texturas embutidas).
- [ ] Nome exatamente como na tabela (minúsculas, sem acento).
- [ ] Um objeto só, sem chão nem pedestal embaixo.
- [ ] Formigas: pernas separadas e até ~4 mil triângulos.
- [ ] Abriu o projeto no Godot e esperou a importação terminar.
- [ ] Ficou virado, grande ou pequeno demais? Ajuste em `assets/models/ajustes.cfg`.
