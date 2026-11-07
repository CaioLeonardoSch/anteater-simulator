# Pesquisa: o ciclo de jogo das habilidades e a economia da compra

05/11/2026. Pesquisa pedida na revisão de qualidade de vida (ponto 5). Junta o
que outros jogos e autores de game design dizem com as contas da demo como ela
está hoje. As recomendações estão na seção 4, em ordem de impacto. As seções 5 e 6
trazem a simulação com o bot e a proposta de reformulação da economia. Nada
daqui foi implementado: é material para decidir.

## 1. Como a demo funciona hoje (os números)

- A clareira tem **32 000 insetos**. Cada 10 comidos valem **1 ponto**: são
  **3 200 pontos** no jogo inteiro (as 7 rainhas valem 200 insetos cada).
- As 32 habilidades da área 1 custam **2 755 pontos** no total. Ou seja, o
  jogador consegue comprar tudo com **86%** dos insetos comidos. Os últimos 14%
  (uns 4 450 insetos) não têm mais nada para comprar. Você disse que isso não é
  problema, e a pesquisa concorda (veja a seção 3).
- Os preços vão de 20 (Farejar) a 170 (Lambida Voraz e Terremoto). Dentro de
  cada linha o preço sobe mais ou menos 1,5 vez por nível (40 → 75 → 115 → 170).
- Redistribuir pontos é de graça. A escolha é mais "em que ordem" do que "qual
  caminho para sempre".

### Quando cada habilidade chega (comprando sempre a mais barata disponível)

| Nº | Habilidade | Preço | Insetos comidos | % do jogo |
|---:|---|---:|---:|---:|
| 1 | Farejar | 20 | 200 | 0,6% |
| 2 | Lambida Contínua | 25 | 450 | 1,4% |
| 3 | Língua Certeira | 30 | 750 | 2,3% |
| 4 | Corrida | 30 | 1 050 | 3,3% |
| 5 | Cavar | 35 | 1 400 | 4,4% |
| 10 | Mira Ampla | 60 | 3 750 | 11,7% |
| 16 | Lambida Larga | 75 | 7 800 | 24,4% |
| 22 | **Tremor** | 110 | 13 500 | 42,2% |
| 25 | **Escavação Real** (rainhas) | 120 | 16 950 | 53,0% |
| 28 | Língua Turbo | 150 | 21 050 | 65,8% |
| 32 | Terremoto (a última) | 170 | 27 550 | 86,1% |

Leitura rápida:

- **O começo é bem servido.** Cinco habilidades nos primeiros 4% do jogo. A
  pesquisa recomenda exatamente isso (seção 3).
- **Do meio para o fim, uma habilidade a cada 3% do jogo, mais ou menos.** Como
  o jogador come cada vez mais rápido, em minutos esse intervalo encurta.
- **Dois "verbos novos" grandes chegam tarde.** Tremor (pular e atordoar) chega
  perto dos 42% e a rainha (Escavação Real) perto dos 53%. Antes disso, quase
  tudo o que se compra é "mais do mesmo" (+25%, +50%, mais insetos por lambida).

### Mudança de hoje que mexe na economia

Com os 18 formigueiros, **metade dos insetos agora mora nas câmaras** (antes
eram 26%). Câmara só abre com Cavar. Então:

- sem Cavar, o jogador alcança 50% dos insetos (trilhas e passeios), antes 74%;
- com Cavar e sem Cavar Fundo, ele fica de fora das câmaras dos 7 formigueiros
  grandes;
- Cavar ficou mais importante, e continua barato (35 pontos, 5ª habilidade).
  Isso é bom: o "verbo" Cavar chega cedo e vale muito. Vale confirmar jogando.

## 2. O ciclo de jogo por causa das habilidades

### O ciclo da demo

```
procurar insetos → lamber/cavar → pontos → habilidade → procurar/comer mais rápido
        ↑                                                       │
        └───────────── o mapa vai esvaziando ←──────────────────┘
```

São dois ciclos:

1. **Um que acelera** (os autores chamam de *feedback positivo*). Cada
   habilidade faz comer mais rápido, e comer mais rápido traz a próxima
   habilidade mais cedo.
2. **Um que freia** (*feedback negativo*). O mapa esvazia e os insetos que
   sobram ficam espalhados e mais longe.

Joris Dormans, que criou o Machinations (uma ferramenta para desenhar a
economia de jogos), explica que boa parte do comportamento de um jogo vem
dessas voltas que aceleram ou freiam. Ele avisa que a volta que acelera, sozinha,
"faz o jogo ficar fácil demais". A combinação comum é uma que acelera rápido com
uma que freia devagar. É exatamente o que a demo tem: as habilidades aceleram,
e o esvaziamento do mapa freia no fim.

### O que os jogos parecidos ensinam

- **Katamari Damacy** (crescer comendo o mundo). Os criadores evitaram um
  objetivo único e fixo: tinham medo de que crescer virasse "só um meio para
  chegar lá". Um crítico aponta que o encanto está em várias progressões
  empilhadas, sempre recompensando o que você faz. E diz que o ponto mais forte
  é **voltar a lugares conhecidos e senti-los diferentes** porque você cresceu.
  Para a demo: o mesmo formigueiro deve "virar outro" depois de Cavar Fundo,
  Tremor ou Faro de Câmara. Isso já acontece um pouco (as câmaras escondidas
  aparecem, o monte desmancha).
