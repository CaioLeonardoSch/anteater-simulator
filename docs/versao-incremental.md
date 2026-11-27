# A versão incremental: uma área gigante (plano de desenvolvimento)

Escrito em 27/11/2026, a partir do pedido do Caio e das 12 respostas dele no
mesmo dia (nome provisório no menu: **Banquete**). **Nada disto está feito
ainda.** Sobre a ideia original (a demo da área 1 e as 4 áreas), vale o
[`DESIGN.md`](DESIGN.md); sobre a versão incremental, vale este arquivo.

**Não é um modo a mais: é a outra opção do jogo.** Durante o teste, as duas
ficam no menu. Depois fica **uma ou outra**: se o Caio gostar mais da versão
incremental, o jogo segue só com ela, que tem **uma área só, gigante**, no
lugar das 4.

Números marcados como **estimativa** são contas feitas aqui, sem medir; o
simulador da etapa B0 (seção 10) existe para trocá-los por números medidos.

---

## 1. Resumo: a recomendação primeiro

- **Dá para fazer, e o momento é bom.** Quatro dos seis jogos que o Caio
  citou são incrementais em 1ª pessoa com o mesmo formato: um gesto feito à
  mão que passa de 1 por vez a centenas de uma vez, e ferramentas que mudam o
  gesto; três deles ainda têm um espaço finito para esvaziar e um fim
  escondido (seção 6). O tamanduá já tem o gesto (a língua) e o espaço (os
  ninhos).
- **Uma área de uns 250 m de ponta a ponta**: umas 5 vezes a largura da área
  1 (cruzar a pé leva 1 minuto e meio). Cabe no jeito que o jogo monta o
  mundo hoje, com ajustes nos tamanhos que o código supõe (seção 9.1).
- **Meta: 1 milhão de insetos**, uns 70% dentro do cupinzeiro (estimativa).
  Com esse número, **cada inseto na tela continua sendo um só**, como desde
  05/11/2026. Só o que está fora da tela ou longe vira número (como as
  moradoras das câmaras fechadas de hoje) ou o desenho simples de longe.
