# Pesquisa: o ciclo de jogo das habilidades e a economia da compra

05/11/2026. Pesquisa pedida na revisão de qualidade de vida (ponto 5). Junta o
que outros jogos e autores de game design dizem com as contas da demo como ela
está hoje. As recomendações estão no fim, em ordem de impacto. Nada daqui foi
implementado: é material para decidir.

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