- **SteamWorld Dig** (cavar, juntar, comprar melhorias). As críticas se
  repetem: o começo arrasta, o fim corre, e **muitas melhorias "não eram
  necessárias", então pareciam inúteis**. Na continuação, os poderes novos
  chegavam "justo quando você começava a se acomodar", e isso foi elogiado.
- **PowerWash Simulator** (limpar 100% e comprar equipamento). O ciclo "ganha e
  gasta" é simples. Os guias dizem que o melhor é melhorar primeiro a
  ferramenta principal e só depois diversificar. É parecido com a demo: a
  língua é a ferramenta principal.
- **Hollow Knight e os metroidvanias.** Uma habilidade boa muda **como você
  anda pelo mundo** e abre lugares que antes estavam fechados (a "chave" e a
  "fechadura"). Cavar, Cavar Fundo e Escavação Real são isso na demo.
  Escalada, na área 2, vai ser também.

### Escolhas que importam numa árvore

Os textos sobre árvores de habilidade concordam em quatro pontos:

1. **Menos nós, mais fortes.** A crítica mais comum a árvores grandes (Diablo
   IV, por exemplo) é ter muitos pontos que são "aumentos pequenos" em vez de
   mudar o jogo.
2. **Cada ramo, um jeito de jogar** (Borderlands é o exemplo citado). Na demo
   os ramos já são jeitos diferentes: Língua (comer), Garras (abrir e
   atordoar), Patas (andar), Faro (achar).
3. **Opção-armadilha e opções iguais tiram o sentido da escolha.** Se todas
   valem a mesma coisa, nenhuma importa.
4. **Árvore pequena funciona** em jogo independente: dá para caprichar em menos
   escolhas.

Como é a demo nesse olhar:

- Das 32 habilidades, **12 são verbos ou mudam uma regra**: Farejar, Lambida
  Contínua, Língua Certeira, Cavar, Cavar Fundo, Escavação Real, Garras Fortes,
  Tremor, Terremoto (puxa os tontos), Corrida, Lamber Correndo e Galope
  Silencioso. Mais 3 mostram coisas novas: Faro Preciso, Faro Nítido e Faro de
  Câmara. **As outras 17 são números** (+%, alcance, recarga, capacidade).
- O ramo **Patas** é o mais curto (4 habilidades, 300 pontos), e tem só um
  verbo (Corrida).
- As pontas de cada linha (as mais caras) são quase todas números maiores
  (Voraz, Turbo, Recarga Relâmpago, Faro Lendário). As exceções são Terremoto,
  que puxa os insetos tontos, e Galope Silencioso.

## 3. A economia da compra

### O modelo clássico (jogos de "incremental")

Anthony Pecorella, da Kongregate, escreveu a referência mais citada sobre a
matemática desses jogos. A ideia central: **o preço cresce multiplicando**
(por exemplo, cada nível custa 1,07 a 1,15 vez o anterior) **enquanto o ganho
cresce somando**. Assim o jogador nunca dispara para longe da curva de preços.
Quando o ganho cresce mais rápido que o preço, o jogo "quebra" (compra-se tudo
de uma vez). Quando o preço cresce rápido demais, aparece o "muro" (esperar
muito por uma compra). Um desenvolvedor contou no itch.io que um salto de preço
no fim criou exatamente esse muro, e que suavizar a subida resolveu.

Para a demo:

- **Os preços sobem 1,5 vez por nível**, e o ganho pode subir mais que isso.
  Só a Lambida vai de 50 a 400 insetos por lambida (8 vezes). A língua fica
  3 vezes mais rápida (×1,25, ×1,25 e ×2). O que segura a aceleração é o
  esvaziamento do mapa, não o preço. Isso é bom num jogo de 1 a 2 horas, mas
  tem um risco: **do meio para o fim, as compras chegarem tão rápido que
  perdem a graça**. Só jogando dá para saber.
- **Primeira recompensa em minutos.** Os guias de progressão dizem que a
  primeira melhoria deve chegar em poucos minutos e que as primeiras devem ser
  as que mais mudam o jogo. A demo cumpre: Farejar com 200 insetos.
- **Curva "rápido no começo, mais lento no fim"** é a recomendada. A sensação
  estranha é a curva plana, em que o fim é tão rápido quanto o começo.

### O fim sem nada para comprar (os últimos 14%)

Você disse que não vê problema, e a pesquisa ajuda a entender por quê. Katamari
e PowerWash terminam numa fase de **completar** (achar os últimos itens), não
de comprar. O que segura essa fase é:

- **ferramentas para achar o que falta**: o Faro com contagem por formigueiro
  e o mapa com insetos por formigueiro, ambos já feitos;
- **uma meta fora da árvore**: recorde de tempo, modo contra o relógio,
  conquistas e estatísticas, feitos hoje.

## 4. Recomendações (da mais impactante para a menos)

1. **Medir antes de mexer.** Gravar no jogo salvo o tempo e os insetos de cada
   compra, e mostrar isso na aba Estatísticas como uma "linha do tempo das
   habilidades". Com 3 ou 4 jogos seus, dá para ver onde a curva tem buraco
   ou muro. É barato: as estatísticas já existem.
2. **Antecipar um verbo grande para o meio do jogo.** Tremor chega com 42% e a
   rainha com 53%. Uma opção é baixar Tremor de 110 para 80 e Escavação Real
   de 120 para 90, e subir um pouco as pontas numéricas (Turbo, Voraz,
   Recarga Relâmpago) para o total quase não mudar. Assim cada terço do jogo
   ganha uma novidade de verdade: Cavar no começo, Tremor e rainha no meio,
   Terremoto e Faro Lendário no fim.