- **Sem automação, quem acelera é o gesto.** Como no Punch The Walls ("de
  poucos cubos por soco a centenas de uma vez"), cada habilidade grande troca
  o gesto: lamber 1, lamber vários, cavar, puxar do buraco, empinar, sacudir a
  árvore, rasgar o tronco, varrer o chão da sala com a língua (seção 7.4).
- **Primeiro a ferramenta e um pedaço que testa a ideia**: um simulador da
  economia que prova que dá para chegar ao fim sem travar, e uma fatia
  jogável de 30 minutos (campo, um tronco caído, uma árvore-ninho e um andar
  do cupinzeiro). **A fatia é o ponto de decisão**: o Caio joga a fatia e a
  área 1 e escolhe com qual versão o jogo segue (seção 4).
- **O risco que mais preocupa**: com 1 milhão, a força do fim fica umas 2 a 3
  vezes a do fim da área 1 (estimativa: umas 100 formigas por lambida contra
  40). O "número subindo" vem mais do total e das salas cheias do que de cada
  lambida. O simulador mostra se basta; se não, sobe a meta até onde a tela
  aguenta (seção 15).

---

## 2. O que o Caio decidiu (27/11/2026)

| Assunto | Decidido |
|---|---|
| O que é | **Uma versão alternativa do jogo**, não um modo a mais: um mapa novo, à parte, com **uma área só, gigante**. No teste, fica como segunda opção no menu; depois, ou ela ou a ideia original |
| Mapa | Um começo com cara de área 1, uma mata densa e escura (a maior parte) e o cupinzeiro gigante |
| Tamanho | **Uns 250 m** de ponta a ponta |
| Fim | **Meta gigante com fim**: acaba ao comer o último cupim do cupinzeiro |
| A meta | **1 milhão de insetos** ("pode ser o suficiente") |
| Insetos na tela | **Cada um é um só**; juntar em número só o que não está na tela e o que está longe |
| Automação | **Nenhuma**: tudo pela língua; as habilidades só deixam o tamanduá mais rápido e mais forte |
| "Tudo disponível" | **Mapa aberto desde o começo, trava por força**: os ninhos maiores e as salas pedem níveis mais altos |
| O ciclo | "Lamber insetos para ganhar pontos, comprar níveis que multiplicam quanto cada lambida e cada cavada rendem, e com isso abrir ninhos cada vez mais duros (árvores, troncos, salas do cupinzeiro) até comer o último cupim do cupinzeiro gigante." |
| Duração | **4 a 6 horas** até o fim |
| Andares do cupinzeiro | **Sobem a torre**; no topo, a sala da rainha-mãe, com a vista do cerrado |
| Ninhos no alto das árvores | **Empinar e derrubar**: o tamanduá fica em pé nas patas de trás para lamber até uns 2,5 m, e as garras rasgam troncos ou sacodem a árvore para as formigas caírem. Sem escalada |
| Referências | SHRED A BILLION, Punch The Walls, Find The Needle, Potato Please, We March as One e Dungeonbound |

---

## 3. Premissas (o que este plano supõe)

Se alguma estiver errada, o plano muda.

1. **Mesmo motor e mesmo estilo**: Godot 4.7 (Forward+), 3D estilizado, 1ª
   pessoa, interface Constelação, os mesmos controles e a mesma história (o
   tamanduá acorda numa caverna, vê o cupinzeiro gigante e a barriga ronca).
2. **No teste, as duas versões ficam no menu**: "Jogar" (a original) e
   "Banquete" (a nova). Depois da decisão, a que perdeu sai do jogo e do código.
3. **PC (Steam)**, Windows e Mac, teclado e mouse ou controle; o jogo custa
   até R$ 20; sem anúncios e sem compras dentro do jogo; **nada vai pela
   internet** (decisão de 11/11/2026). A demo da Steam será da versão escolhida.
4. O código continua sendo escrito em sessões do Claude Code, medido com o
   bot (`--autoplay`, `--botlog`) e com capturas. Modelos e texturas
   continuam feitos por código, com os modelos de IA opcionais.
5. **A versão original não pode quebrar enquanto as duas estiverem no menu.**
6. Se a versão incremental perder, as peças dela (a mata, os ninhos em
   árvores e troncos, o cupinzeiro por dentro) podem ir para as áreas 2 a 4
   da ideia original. Nada se perde.

---

## 4. Objetivo, hipótese e ponto de decisão

**Hipótese:** comer em escala de incremental (de 1 inseto por clique a umas
8 000 por minuto, e de 0 a 1 milhão), em 1ª pessoa, numa área gigante que se
abre pela força e não por portas, prende uma pessoa por 4 a 6 horas sem
automação, e o Caio gosta mais dela do que das 4 áreas.

Como medir, sem nada pela internet: testes com amigos (vendo de perto, em
silêncio, como pede o [`PLANO.md`](PLANO.md)) e o bot.

| Medida | Meta | Sinal de refazer | De onde vem a meta |
|---|---|---|---|
| Primeira compra | antes de 1 min | depois de 2 min | [`pesquisa-habilidades.md`](pesquisa-habilidades.md), seção 3 |
| Tempo entre compras | 40–60 s em média na 1ª hora; até 2 min depois | 3 min sem nada para comprar nem para abrir | seção 11 da pesquisa (área 1); o resto é estimativa |
| Gesto novo | a cada 20–30 min | 45 min sem gesto novo | estimativa (seção 7.4) |
| Fatia jogável (B2) | 2 de 3 pessoas querem continuar depois de 30 min | 2 de 3 param antes de 20 min | o teste do `PLANO.md` |
| Jogo inteiro | mediana de 4–6 h até o fim | menos de 3 h ou mais de 8 h | decisão do Caio |
| Travas | nenhum jogo do bot fica sem poder abrir o próximo ninho | qualquer trava | a trava dos 9 601 insetos da área 1 (11/11/2026) |

**O ponto de decisão é a fatia jogável (B2).** O Caio joga a fatia e a
demo da área 1 e escolhe:

- **Segue a versão incremental**: a área 1 e as áreas 2 a 4 saem do plano,
  e as etapas B3 em diante continuam.
- **Volta para a ideia original**: a versão incremental sai do menu, e as
  peças dela vão para as áreas 2 a 4.
- **Ainda não dá para saber**: refaz o que não funcionou e testa de novo. Se
  falhar duas vezes, vale a ideia original.

---

## 5. O que fica de fora (de propósito)

As sessões que forem construir **não** devem fazer:

- automação de qualquer tipo: ajudantes, bichos que comem sozinhos,
  progresso com o jogo fechado;
- renascimento ou prestígio: a versão tem fim;
- mais de uma área, passagens fechadas por tronco, telas de carregamento;
- escalada de árvore (fica o Empinar);
- multijogador (o SHRED A BILLION tem; aqui não);
- anúncios, loja, moeda paga e estatísticas pela internet;
- dia e noite: continua o mesmo fim de tarde. Dentro da mata e do cupinzeiro
  a luz muda; o céu não;
- mudanças na versão original além das necessárias para dividir o código
  (seção 9.1);
- manter as duas versões depois da decisão.

---

## 6. O que os jogos de referência ensinam

Números de novembro de 2026; preços e análises mudam.

| Jogo | O que é | O que levar | O que não levar |
|---|---|---|---|
| **SHRED A BILLION** (ImSoTiredStudio, 24/11/2026, US$ 6,99, 97% de 1 484 análises) | Pegar notas com a mão, depois com um balde, depois com um aspirador que faz um redemoinho, e jogar no triturador. Mais de 100 melhorias, árvore de habilidades, relíquias e notas douradas; números até trilhões; um cofre de 5 níveis para baixo, com buracos para cavar; no fim, uma chave dourada abre uma porta enorme (Steam, nov 2026; Game*Spark, nov 2026) | A meta gigante e finita; as ferramentas que trocam o gesto; os andares; o fim escondido; as relíquias (colecionáveis com bônus) | Os drones (até 16: é a automação dele) e o jogo em grupo |
| **Punch The Walls** (BoomGames, 06/11/2026, US$ 2,99, 89% de 727) | Socar paredes de concreto, que viram cubos; aspirar e triturar por dinheiro. Socos mais fortes, mais largos e mais rápidos, aspirador maior, explosivos; 8 tipos de rocha, cada um mais duro; ouro, relógios e coroas dentro das paredes. Fugir é o fim; depois, uma marreta que melhora sem limite e a conquista de demolir tudo (Steam e iXBT, nov 2026) | **A dureza do material como trava** (é a "trava por força"); "de poucos por golpe a centenas de uma vez"; tesouros dentro das paredes; um pós-jogo com melhoria sem teto e a conquista de limpar tudo. É o mais parecido com a escolha de não ter automação | O mapa sorteado a cada jogo |
| **Find The Needle** (Needless Games, 06/11/2026, 849 de 1 023 análises positivas, mediana de 11 h) | Achar uma agulha num palheiro de uns 6 milhões de fios, cavando à mão, e depois com esteiras e máquinas (Wasdland e iXBT, nov 2026; as fontes divergem sobre ser acesso antecipado) | A busca num volume enorme (o papel do Faro); a prova de que as pessoas ficam muitas horas num gesto simples | A fábrica |
| **Potato Please** (Golden Horn Studios, 03/11/2026, 91% de 4 260) | Descascar batata à mão, fino, para não desperdiçar; depois ferramentas e máquinas (games.gg, nov 2026) | O capricho no gesto manual: o prazer está em fazer bem feito | As máquinas |
| **We March as One** (dux, 13/11/2026, sem análises ainda) | Auto-batalha incremental em que cada soldado de um exército enorme é simulado (Deku Deals, nov 2026) | Ver uma massa enorme se mexendo, cada um sozinho (as salas cheias de cupins) | A batalha automática |
| **Dungeonbound** (louidev) | Pela ficha de uma loja, um incremental de masmorra em 1ª pessoa, com 5 ambientes diferentes. A página não abriu: **não verificado** | Se se confirmar: cada andar com cara própria | O combate |

O padrão dos quatro primeiros: **um gesto à mão, em 1ª pessoa, que passa de
1 por vez a centenas de uma vez; ferramentas que mudam o gesto; preço
baixo.** Os três primeiros também têm um espaço finito para esvaziar e um fim
escondido (a porta do cofre, a fuga, a agulha). O SHRED, o Find The Needle e
o Potato Please têm automação (drones, esteiras, máquinas); a versão
incremental troca isso por gestos maiores, como o Punch The Walls.

---

## 7. O ciclo, com regras e números

### 7.1 A meta

- **1 milhão de insetos.**
- **O fim** chega ao comer a rainha-mãe, que só fica exposta quando o
  cupinzeiro está 100% limpo (como a rainha da área 1, que só sai depois da
  corte).
- **O campo e a mata não precisam acabar** para o fim. Limpar a área inteira
  vira a conquista do pós-jogo (como a demolição total do Punch The Walls).
- **A conta é a de hoje**: cada inseto comido conta 1, e 10 insetos valem 1
  ponto (uns 100 mil pontos ao todo). Na tela, os números grandes ficam
  curtos: 12,3 mil · 450 mil · 1 mi.

### 7.2 As três zonas (estimativas)

| Zona | Como é | Insetos | Tempo de uma pessoa | Gestos que estreiam |
|---|---|---|---|---|
| **1. Cerrado aberto** (o começo) | Como a área 1: capim, formigueiros de saúva, trilhas, arbustos, a lagoa; o tamanduá acorda numa caverna e vê o cupinzeiro por cima da mata | ~15 mil (a área 1 tem 10 mil) | 0:00 – 0:30 | Lamber, Lambida Rápida, Bocado, Cavar, Olheiro |
| **2. Mata de galeria** (a maior) | Mata fechada e escura ao longo de um córrego, com umas 1 000 árvores: a maioria sem nada, umas 20 a 30 cheias de insetos; troncos caídos | ~230 mil | 0:30 – 2:15 | Empinar, Sacudir, Rasgar |
| **3. Campo de murundus e o cupinzeiro gigante** | Campo com montinhos de cupim em volta do cupinzeiro; 10 andares por dentro | ~750 mil | 2:15 – 5:00 | Varrer, Terremoto, Fungada |

"Mata de galeria" e "campo de murundus" são paisagens de verdade do cerrado:
a mata fechada que acompanha os córregos e o campo pontilhado de montes de
terra. Dão um motivo para a mata ser densa e para haver cupinzeiros em volta
do gigante.

A conta por trás (estimativa): o que o tamanduá come por minuto sobe de umas
200 no começo para umas 8 000 no fim. É o jeito dos incrementais: a última
parte tem a maioria dos números.

### 7.3 Na tela, cada inseto é um só

- **Na tela e perto, cada inseto anda sozinho**, como hoje: nas trilhas, em
  volta das câmaras, subindo os troncos, caindo da árvore sacudida, enchendo
  as salas do cupinzeiro.
- **Fora da tela ou longe, vira número ou desenho simples.** É o que o jogo
  já faz: as moradoras das câmaras fechadas só existem como um número até a
  câmara abrir, e as formigas de campo de longe usam malhas de 30 e 12
  triângulos. O trabalho novo é fazer isso valer para a área inteira e para os
  cupins.
- **Sala cheia**: uma sala mostra no máximo uns 2 a 3 mil cupins de cada vez
  (a medir). Os outros saem dos buracos das paredes conforme você come, como
  o túnel das câmaras de hoje (até 40 à vista; o resto sai conforme você come).
- **O ninho de papelão** que cai da árvore racha no chão e vira uma câmara
  aberta: os insetos saem dele aos poucos.

### 7.4 A escada dos gestos (o que faz o papel da automação)

| # | Gesto | O que muda | Quando (estimativa) |
|---|---|---|---|
| 1 | Lamber | 1 inseto por clique | 0:00 |
| 2 | Lambida Rápida | segurar o botão | ~0:01 |
| 3 | Bocado | vários por lambida (2 → umas 100) | ~0:03 |
| 4 | Cavar | abre as câmaras (e, depois, as salas) | ~0:08 |
| 5 | Olheiro | a língua entra no buraco e puxa os escondidos (formigueiro, oco de árvore) | ~0:15 |
| 6 | Empinar | em pé nas patas de trás: lambe até 1,5 → 2,0 → 2,5 m | ~0:35 |
| 7 | Sacudir | as garras batem no tronco: as formigas caem como chuva, e os ninhos de papelão despencam | ~0:50 |
| 8 | Rasgar | abre os troncos caídos em pedaços (cada pedaço é uma câmara) | ~1:05 |
| 9 | Varrer | segurando, a língua arrasta pelo chão da sala e pega todos os insetos da faixa | ~2:15 |
| 10 | Terremoto | o pulo que puxa tudo em volta (o Tremor de hoje, maior) | ~3:00 |
| 11 | Fungada | o focinho puxa um cone de insetos de uma vez (o "aspirador" do SHRED e do Punch) | ~3:45 |

O tamanduá-bandeira de verdade empina nas patas de trás, apoiado na cauda, e
rasga cupinzeiros e madeira podre com as garras. A Fungada é a licença do
desenho (pergunta 5 da seção 16).

### 7.5 Trava por força: a dureza

A área inteira está aberta desde o começo. O que segura é a **dureza** do que
fecha cada ninho, como as 8 rochas do Punch The Walls. Com Força abaixo da
dureza, a dica embaixo da mira mostra o cadeado e o nível que falta (como
hoje).

| Dureza | O que é | Onde | Abre com |
|---|---|---|---|
| 1 | terra fofa | câmaras pequenas dos formigueiros | Cavar |
| 2 | terra batida | câmaras grandes | Força 2 |
| 3 | madeira podre | troncos caídos | Rasgar (Força 3) |
| 4 | papelão de formiga ou de cupim | ninhos dos galhos, depois de derrubados | Força 4 |
| 5 a 14 | barro de cupinzeiro, cada andar mais duro | murundus (5) e as salas e os tampões das rampas dos andares 1 a 10 (5 a 14) | Força 5 a 14 |

Mais duas travas, pela altura e pela grossura:

- **Altura** (Empinar 1 a 3): buracos e ninhos até 1,5 m, 2 m e 2,5 m.
- **Grossura do tronco** (Sacudir 1 a 4): árvore fina, média, grossa e gigante.

**Rede de segurança:** se o jogador comeu tudo o que alcança e não tem pontos
para a próxima trava, a chave dela vem de presente (como a Cavar fundo nível 2
no marco Rainha). O simulador (seção 10) existe para isso quase nunca
acontecer, e redistribuir os pontos continua de graça, o que já evita boa
parte das travas.

### 7.6 A economia (o modelo que o simulador vai acertar)

- **Preço de cada nível**: o preço-base × 1,15 elevado ao nível, o modelo
  clássico de Anthony Pecorella (seção 3 da pesquisa).
- **Efeito**: sobe um pouco por nível e **dobra a cada 10 níveis**, com um
  cartão na tela ("Bocado nível 30 · o dobro"). O preço cresce umas 4 vezes a
  cada 10 níveis e o efeito umas 2; a diferença vem dos ninhos mais cheios de
  cada zona e de cada andar.
- **Níveis sem teto** nas linhas de quantidade (Bocado, Destreza, Força,
  Varrer, Fungada). Os pontos acabam junto com os insetos, então na prática o
  teto é o fim do jogo. As linhas de gesto (Empinar, Sacudir) têm poucos níveis.
- **Cada andar** guarda umas 1,25 vez os insetos do anterior (estimativa):
  andar 1 com ~20 mil, andar 10 com ~150 mil.
- **Bônus de ninho limpo**, como os 20 pontos de hoje, proporcional ao ninho.
- **Frenesi** (tanajuras e cogumelos) continua, e na versão incremental
  multiplica. Uma ideia a mais: de vez em quando saem **aleluias** (cupins
  com asas) pelas janelas do cupinzeiro, e comê-las dá Frenesi.

### 7.7 Os ninhos

Espécies sugeridas com base na vida real; dá para trocar (pergunta 3).

| Ninho | Zona | Quantos | Insetos em cada (estimativa) | Como se come | Peças de hoje que servem |
|---|---|---|---|---|---|
| Formigueiro de saúva | 1 | ~8 | 1 mil a 4 mil | trilhas, passeio e câmaras, como na área 1 | `nest.gd`, `colony.gd`, `ant_field.gd` |
| Tronco caído (formiga-carpinteira) | 2 | ~15 | 2 mil a 6 mil | Rasgar abre o tronco em pedaços; serragem no chão denuncia o ninho | câmaras, a terra ao cavar (`dirt_fx.gd`), as lascas do tronco da saída |
| Árvore oca (formiga de embaúba) | 2 | ~15 | 3 mil a 8 mil | uma fila sobe o tronco; Olheiro nos buracos (Empinar para os altos); Sacudir derruba as de fora | a subida no tronco (`ant_ground.gd`), o Olheiro |
| Ninho de papelão no galho (formiga ou cupim de árvore) | 2 | ~10 | 5 mil a 10 mil | Sacudir derruba; no chão ele racha e vira uma câmara aberta | a câmara aberta |
| Correição (formiga-de-correição) | 2 | de vez em quando | 3 mil a 6 mil por passagem | um rio de formigas atravessa a mata; é correr atrás | as trilhas (`trail_network.gd`) |
| Murundu (cupinzeiro pequeno) | 3 | ~8 | 4 mil a 8 mil | Cavar abre; os cupins saem das galerias | `nest.gd` |
| Sala do cupinzeiro gigante | 3 | ~55 | de uns 2 mil (andar 1) a uns 150 mil (a sala da rainha-mãe) | entrar e comer à vontade; os cupins enchem o chão e as paredes e saem dos buracos | a câmara aberta |
| Rainha-mãe | 3 | 1 | a definir | a última; é o fim | a rainha da área 1 |

### 7.8 O cupinzeiro gigante

- **Tamanho** (estimativa): uns 50 m de largura na base e 60 m de altura,
  com 10 andares de uns 6 m. Os olhos do tamanduá ficam a 72 cm do chão:
  cada andar parece enorme.
- **Por dentro**: uma chaminé no meio (como a que alguns cupins de verdade
  fazem, para ventilar), uma rampa em espiral rente à parede de fora e um
  anel de salas em volta da chaminé. O andar 1 tem umas 10 salas; o andar 10,
  só a da rainha-mãe; umas 55 salas ao todo (estimativa).
- **Travas**: cada sala fechada por uma parede de barro da dureza do andar; a
  rampa para o andar seguinte, por um tampão de barro da dureza dele (cupins
  fecham passagens de verdade). Dá para entrar no cupinzeiro desde o começo e
  ver o primeiro andar; subir depende da força.
- **Janelas e varandas** na parede de fora, para ver a mata e o campo lá
  embaixo: ajudam a não se perder e a sentir a altura.
- **Descer rápido**: pular na chaminé e escorregar até o chão, sem dano, como
  em todo o jogo.
- **Luz**: a do fim de tarde entra pelas janelas. Mais para dentro, larvas de
  um besouro que brilha (parente dos vaga-lumes) acendem pontos verdes nas
  paredes. Isso existe no cerrado: no Parque Nacional das Emas, larvas do
  besouro *Pyrearinus termitilluminans* vivem em cupinzeiros e acendem luzes
  verdes para atrair presas (FAPESP, jan 2024). Por fora, o cupinzeiro também
  pode pontilhar de verde visto de longe.
- **Um tema por andar**, para não repetir: galerias de terra; depósito de
  capim (cupins guardam capim seco); berçário (ovos e ninfas); andar dos
  soldados; chaminés; andar das larvas que brilham; câmara dos alados
  (prontos para a revoada); varandas ao vento; antecâmara; a sala da
  rainha-mãe.
- **O fim**: a rainha-mãe no topo. Ao comer a última, a câmera olha o
  cerrado lá de cima, no fim de tarde, e aparecem as estatísticas. Na
  natureza a câmara real fica no meio do monte, e não no topo; aqui é
  licença do jogo, pela vista.
- **Por fora**, ele continua lendo como cupinzeiro de longe (as caneluras de
  chuva, a ponta fina e as torres menores do `giant_mound.gd` de hoje, que é
  só cenário e não serve para andar).

### 7.9 A mata densa e escura

- **Densidade** (estimativa): umas 1 000 árvores na mata e uns 40 troncos
  caídos. Só umas 20 a 30 árvores e uns 15 troncos têm insetos; o resto é só
  cenário.
- **Como reconhecer uma árvore-ninho**: uma fila de formigas subindo o
  tronco, serragem no pé, buracos com terra fresca, bolas escuras de papelão
  nos galhos.
- **Escuridão**: as copas fecham por cima, e a luz baixa do fim de tarde entra
  em raios. O chão é de folhas secas (a textura `folhico` já existe), com
  vaga-lumes (já existem) e as larvas que brilham. O Faro ganha importância:
  a mata escura é onde ele mais ajuda.
- **Leitura**: as formigas precisam continuar visíveis no escuro (o contorno
  que a mira já usa, o Faro, os raios de luz). Testar nos presets Baixa e Média.

### 7.10 Controles e sensação

- **Comandos novos** (todos trocáveis em Configurações → Controles):
  Empinar = segurar `C` (controle: `LB`); Fungada = `R` (controle: `RB`).
  Sacudir e Rasgar usam o mesmo `E` do Cavar, mirando no tronco. Varrer é
  automático: segurar a lambida e arrastar a mira pelo chão.
- **Mão cansada**: horas segurando o botão cansam. A Lambida Rápida ganha a
  opção "apertar uma vez", como Correr e Cavar já têm.
- **O que precisa ser gostoso** (a lista de capricho):
  - o "+120" subindo do medalhão (hoje já sobe o "+1" e o "+20");
  - a sala cheia de cupins esvaziando enquanto a língua varre;
  - a chuva de formigas ao sacudir, com o barulhinho delas caindo nas folhas;
  - o tronco abrindo em lascas e o ninho de papelão despencando e rachando;
  - os insetos voando para dentro do focinho na Fungada;
  - o cartão a cada 10 níveis ("o dobro");
  - as salas do andar acendendo em verde no mapa quando ficam limpas;
  - o som de mastigar subindo de tom com o combo;
  - a vista do topo, no fim.

---

## 8. Habilidades da versão incremental (rascunho)

A mesma árvore Constelação, com 5 ramos. Nas linhas de muitos níveis, um
número ("Nv 37") no lugar das bolinhas. Clique compra 1 nível, Shift compra
10 e Ctrl compra o máximo (ou os botões ×1, ×10 e Máx na caixa da
habilidade), que continua mostrando antes → depois.

| Ramo | Linha | Níveis | O que faz |
|---|---|---|---|
| **Língua** | Lambida Rápida | 1 | segurar para lamber |
| | Bocado | sem teto | insetos por lambida e o raio da ponta |
| | Destreza | ~30 | lambidas por segundo |
| | Comprimento | ~12 | alcance, de 1 m a 5 m |
| | Mira | ~5 | a área da mira |
| | Olheiro | sem teto | quantos a língua puxa do buraco, e a recarga |
| | Varrer | sem teto | largura e velocidade da faixa |
| **Garras** | Cavar e Força | 14 durezas | o que dá para abrir (seção 7.5) |
| | Rapidez | ~20 | o descanso das garras e o tempo de cavar |
| | Sacudir | 4 | a grossura do tronco |
| | Tremor e Terremoto | ~10 | atordoa e puxa as tontas |
| **Patas** | Corrida, Respiro, Passada, Fôlego | ~10 cada | como hoje, com mais níveis (a área é 5 vezes mais larga) |
| | Empinar | 3 | 1,5 → 2,0 → 2,5 m |
| **Faro** | Rastro e Família | ~6 cada | achar ninhos, salas e o que falta |
| | Faro no escuro | ~3 | ver os insetos na mata escura e no fundo das salas |
| **Focinho** (no lugar da Escalada) | Fungada | sem teto | o cone que puxa |

---

## 9. Sistemas, na ordem de construção

### 9.1 Fazer a versão nova sem quebrar a original (o primeiro e o mais arriscado)

Como fica **uma ou outra**, não vale a pena deixar tudo geral para sempre.
Durante o teste:

- **O código novo fica em arquivos novos**: `scripts/world/incremental/` (o
  mundo, os ninhos novos, o cupinzeiro) e `scripts/modes/incremental.gd` (a
  economia).
- **Os arquivos de hoje só ganham parâmetros**, com os valores de hoje como
  padrão, para a versão original continuar igual.
- **Depois da decisão**, a versão que perdeu sai do código.

O que hoje supõe a área 1:

| Onde | O que é fixo hoje | O que muda |
|---|---|---|
| `scripts/autoload/game_state.gd` | `GOAL` (10 000), `BRANCHES`, `MARCOS`, `UPGRADES` e as contas das habilidades (`lick_capacity()`, `tongue_range()`, `lick_rate()`...), feitas por cliques | Os dados de cada versão em arquivos próprios (`scripts/modes/normal.gd` e `scripts/modes/incremental.gd`); na incremental, as contas por nível |
| `scripts/main.gd` | Sempre monta o `World` da área 1 | Monta o mundo da versão escolhida no menu |
| `scripts/world/terrain.gd` | `SIZE` 160 m, `RES` 256 (um ponto a cada 62 cm), `MASK_RES` 512 | Uns 300 m (a área de 250 m mais o platô em volta), mesma densidade de pontos (`RES` ~480) |
| `scripts/ants/ant_ground.gd` | `SIZE` 64 m (pedras, troncos e árvores onde as formigas sobem) | Uns 260 m |
| `scripts/ants/ant_field.gd` | `HEIGHT_SIZE` 160 m (o chão das formigas de campo na placa de vídeo) | Uns 300 m |
| `scripts/world/cliffs.gd` | `BASE_RADIUS` 26 m: um círculo em volta da clareira | O contorno da área gigante |
| `scripts/world/world.gd` | `NEST_LAYOUT`, `FOOD_LAYOUT`, `LINKS` da área 1 | A planta em dados (seção 10) |
| `scripts/ants/ant_swarm.gd` | `CAPACITY` 4 096 formigas simuladas uma a uma | Continua; o resto fica no campo calculado pela placa de vídeo, ou como número |
| Jogos salvos (`game_state.gd`, `SAVE_VERSION` 9) | 3 jogos da versão original | Mais 3 só da incremental (`user://incremental_N.json`), com versão própria; a coleção (`user://save.cfg`) ganha a área nova |

**Teste de que a versão original não mudou:** o bot com a mesma semente
antes e depois (`--autoplay --botlog`), comparando os CSVs (no máximo 5% de
diferença no tempo de cada marco), e capturas do menu, do mapa e da árvore.

### 9.2 A ordem

1. **A divisão do código** (9.1).
2. **Menu e jogos salvos**: o botão novo no `scripts/ui/menus.gd` e a tela
   de jogos salvos da versão incremental.
3. **Números grandes**: a forma curta (mil, mi) num lugar só
   (`scripts/ui/ui_theme.gd` ou um `scripts/ui/numeros.gd`), usada no
   medalhão, nos cartões, no mapa e na árvore.
4. **Economia por níveis e a árvore com níveis** (`scripts/ui/skill_tree.gd`):
   ×1, ×10 e Máx, "Nv 37", o cartão a cada 10 níveis.
5. **O mundo da área gigante** (`scripts/world/incremental/`): terreno de uns
   250 m com o platô, penhascos em volta, a caverna, as três zonas e a
   passagem de luz entre elas.
6. **Os formigueiros do começo**: `nest.gd` com números maiores.
7. **Insetos fora da tela e de longe**: fazer valer para a área inteira e
   para os cupins o que o jogo já faz com as moradoras das câmaras fechadas
   (um número até precisar aparecer) e com as formigas de campo de longe (as
   malhas simples). Malhas próprias para os cupins, mais simples que as das
   formigas (sem folha, corpo claro). O teto de insetos à vista por sala, com
   o resto saindo dos buracos das paredes.
8. **A mata**: árvores feitas com 12 a 20 modelos repetidos (em vez de uma
   malha para cada árvore), versões simples de longe, sombra só perto, uma
   imagem da copa que escurece o chão, o capim e as formigas embaixo dela
   (mais barato que sombra de verdade de centenas de árvores) e os raios de luz.
9. **Árvores-ninho e troncos caídos**: um tipo novo de trilha em
   `ant_field.gd`, que sobe o tronco; Olheiro nos buracos; Empinar; Sacudir
   (as formigas caem uma a uma e correm pelo chão); Rasgar (o tronco em
   pedaços); o ninho de papelão que cai, racha e vira uma câmara aberta.
10. **O cupinzeiro por dentro**: andares, rampa, salas, chaminé, janelas,
    colisão, a luz das larvas, e só o andar onde você está (mais o de cima e
    o de baixo) desenhado por dentro.
11. **Objetivos e mapa da versão incremental**: a sequência guiada dos
    primeiros 30 minutos (como a da área 1) e um objetivo por zona e por
    andar (`scripts/ui/objectives.gd`); no mapa (`scripts/ui/map_view.gd`),
    uma vista por andar do cupinzeiro.
12. **Colecionáveis da área nova, conquistas e estatísticas.**
13. **O bot da versão incremental e o balanceamento.**
14. **Desempenho e polimento.**

### 9.3 Desempenho

- **Meta**: pelo menos 60 quadros por segundo no preset Média nos três
  lugares mais pesados (o meio da mata; a beira do cupinzeiro, olhando a
  mata; uma sala cheia de cupins), medido com F3 e `--stats`. Para comparar:
  a área 1 roda hoje entre uns 130 e 180 na máquina de teste (RTX 5070,
  3440×1440), segundo o histórico do `DESIGN.md`.
- **Árvores**: no máximo uns 20 modelos diferentes; o resto repetido.
- **Insetos à vista**: no máximo as 4 096 formigas simuladas de hoje, mais as
  formigas de campo calculadas pela placa de vídeo (medir quantas cabem; a
  área 1 tem uns 5 500 andando) e o teto de cada sala; o resto, como número.
- **Cupinzeiro**: o que está em outros andares não é desenhado por dentro.
- **Tempo para abrir o jogo**: o mundo é montado por código na hora de
  carregar, e a área nova é 5 vezes mais larga. Medir na B1; se passar de uns
  15 s na máquina de teste, guardar partes já prontas.

---

## 10. Ferramentas primeiro (antes do conteúdo)

1. **Simulador da economia** (`tools/sim_incremental.py`, em Python como os
   outros de `tools/`): lê os mesmos dados que o jogo (`data/incremental.json`:
   insetos de cada ninho, durezas, preços, efeitos) e simula um jogador que
   compra o nível que mais rende por ponto e come o ninho que mais rende por
   segundo. Diz o tempo até o fim, o tempo entre as compras, quando chega cada
   gesto e se alguma trava ficou impossível. Roda em segundos: dá para testar
   dezenas de curvas numa tarde.
2. **Validador das travas** (no mesmo script): para cada dureza, prova que
   os insetos abaixo dela dão os pontos para comprá-la, com folga (1,3 vez),
   mesmo comprando mal. Se falhar, aponta onde e sai com erro.
3. **A planta em dados** (`data/incremental_mapa.json`: zonas, ninhos,
   árvores-ninho, troncos, andares, salas, rampas), lida pelo gerador do
   mundo e pelo simulador (as distâncias entram no tempo: a área é grande).
4. **O bot na versão incremental** (`--autoplay` e `--botlog`), para conferir
   o simulador no jogo de verdade. Na área 1, o bot é umas 3 vezes mais lento
   que uma pessoa; a mesma régua vale aqui até ser medida de novo.

Para o jogo exportado ler os `.json`, o `data/*.json` entra no
`include_filter` do `export_presets.cfg` (hoje ele só tem o
`assets/models/ajustes.cfg`).

**O bot anota** (para o balanceamento; tudo fica no computador): cada compra
(habilidade, nível, preço, minuto), cada ninho e cada sala limpos, cada
presente da rede de segurança, cada andar aberto, o fim, e uma linha a cada
30 s com insetos, pontos, zona e andar.

---

## 11. Restrições técnicas

- Godot **4.7.2**, Forward+, GDScript; nenhum complemento novo.
- Tudo feito por código, como hoje (malhas, sons e texturas); modelos de IA
  continuam opcionais.
- Os jogos salvos da versão original (versão 9) continuam abrindo enquanto
  ela estiver no jogo.
- Nada pela internet.
- O desempenho da seção 9.3.

---

## 12. O que não se aplica aqui

O modelo de brief do plugin Game Trend Skills pede pontos de anúncio e
eventos enviados para um serviço de análise. Não valem para este jogo: ele é
vendido na Steam por até R$ 20, sem anúncios, e desde 11/11/2026 não manda
nada pela internet. No lugar deles ficam o registro local do bot (seção 10) e
as estatísticas que o jogo já mostra.

---

## 13. Etapas, com o que conferir

| Etapa | O que entra | Pronto quando (dá para conferir) | Tamanho |
|---|---|---|---|
| **B0. Papel e simulador** | A seção 10, a planta da área e a do cupinzeiro, e as perguntas da seção 16 respondidas | O simulador dá 4 a 6 h sem trava; o Caio aprova as duas plantas | P |
| **B1. Fundação** | A seção 9.1, o menu, os jogos salvos, os números grandes e a economia por níveis | "Banquete" no menu abre uma área vazia de uns 250 m, com penhascos e caverna; a versão original fica igual (bot e capturas); os jogos salvos das duas não se misturam; o tempo para abrir está medido | M |
| **B2. Fatia jogável (a decisão)** | Um campo pequeno com 3 formigueiros, 1 tronco caído, 1 árvore-ninho (Empinar e Sacudir), 1 andar do cupinzeiro com 3 salas cheias, e a árvore com níveis | 30 minutos jogáveis, do começo até limpar o 1º andar; o teste com 3 pessoas da seção 4; **o Caio escolhe a versão** | G |
| **B3. Cerrado aberto** | A zona 1 inteira (e, se a incremental ganhou, a área 1 sai do menu) | O bot limpa a zona no equivalente a uns 30 min de uma pessoa | M |
| **B4. Mata de galeria** | A zona 2 inteira: escuridão, árvores-ninho, troncos, ninhos de papelão, correição | Pelo menos 60 quadros por segundo no Média no meio da mata; o bot chega ao cupinzeiro no equivalente a umas 2h15 de uma pessoa | G |
| **B5. O cupinzeiro** | Os 10 andares, salas, rampas, chaminé, larvas, a rainha-mãe e o fim | Dá para subir do chão ao topo e terminar; nenhuma sala sem saída; nenhum lugar onde a câmera atravessa a parede | G |
| **B6. Economia fechada** | Balanceamento com o simulador e o bot, colecionáveis, conquistas, objetivos, o mapa por andar | O bot termina na faixa de 4 a 6 h de uma pessoa, sem trava, com 3 sementes diferentes | M |
| **B7. Polimento e versão de teste** | Textos, sons, desempenho e a versão para os amigos (a automação do GitHub que já existe) | 3 pessoas jogam pelo menos 2 h, e anotamos onde pararam de sorrir | M |

P = alguns dias de sessões; M = 1 a 2 semanas; G = 3 semanas ou mais
(estimativa, pelo ritmo do repositório em novembro).

---

## 14. Como conferir cada etapa

- **B0**: `python3 tools/sim_incremental.py` mostra a tabela do ritmo e sai
  com erro se alguma trava falhar.
- **B1 a B7**: a sessão baixa o Godot 4.7.2 (do mesmo jeito que o
  `.github/workflows/versao.yml`) e roda o bot e as capturas. A opção para
  começar direto na versão incremental (`--start=incremental`) é criada na
  B1, junto com as de hoje (`--autoplay`, `--timescale`, `--botlog`,
  `--captures`, `--quit`).
- **A versão original**: a mesma linha do bot de hoje, comparada com os
  `docs/dados/bot-marcos-*.csv`.
- **Desempenho**: `--stats` e F3 nos três lugares da seção 9.3, numa máquina
  com placa de vídeo (as capturas do servidor sem placa de vídeo não servem
  para medir quadros por segundo).
- **Os registros** do bot vão para `docs/dados/bot-incremental-*.csv`, como
  os da área 1.

---

## 15. Riscos (do maior para o menor)

1. **Conteúdo demais.** 4 a 6 horas são de 12 a 18 vezes a área 1, numa
   área 5 vezes mais larga. Saída: ferramentas e dados primeiro, peças
   repetidas com variação (como as câmaras), e a fatia jogável antes do resto.
2. **Quebrar a versão original durante o teste.** Saída: código novo em
   arquivos novos, parâmetros com os valores de hoje como padrão, e o bot e
   as capturas antes de cada junção.
3. **Travar no fim.** Numa versão finita e sem automação, se faltar ponto o
   jogo para. Saída: o validador, redistribuir de graça e a rede de segurança.
4. **Insetos demais na tela** (salas cheias, a chuva de formigas, a
   correição). Saída: o teto por sala, com o resto saindo dos buracos;
   malhas simples para os cupins; medir já na B2.
5. **O número subir pouco.** Com 1 milhão, o fim fica em umas 100 por
   lambida, 2 a 3 vezes o fim da área 1 (estimativa). Saída: o simulador
   mostra na B0; se faltar, sobe a meta (2 a 5 milhões, até onde o teto de
   insetos na tela aguenta) ou cresce mais a Varrer e a Fungada.
6. **Mão cansada.** Saída: a Lambida Rápida com "apertar uma vez"; Varrer e
   Fungada pegam mais com menos cliques.
7. **Mata escura demais** para ver as formigas. Saída: o contorno, o Faro no
   escuro, os raios de luz; testar nos presets Baixa e Média.
8. **O peso da mata e o tempo para abrir o jogo** (1 000 árvores, uma área 5
   vezes mais larga, tudo montado por código ao carregar). Saída: modelos
   repetidos, versões de longe, sombra só perto, a imagem da copa no lugar de
   sombras de verdade, e partes já prontas se o carregamento passar de 15 s.
9. **Dentro do cupinzeiro**: em 1ª pessoa, em lugar fechado, a câmera pode
   atravessar a parede, e dá para se perder. Saída: salas largas, janelas, o
   mapa por andar e o losango do objetivo.
10. **Duas versões até a decisão.** Saída: decidir na B2, e não depois da
    B6, para não balancear as duas por muito tempo.

---

## 16. Perguntas em aberto (e o que vale se ninguém responder)

| # | Pergunta | Vale, se ninguém responder |
|---|---|---|
| 1 | O começo é a própria clareira da área 1 (os 8 formigueiros, a lagoa e a caverna), aberta para a mata? | Sim: aproveita o que já foi feito e afinado; muda só o paredão do lado da mata e os números |
| 2 | O nome no menu durante o teste | "Banquete" |
| 3 | As espécies: saúva, formiga-carpinteira, formiga de embaúba, ninho de papelão (formiga ou cupim de árvore), correição e cupim de murundu | Essas |
| 4 | Os colecionáveis da área nova dão bônus (como as relíquias do SHRED)? | Sim, de 3% a 5% cada |
| 5 | A Fungada (o "aspirador" do focinho) como último gesto? | Sim, a partir do andar 7 |
| 6 | A correição (o rio de formigas que atravessa a mata)? | Sim, mas só na B6 |
| 7 | O combo dá pontos? | Sim, pouco (até 20% a mais) |
| 8 | Dá para continuar depois do fim, para limpar a área inteira? | Sim, com a conquista de limpar tudo |
| 9 | Os amigos que testarem mandam um registro da partida (um arquivo que eles enviam se quiserem)? | Não: só o bot e as estatísticas de hoje, nada pela internet |

---

## 17. Fontes

- SHRED A BILLION: [página na Steam](https://store.steampowered.com/app/5472080/SHRED_A_BILLION/) (nov 2026); [Game*Spark](https://en.gamespark.jp/article/2026/11/26/2716.html) (nov 2026)
- Punch The Walls: [página na Steam](https://store.steampowered.com/app/5455340/) (nov 2026); [iXBT](https://ixbt.games/en/news/2026/11/15/v-steam-vysel-simuliator-pobega-iz-tiurmy-v-kotorom-geroi-golymi-rukami-probivaet-sebe-put-k-svobode.amp.html) (nov 2026)
- Find The Needle: [Wasdland](https://www.wasdland.com/game/find-the-needle-5160800/) (nov 2026); [iXBT](https://ixbt.games/en/news/2026/11/06/v-steam-vysel-simuliator-poiska-igolki-v-stoge-sena-on-obosel-original-po-vislistam.amp.html) (nov 2026)
- Potato Please: [games.gg](https://games.gg/potato-please/) (nov 2026)
- We March as One: [Deku Deals](https://www.dekudeals.com/items/we-march-as-one) (nov 2026)
- Dungeonbound: [GG.deals](https://gg.deals/game/dungeonbound/) (a página não abriu; só o resumo de uma busca, nov 2026)
- Larvas que brilham nos cupinzeiros: [Agência FAPESP](https://agencia.fapesp.br/diversity-of-bioluminescent-beetles-in-brazilian-savanna-has-declined-sharply-in-30-years/50536) (jan 2024); [Pyrearinus, Wikipedia](https://en.wikipedia.org/wiki/Pyrearinus)
- Preços que multiplicam e ganhos que somam: Anthony Pecorella, [The Math of Idle Games, parte I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i) (já citado na [pesquisa](pesquisa-habilidades.md))