3. **Uma ponta com verbo em cada linha.** Trocar algumas pontas "só número" por
   algo que mude a regra. Ideias, todas no tema:
   - Lambida Voraz também puxa os insetos de uma trilha inteira por alguns
     segundos ("aspirar a fila");
   - Faro Lendário mostra no mapa (TAB) os formigueiros com insetos por perto;
   - Patas ganha um verbo próprio no fim, como "Galope" atravessar lagoas rasas
     ou derrubar capim alto (mais um "lugar que muda" depois da habilidade).
4. **Ramo Patas mais longo.** Com 4 habilidades ele parece um apêndice. Um ou
   dois níveis a mais, com preço médio (60 a 100), equilibram com os outros
   ramos.
5. **Manter o preço subindo 1,5 vez por nível, mas conferir o fim.** Se os
   testes mostrarem compras rápidas demais no fim, a correção clássica é a
   subida por nível ficar um pouco maior só nas pontas (1,6 a 1,8 vez), e não
   mexer no começo.
6. **Não mudar o fim de 14% sem compras.** Está coerente com jogos de
   completar, e agora tem estatísticas, contra o relógio e conquistas para
   segurar essa fase.

## 5. Simulação com o bot (05/11/2026)

Pedido: o bot compra **todas** as habilidades, uma de cada ramo por vez
(Língua, Garras, Patas, Faro, em rodízio; dentro do ramo, a de menor nível e,
empatando, a mais barata), e anota o tempo de cada compra. Se ainda não dá
para pagar a da vez, ele espera juntar os pontos.

Como foi feito: `--autoplay --botlog=arquivo.csv`, acelerado 8 vezes com a
física no passo normal (`--timescale=8 --physics-scale`). Duas partidas
completas, A e B. Os registros estão em `docs/dados/bot-partida-a.csv` e
`bot-partida-b.csv` (compras, formigueiros limpos e o progresso a cada 30 s).

O bot anda até o inseto mais perto, lambe, abre as câmaras que o Cavar dele
alcança, usa o Tremor quando tem 12 ou mais insetos em volta, corre (até perto
do alvo com o Galope Silencioso) e lambe correndo com Lamber Correndo. Ele
**não usa o Faro**, porque já sabe onde está cada inseto. E é pior que uma
pessoa em outras coisas: não planeja o caminho e não procura as câmaras
cheias de propósito. Os tempos servem para ver o **formato** da curva, não o
tempo exato de um jogador.

### Quando cada habilidade foi comprada

| Nº | Habilidade | Preço | Partida A | Partida B | Insetos (média) | % do jogo |
|---:|---|---:|---:|---:|---:|---:|
| 1 | Lambida Contínua | 25 | 2:27 | 2:41 | 250 | 1% |
| 2 | Cavar | 35 | 4:53 | 4:57 | 600 | 2% |
| 3 | Corrida | 30 | 8:04 | 7:25 | 900 | 3% |
| 4 | Farejar | 20 | 9:38 | 9:46 | 1 100 | 3% |
| 5 | Língua Certeira | 30 | 11:47 | 11:34 | 1 400 | 4% |
| 6 | Garras Ágeis | 50 | 14:48 | 15:11 | 1 900 | 6% |
| 7 | Lamber Correndo | 60 | 18:38 | 16:53 | 2 500 | 8% |
| 8 | Faro Atento | 40 | 20:40 | 19:05 | 2 900 | 9% |
| 9 | Lambida | 40 | 22:10 | 21:25 | 3 300 | 10% |
| 10 | Cavar Fundo | 60 | 25:49 | 23:21 | 3 900 | 12% |
| 11 | Patas Ligeiras | 80 | 29:20 | 26:27 | 4 710 | 15% |
| 12 | Faro Preciso | 45 | 31:12 | 28:48 | 5 160 | 16% |
| 13 | Língua Comprida | 70 | 34:38 | 32:15 | 5 850 | 18% |
| 14 | Garras Fortes | 70 | 37:17 | 35:13 | 6 550 | 20% |
| 15 | Galope Silencioso | 130 | 42:16 | 40:15 | 7 850 | 25% |
| 16 | Faro Apurado | 70 | 45:22 | 41:30 | 8 550 | 27% |
| 17 | Mira Ampla | 60 | 48:00 | 44:30 | 9 170 | 29% |
| 18 | Garras Incansáveis | 95 | 51:37 | 48:36 | 10 120 | 32% |
| 19 | Faro Nítido | 85 | 55:05 | 52:52 | 10 950 | 34% |
| 20 | Lambida Larga | 75 | 57:42 | 55:57 | 11 700 | 37% |
| 21 | Tremor | 110 | 62:05 | 60:15 | 12 800 | 40% |
| 22 | Faro de Câmara | 100 | 64:41 | 61:56 | 13 800 | 43% |
| 23 | Saliva Grudenta | 100 | 66:54 | 64:51 | 14 810 | 46% |
| 24 | Escavação Real | 120 | 68:47 | 67:02 | 16 010 | 50% |
| 25 | Faro Aguçado | 110 | 70:44 | 68:21 | 17 110 | 53% |
| 26 | Lambida Gulosa | 115 | 72:17 | 69:45 | 18 260 | 57% |
| 27 | Recarga do Tremor | 130 | 73:26 | 71:28 | 19 550 | 61% |
| 28 | Faro Lendário | 160 | 75:49 | 73:09 | 21 170 | 66% |
| 29 | Língua Turbo | 150 | 77:59 | 75:09 | 22 670 | 71% |
| 30 | Terremoto | 170 | 79:15 | 76:09 | 24 430 | 76% |
| 31 | Lambida Voraz | 170 | 79:48 | 77:03 | 26 090 | 82% |
| 32 | Recarga Relâmpago | 150 | 80:25 | 77:50 | 27 570 | 86% |

Fim: partida A 83:40, partida B 81:18.
Primeiro formigueiro limpo: A 66:46 (46%), B 69:04 (56%).

### O que os números mostram

1. **As duas partidas quase iguais** (81 e 84 minutos). O formato é confiável.
2. **Uma hora de "moagem" e depois uma explosão.** Insetos comidos a cada 10
   minutos (partida A): 1 100, 1 560, 2 070, 2 650, 2 380, 2 430, **4 240,
   9 700**, 5 880. De 30 a 60 minutos o ritmo fica parado (uns 240 por
   minuto), mesmo comprando 12 habilidades nesse meio. Depois dos 65 minutos
   ele passa de 1 000 por minuto.
3. **Metade do jogo leva 67 minutos; a outra metade, 14.** O bot chega a 50%
   dos insetos aos 67–69 minutos e termina aos 81–84.
4. **As compras do meio não aceleram o jogo.** Faro, Garras Ágeis,
   Incansáveis, Patas Ligeiras: nada disso muda quantos insetos entram por
   minuto (para o bot). O que acelera é o que chega depois dos 60 minutos:
   Tremor, Escavação Real, Lambida Gulosa e os bolos de insetos das câmaras.
5. **Os verbos grandes chegam tarde.** Tremor aos 60–62 minutos (40% dos
   insetos), Escavação Real aos 67–69 (50%). A pesquisa já tinha apontado isso
   pelas contas; o bot confirmou.
6. **O fim é corrido.** As últimas 8 compras saem em 8 minutos, e as últimas
   3, em menos de 2. Depois da última (86%), sobram uns 4 minutos sem nada
   para comprar.
7. **Formigueiro limpo só depois da metade.** O primeiro sai aos 67–69
   minutos (46–56% dos insetos); os outros 17 saem nos últimos 15 minutos.
8. **A corrida sem limite pesa.** Depois de Corrida e Lamber Correndo (aos 17
   minutos), o bot corre quase o tempo todo. Isso levou à proposta de
   estamina (seção 6).

## 6. Proposta de reformulação

Nada desta seção foi implementado. É para decidirmos juntos.

### Travar habilidades pelo progresso (avaliação)

A ideia: cada nível de cada linha só abre depois de um tanto de progresso
(formigueiros limpos ou insetos comidos), numa curva como a de Fibonacci.

- **Por formigueiros limpos: não recomendo agora.** No bot, o primeiro
  formigueiro só fica limpo depois da metade do jogo. Limpar um formigueiro
  pede comer até o último inseto, inclusive os que passeiam longe e a rainha
  (que precisa da Escavação Real). Uma trava assim deixaria o jogador uma
  hora sem nada novo. Só faria sentido se o jogo empurrasse a limpar um
  formigueiro de cada vez (por exemplo, com o mapa e o Faro mostrando "faltam
  12 aqui").
- **Por insetos comidos: recomendo, com um papel bem definido.** Uma trava
  por insetos funciona como um "preço que não se gasta". Para quem compra
  equilibrado (como o bot), ela quase nunca segura: refiz as contas com a
  trava e as compras saíram nos mesmos minutos. O que ela faz é **impedir a
  corrida por uma linha só**: sem trava, quem gasta tudo numa linha chega na
  ponta (Lambida Voraz) com uns 17% do jogo; com a trava, só com 66%.
- **A curva:** um número de Fibonacci sim, outro não, em milhares de insetos:
  **nível 1 com 1 000, nível 2 com 3 000, nível 3 com 8 000, nível 4 com
  21 000** (3%, 9%, 25% e 66% do jogo). Na curva do bot, isso cai perto dos
  10, 19, 42 e 74 minutos. A árvore mostraria no cadeado "abre com 8 000
  insetos".

### O que realmente muda o ritmo: preços e a ordem dos verbos

A trava não resolve a "hora parada" do meio nem a explosão do fim. Isso vem do
**que** cada compra faz e de **quando** ela chega:

- **Puxar os verbos grandes para o meio.** Tremor a 100 pontos (hoje 110) e
  Escavação Real a 110 (hoje 120), no nível 2 das linhas. Com os preços abaixo,
  pela curva do bot, o Tremor chegaria perto dos 39 minutos (hoje 61) e a
  rainha perto dos 50 (hoje 68). Isso deve acelerar o meio de verdade, porque
  são justamente o que fez o bot acelerar.
- **Pontas bem mais caras.** As do nível 3 e 4 passam de 110–170 para
  180–260 pontos, para as compras do fim ficarem mais espaçadas.
- **Mais insetos e preços maiores?** Aumentar os dois na mesma proporção não
  muda o ritmo, só os números. O que muda é a relação entre eles. Para caber a
  árvore nova (mais cara), há dois caminhos:
  - **1 ponto a cada 8 insetos** (hoje 10). Dá 4 000 pontos, sem pesar no
    computador. Recomendo este.
  - **40 000 insetos** (hoje 32 000). Mesmo efeito nos pontos, mas o jogo
    fica uns 25% mais longo e mais pesado de desenhar.

**Decisão (05/11/2026):** a clareira passou para **44 000 insetos**, mantendo
1 ponto a cada 10: são 4 400 pontos. A árvore acima (3 850) custaria 88%
deles; os preços finais saem quando a árvore nova for feita.

### Estamina (feita em 05/11/2026)

- Correr existe desde o começo; a habilidade Corrida sai.
- Barra no canto inferior esquerdo, sem número: verde cheia, vai para um
  vermelho-escuro conforme esvazia.
- **Só recarrega sem correr, 1 segundo depois de parar.** Assim nunca dá
  para correr para sempre: no longo prazo, ele corre no máximo pouco mais da
  metade do tempo.
- Três linhas no ramo Patas, com três melhorias cada:

| Linha | Começo | Nível 1 | Nível 2 | Nível 3 |
|---|---|---|---|---|
| Estamina máxima | 50 | 100 | 150 | 200 |
| Gasto correndo (por segundo) | 10 | 8 | 6,5 | 5 |
| Recuperação (por segundo, sem correr) | 3 | 4,5 | 6 | 7 |

| Momento | Corre sem parar | Recarrega do zero | Tempo correndo | Velocidade média |
|---|---|---|---|---|
| Começo | 5 s (21 m) | 17 s | 23% | +6% sobre andar |
| 1 nível de cada | 12 s (52 m) | 22 s | 36% | +9% |
| 2 de cada + Patas Ligeiras | 23 s (114 m) | 25 s | 48% | +24% |
| Tudo comprado | 40 s (quase 200 m) | 29 s | 58% | +29% |
| Hoje, depois da Corrida | sem limite | — | 100% | +25% a +50% |

### Árvore proposta (40 habilidades, 3 850 pontos = 96% dos pontos)

| Nível | Língua | Garras | Patas | Faro |
|---|---|---|---|---|
| 0 (abre já) | Lambida Contínua 25 | Cavar 30 | Estamina 20 · Fôlego 25 · Recuperação 25 | Farejar 20 |
| 1 (1 000 insetos) | Certeira 40 · Lambida 50 · Comprida 70 | Ágeis 50 · Fundo 60 · Fortes 70 | Estamina II 50 · Fôlego II 50 · Recuperação II 50 · Lamber Correndo 60 · Ligeiras 70 | Atento 40 · Preciso 45 |
| 2 (3 000) | Mira Ampla 100 · Larga 100 · Saliva 120 | **Tremor 100** · **Escavação Real 110** · Incansáveis 110 | Estamina III 90 · Fôlego III 90 · Recuperação III 90 · Galope 120 | Apurado 80 · Nítido 90 |
| 3 (8 000) | Gulosa 180 · Turbo 200 | Recarga do Tremor 180 · Terremoto 210 | — | Faro de Câmara 140 · Aguçado 150 |
| 4 (21 000) | Voraz 260 | Recarga Relâmpago 250 | — | Lendário 230 |

("Fôlego" é a linha de gastar menos estamina correndo.)

Pelas contas com a curva do bot, com 1 ponto a cada 8 insetos e a trava: 9
compras nos primeiros 20 minutos, 9 dos 20 aos 40, 6 dos 40 aos 60, e as
outras 16 até o fim; a última com 97% dos insetos. Tremor perto dos 39
minutos e a rainha perto dos 50.

Cuidado com essa conta: ela usa a curva de hoje, com a explosão do fim, então
as últimas compras ainda saem juntas. Na árvore nova o Tremor e a rainha
chegam antes, e isso deve acelerar o meio e suavizar o fim; só medindo para
saber. **Depois de implementar, rodo o bot de novo** com a árvore nova.

## 7. Árvore feita (05/11/2026): travas e preços

Decidido com o Caio, depois das contas acima:

- **Cinco travas**, em insetos comidos: **1 000, 3 000, 8 000, 13 000 e
  21 000** (números de Fibonacci; cada um cerca de 1,6 a 2,6 vezes o
  anterior). O começo de cada ramo não tem trava. Cada habilidade tem a sua:
  as linhas curtas e de apoio terminam até 13 000, e as pontas mais fortes
  ficam para 21 000.
- **O Tremor virou uma linha própria**, que sai de Força nível 1: Tremor
  nível 1 (o pulo), nível 2 (recarga de 14 s) e nível 3 (Terremoto, recarga
  de 7 s). Força ganhou um nível 2 (tontas por 4 s) e Rapidez ficou só com
  o descanso das garras.

**A regra dos preços.** Quem compra de tudo um pouco deve terminar de pagar o
que uma trava abriu **bem quando a seguinte abre**. Ou seja, a soma dos preços
de tudo o que já abriu é igual aos pontos ganhos até a próxima trava (10
insetos = 1 ponto). Assim a trava quase nunca segura quem compra equilibrado,
mas segura quem gasta tudo numa linha só. Dentro de cada faixa, o preço segue
a conta "pontos por minuto × minutos até a próxima compra", mirando uma
compra a cada 1,5 a 2 minutos.

| Trava | Habilidades que abrem | Soma dos preços | Soma até aqui | Pontos ao abrir a próxima | Minuto aproximado* |
|---|---|---|---|---|---|
| começo | Lambida Contínua 25 · Cavar 35 · Fôlego 1 20 · Farejar 20 | 100 | 100 | 100 | 0 |
| 1 000 | Bocado 1 40 · Mira 1 30 · Rapidez 1 30 · Respiro 1 30 · Passada 1 30 · Alcance 1 40 | 200 | 300 | 300 | 7 |
| 3 000 | Bocado 2 80 · Destreza 1 70 · Mira 2 60 · Força 1 55 · Fundura 1 60 · Corrida 1 60 · Fôlego 2 50 · Precisão 1 50 | 485 | 785 | 800 | 17 |
| 8 000 | Destreza 2 90 · Força 2 50 · **Tremor 1 100** · Rapidez 2 80 · Respiro 2 60 · Passada 2 60 · Alcance 2 70 | 510 | 1 295 | 1 300 | 33 |
| 13 000 | Bocado 3 120 · Tremor 2 100 · **Fundura 2 (rainha) 120** · Corrida 2 90 · Respiro 3 70 · Passada 3 70 · Fôlego 3 80 · Alcance 3 100 · Precisão 2 80 | 830 | 2 125 | 2 100 | 48 |
| 21 000 | Bocado 4 320 · Destreza 3 300 · Tremor 3 330 · Corrida 3 250 · Alcance 4 260 · Precisão 3 240 | 1 700 | 3 825 | 4 400 (fim) | 66 |

\* Pela curva do bot antigo, ajustada para 44 000 insetos. A árvore nova
deve mudar essa curva (o Tremor chega perto dos 33 minutos, antes 61, e a
rainha perto dos 48, antes 68), então os minutos são só um ponto de partida.

As 40 habilidades custam **3 825 pontos (87% dos 4 400)**. Com as pontas a
21 000, os últimos 1 700 pontos chegam por volta de 38 000 insetos: sobra
um pedaço do fim para usar as habilidades mais fortes.

O bot rodou com a árvore nova em 06/11/2026: resultados na seção 8.

## 8. Bot com a árvore nova (06/11/2026)

O mesmo bot da seção 5 (compra em rodízio entre os ramos, acelerado 8 vezes
com a física no passo normal), agora com 44 000 insetos, estamina, travas e
os preços novos. Duas partidas completas; os registros estão em
`docs/dados/bot-arvore-nova-a.csv` e `bot-arvore-nova-b.csv` (agora também
com uma linha quando cada trava abre).

**Resumo:** a clareira ficou limpa em **68 e 73 minutos** (antes 81–84, com
27% menos insetos). As 40 habilidades foram compradas, a última com **87%**
dos insetos, como planejado.

### Quando cada trava abriu

| Trava | Previsto | Partida A | Partida B |
|---|---:|---:|---:|
| 1 000 | 7 min | 5:49 | 7:31 |
| 3 000 | 17 min | 15:58 | 17:45 |
| 8 000 | 33 min | 37:11 | 41:24 |
| 13 000 | 48 min | 44:56 | 49:09 |
| 21 000 | 66 min | 53:29 | 59:53 |

### O ritmo (insetos comidos por minuto, em cada faixa de 10 minutos)

| Minutos | Árvore antiga (A / B) | Árvore nova (A / B) |
|---|---|---|
| 0–10 | 109 / 107 | 151 / 130 |
| 10–20 | 157 / 192 | 216 / 211 |
| 20–30 | 207 / 229 | 231 / 192 |
| 30–40 | 265 / 244 | 301 / 239 |
| 40–50 | 238 / 256 | 918 / 555 |
| 50–60 | 243 / 242 | 1 005 / 761 |
| 60–70 | 424 / 551 | 1 562 / 1 722 |

### Compras que importam

| Habilidade | Árvore antiga | Árvore nova (A / B) |
|---|---|---|
| Tremor (Tremor nível 1) | 61 min | 45 / 49 min |
| Rainha (Fundura nível 2) | 68 min | 47 / 51 min |
| Primeiro formigueiro limpo | 46–56% dos insetos | 41% / 39% |
| Última compra | 86% dos insetos | 87% / 87% |

### O que aprendemos

- **A regra dos preços funcionou.** O bot quase nunca ficou com pontos
  parados (até o minuto 60, no máximo 66 sobrando): ele gasta o que ganha, e
  a trava abre mais ou menos quando ele termina a faixa anterior. Entre uma
  compra e outra, quase sempre 1 a 3 minutos (o maior intervalo: 4,3 min).
- **A "hora parada" encolheu, mas não sumiu.** Antes o ritmo ficava parado
  dos 30 aos 60 minutos; agora fica parado dos 20 aos 40 (uns 200 a 300
  insetos por minuto). Ele acelera logo depois da trava de 8 000, com Bocado
  nível 2, Destreza nível 2 e Rapidez nível 2, antes mesmo do Tremor.
- **A trava de 8 000 abriu mais tarde que o previsto** (37 e 41 min, contra
  33), justamente na fase parada. As de 13 000 e 21 000 abriram mais cedo,
  porque o fim acelera muito.
- **O fim continua rápido demais.** Dos 60 minutos em diante o bot come 5 a
  7 vezes mais rápido que no meio. As habilidades de 21 000 chegam aos 54–60
  minutos, mas a última (Bocado nível 4) só fica uns 2 a 3 minutos em uso.

Lembrando: o bot não usa o Faro e não planeja o caminho, então os minutos
servem para comparar as árvores, não como o tempo de um jogador.

## 9. Nós com vários cliques (07/11/2026, aprovada e feita)

Vem da primeira jogatina do Caio com 1 inseto por lambida (versão 0.1.2,
46 minutos, 21 419 insetos). O que os números dele mostram:

- **Começo parado.** Nos primeiros 13 minutos foram só 3 compras: comendo 1
  inseto por lambida, a trava de 1 000 só abriu aos 13:46.
- **Fim com pontos sobrando.** Depois dos 32 minutos, os pontos foram de 157
  para 416 sem ter o que comprar: as travas seguravam.
- **Pedidos:** upgrades menores entre os que existem (vários cliques num nó
  antes de abrir o seguinte), revisar as travas, Bocado 2 → 3 → 5 mais cedo,
  Respiro 3 → 5 → 7, separar o alcance da velocidade da língua, Mira mais útil,
  Farejar mais para frente e Destreza nível 1 menos forte.

### Como fica

- **Cada nó tem de 1 a 3 cliques.** Cada clique é uma melhora pequena e
  barata, mostrada com bolinhas em volta do nó (●●○) e o "antes → depois" de
  sempre. O nó seguinte da linha só abre quando o anterior estiver completo
  (e a trava dele tiver aberto).
- **Os mesmos 40 nós**, agora com **75 cliques** (hoje são 40 compras). A
  árvore continua do mesmo tamanho na tela.
- **Nove travas** (eram cinco): **200, 500, 1 000, 2 000, 3 000, 5 000, 8 000,
  13 000 e 21 000** insetos. As primeiras chegam em poucos minutos.
- **A Língua ganha uma linha:** Bocado (quantos por lambida), Destreza (só a
  velocidade), **Comprimento** (só o alcance) e Mira.
- **Farejar só abre com 3 000 insetos.**
- **Total: 4 227 pontos (96% dos 4 400).** Hoje são 3 825.

### Os nós

| Ramo | Nó | Trava | Cliques (preço de cada) | O que cada clique dá |
|---|---|---|---|---|
| Língua | Lambida Contínua | — | 15 | segurar para lamber |
| | Bocado 1 | 200 | 8 · 12 · 16 | 2 → 3 → 5 insetos por lambida |
| | Bocado 2 | 2 000 | 30 · 40 · 50 | 8 → 11 → 15 |
| | Bocado 3 | 8 000 | 70 · 90 | 20 → 25 |
| | Bocado 4 | 21 000 | 160 · 200 | 32 → 40 |
| | Destreza 1 | 500 | 10 · 14 · 18 | 1,4 → 1,6 → 1,8 → 2,0 lambidas por segundo |
| | Destreza 2 | 5 000 | 50 · 60 · 70 | 2,4 → 2,8 → 3,2 |
| | Destreza 3 | 21 000 | 260 | 4,4 |
| | Comprimento 1 | 1 000 | 16 · 20 · 24 | língua de 3,0 → 3,3 → 3,6 → 3,9 m |
| | Comprimento 2 | 8 000 | 60 · 80 | 4,2 → 4,5 m |
| | Mira 1 | 200 | 12 | a língua vai atrás do inseto; área da mira de 15° (hoje 10°) |
| | Mira 2 | 3 000 | 25 · 30 · 35 | área de 18° → 21° → 25° |
| | Mira 3 | 13 000 | 110 | a ponta gruda num raio 70% maior |
| Garras | Cavar | — | 25 | abre câmaras pequenas; descanso de 25 s |
| | Rapidez 1 | 1 000 | 12 · 16 · 20 | descanso de 20 → 16 → 12 s |
| | Rapidez 2 | 8 000 | 40 · 50 · 60 | 9 → 7 → 5 s; no último, cava na metade do tempo |
| | Força 1 | 2 000 | 25 · 35 | moradoras tontas por 1,5 → 2,5 s |
| | Força 2 | 8 000 | 40 · 50 | 3,2 → 4 s |
| | Tremor 1 | 5 000 | 90 | libera o Tremor (recarga de 21 s) |
| | Tremor 2 | 13 000 | 45 · 55 · 65 | recarga de 18 → 15 → 12 s |
| | Tremor 3 | 21 000 | 300 | Terremoto (recarga de 7 s) |
| | Fundura 1 | 3 000 | 60 | câmaras grandes |
| | Fundura 2 | 13 000 | 120 | o monte da rainha |
| Patas | Fôlego | — | 10 | estamina de 50 → 75 |
| | Fôlego 1 | 1 000 | 12 · 16 · 20 | 100 → 125 → 150 |
| | Fôlego 2 | 13 000 | 50 · 60 | 175 → 200 |
| | Respiro 1 | 200 | 8 · 12 | a estamina volta 3 → 4 → 5 por segundo |
| | Respiro 2 | 3 000 | 30 · 40 | 6 → 7 por segundo |
| | Passada 1 | 500 | 8 · 12 · 16 | correndo gasta 10 → 9 → 8 → 7 por segundo |
| | Passada 2 | 5 000 | 40 · 50 | 6 → 5 por segundo |
| | Corrida 1 | 2 000 | 25 · 35 | corre +10% · +10% mais rápido |
| | Corrida 2 | 13 000 | 90 | lamber correndo |
| | Corrida 3 | 21 000 | 250 | correr não assusta |
| Faro | Farejar | 3 000 | 25 | fareja a 10 m; a bússola aponta o maior grupo |
| | Alcance 1 | 3 000 | 15 · 20 · 25 | fareja a 13 → 16 → 20 m |
| | Alcance 2 | 8 000 | 55 · 70 | 26 → 34 m; no último, a bússola conta os formigueiros |
| | Alcance 3 | 21 000 | 220 | 50 m e marca as rainhas |
| | Precisão 1 | 5 000 | 45 | nuvem de cheiro |
| | Precisão 2 | 8 000 | 75 | insetos nítidos atrás do capim |
| | Precisão 3 | 13 000 | 200 | mostra as câmaras fechadas |

### Por trava

| Trava | Nós que abrem | Cliques | Soma dos preços | Soma até aqui | Pontos quando a próxima trava abre |
|---|---|---|---|---|---|
| começo | 3 | 3 | 50 | 50 | 20 |
| 200 | 3 | 6 | 68 | 118 | 50 |
| 500 | 2 | 6 | 78 | 196 | 100 |
| 1 000 | 3 | 9 | 156 | 352 | 200 |
| 2 000 | 3 | 7 | 240 | 592 | 300 |
| 3 000 | 5 | 10 | 305 | 897 | 500 |
| 5 000 | 4 | 7 | 405 | 1 302 | 800 |
| 8 000 | 6 | 12 | 740 | 2 042 | 1 300 |
| 13 000 | 6 | 9 | 795 | 2 837 | 2 100 |
| 21 000 | 5 | 6 | 1 390 | 4 227 | 4 400 (fim) |

Desta vez, cada trava abre mais coisa do que dá para pagar até a próxima.
Ou seja, quase sempre tem algo para comprar, e o que segura é o ponto, não
a trava. As travas servem para pôr ordem (o forte fica para o fim), não para
fazer esperar. Os preços são um ponto de partida: depois de feito, o bot
roda de novo para acertar.

### Decidido junto

- **Assustar os insetos.** Eles fugiam a 1 m de você parado e a 1,9 m
  andando, e a língua já alcançava 3 m: alcance maior não fazia diferença.
  Agora fogem a **2,5 m andando** (1 m parado, como antes), e correndo um
  pouco mais longe que antes (a conta mudou de ×1,8 para ×1,5 para não
  exagerar). Assim o Comprimento vale a pena.
- **Jogos salvos.** Os nós mudaram de nome e de preço. Ao abrir um jogo
  salvo antigo, os pontos gastos voltam (como no "Redistribuir pontos"), com
  o aviso "Árvore nova · Seus pontos voltaram" na tela.

### Como ficou no jogo

- Na árvore, as bolinhas ficam em cima do círculo (cheias = compradas). O
  quadro da habilidade mostra "2 de 3 cliques", o "antes → depois" só do
  próximo clique e "O 3º clique custa 18 pontos". Uma habilidade com alguns
  cliques já ganha a cor do ramo; completa, fica dourada.
- Os ramos da Língua e das Patas ficaram um pouco mais afastados (a Língua
  agora tem 4 linhas), e a linha de Comprimento tem um ícone novo (uma régua
  com setas).
- O cartão "Aprendida" vira "Clique 2 de 3" e "Completa".

## Fontes

- Anthony Pecorella, "The Math of Idle Games",
  [parte I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i),
  [parte II](https://www.gamedeveloper.com/disciplines/the-math-of-idle-games-part-ii) e
  [parte III](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii);
  [palestra "Quest for Progress" (GDC Europe 2016)](https://de.slideshare.net/AnthonyPecorella/quest-for-progress-gdc-europe-2016)
- [Balancing tips: how we managed math on Idle Idol](https://gamedeveloper.com/design/balancing-tips-how-we-managed-math-on-idle-idol)
- Joris Dormans, [Engineering Emergence (tese, 2012)](https://eprints.illc.uva.nl/id/eprint/2118/);
  [Machinations, a new way to design game mechanics](https://gamedeveloper.com/design/the-designer-s-notebook-machinations-a-new-way-to-design-game-mechanics);
  [capítulo de Game Mechanics: Advanced Game Design](https://ptgmedia.pearsoncmg.com/imprint_downloads/peachpit/peachpit/samplechapters/0321820274/0321820274_gamemechanics_ch05section.pdf)
- [How Feedback Loops Shape Game Economies](https://adriancrook.com/?p=8170)
- [Postmortem: The singular design of Namco's Katamari Damacy](https://gamedeveloper.com/design/postmortem-the-singular-design-of-namco-s-katamari-damacy-2004-);
  [Katamari Damacy: Keep Going (Unwinnable)](https://unwinnable.com/2019/01/23/katamri-damacy-keep-going/)
- SteamWorld Dig: [críticas no Backloggd](https://www.backloggd.com/reviews/everyone/eternity/recent:desc/steamworld-dig/),
  [Game Informer sobre o 2](https://gameinformer.com/games/steamworld_dig_2/b/switch/archive/2017/09/28/steamworld-dig-2-review)
- PowerWash Simulator: [dinheiro e melhorias (Ludo Guide)](https://www.ludo.guide/guide/powerwash-simulator/earning-money-upgrades),
  [dicas para iniciantes (Game Rant)](https://gamerant.com/powerwash-simulator-beginner-tips/)
- Metroidvanias: [How to design a great Metroidvania map (PC Gamer)](https://www.pcgamer.com/uk/how-to-design-a-great-metroidvania-map),
  [Metroidvania Analysis (HSLU)](https://blog.hslu.ch/games/files/2021/11/Metroidvania_Analysis.pdf)
- Árvores de habilidade: [The problem with skill trees](https://www.wayline.io/blog/the-problem-with-skill-trees),
  [Paradox of choice](https://www.wayline.io/blog/paradox-of-choice-less-customization),
  [Design Dive 20](https://designdive.substack.com/p/design-dive-20)
- Ritmo das recompensas: [Player progression (Abratabia)](https://abratabia.com/game-economy/player-progression.php),
  [muro de preço no fim (itch.io)](https://itch.io/post/15330988),
  [Power progression in games](https://gamedeveloper.com/design/power-progression-in-games-crafting-rewarding-player-experiences)
