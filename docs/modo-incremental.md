# Modo incremental (nome provisório: Banquete): plano de desenvolvimento

Escrito em 27/11/2026, a partir do pedido do Caio e das 8 respostas dele no
mesmo dia. **Nada disto está feito ainda.** Sobre o modo normal (a demo da
área 1), vale o [`DESIGN.md`](DESIGN.md); sobre o Banquete, vale este arquivo.

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
- **O mapa precisa ser compacto: uns 140 × 180 m, não os ~580 m da área 3
  do esboço.** Quem dá as 4 a 6 horas é a altura do cupinzeiro (10 andares)
  e o tamanho dos números, não a distância a pé. O código todo supõe hoje um
  mundo de 160 m (seção 9.1); 580 m pediria um terreno carregado aos
  pedaços e dez vezes mais cenário para fazer.
- **Quase todos os insetos ficam no cupinzeiro** (estimativa: 99%). Para
  caber 1 bilhão sem travar o computador, as massas grandes (as salas do
  cupinzeiro, os ninhos de papelão que caem, as formigas sacudidas de uma
  árvore) viram um **tapete vivo**: a conta continua exata, cada inseto conta
  1, mas o desenho é de uma massa que baixa quando você come, não de insetos
  andando um a um. Isso mexe na decisão de 05/11/2026 ("cada formiga anda
  sozinha") e é a pergunta 3 da seção 16.
- **Sem automação, quem acelera é o gesto.** Como no Punch The Walls ("de
  poucos cubos por soco a centenas de uma vez"), cada habilidade grande troca
  o gesto: lamber 1, lamber vários, puxar do buraco, cavar, empinar, sacudir a
  árvore, rasgar o tronco, varrer o tapete com a língua (seção 7.4).
- **Primeiro a ferramenta e um pedaço que testa a ideia**: um simulador da
  economia que prova que dá para chegar ao fim sem travar, e uma fatia
  jogável de 30 minutos (campo pequeno, um tronco caído, uma árvore-ninho e
  um andar do cupinzeiro). Só depois a mata inteira e os 10 andares (seção 13).
- **Critério de parada:** se, na fatia jogável, 2 de 3 pessoas pararem antes
  de 20 minutos, ou disserem que as compras não mudam nada, o ciclo é refeito
  antes de fazer o resto do conteúdo. Se falhar duas vezes, o Banquete volta
  para o papel (seção 4).

---

## 2. O que o Caio decidiu (27/11/2026)

| Assunto | Decidido |
|---|---|
| Onde fica | Uma segunda opção no menu principal, ao lado do jogo normal |
| Mapa | Só a área 3: um começo com cara de área 1, uma mata densa e escura (a maior parte) e o cupinzeiro gigante |
| Fim | **Meta gigante com fim**: um número enorme e finito; acaba ao comer o último cupim do cupinzeiro |
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

1. **Mesmo jogo**: mesmo motor (Godot 4.7, Forward+), mesmo estilo (3D
   estilizado, 1ª pessoa, interface Constelação), mesmos controles. É uma
   opção a mais no menu, não outro jogo.
2. **PC (Steam)**, Windows e Mac, teclado e mouse ou controle; o jogo custa
   até R$ 20; sem anúncios e sem compras dentro do jogo; **nada vai pela
   internet** (decisão de 11/11/2026).
3. O código continua sendo escrito em sessões do Claude Code, medido com o
   bot (`--autoplay`, `--botlog`) e com capturas. Modelos e texturas
   continuam feitos por código, com os modelos de IA opcionais.
4. **O modo normal não pode quebrar**: tudo o que for dividido entre os dois
   modos é testado nos dois.
5. O conteúdo feito para o Banquete (a mata, os ninhos em árvores e troncos,
   o cupinzeiro) deve servir depois para as áreas 2 a 4 do modo normal
   (pergunta 1 da seção 16).

---

## 4. Objetivo, hipótese e critério de parada

**Hipótese:** comer em escala de incremental (de 1 inseto por lambida a
centenas de milhares por segundo), em 1ª pessoa, num mapa que se abre pela
força e não por portas, prende uma pessoa por 4 a 6 horas sem automação.

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

**Se a fatia jogável falhar duas vezes seguidas**, o Banquete volta para o
papel, e o esforço vai para a área 2 do modo normal, que usa as mesmas peças
(a mata, as árvores-ninho, os troncos).

---

## 5. O que fica de fora (de propósito)

As sessões que forem construir **não** devem fazer:

- automação de qualquer tipo: ajudantes, bichos que comem sozinhos,
  progresso com o jogo fechado;
- renascimento ou prestígio: o modo tem fim;
- as áreas 2 e 4 separadas, passagens fechadas por tronco, telas de
  carregamento;
- escalada de árvore (fica o Empinar);
- multijogador (o SHRED A BILLION tem; aqui não);
- anúncios, loja, moeda paga e estatísticas pela internet;
- dia e noite: continua o mesmo fim de tarde. Dentro da mata e do cupinzeiro
  a luz muda; o céu não;
- mudanças no modo normal além das necessárias para dividir o código (seção 9.1).

---

## 6. O que os jogos de referência ensinam

Números de novembro de 2026; preços e análises mudam.

| Jogo | O que é | O que levar | O que não levar |
|---|---|---|---|
| **SHRED A BILLION** (ImSoTiredStudio, 24/11/2026, US$ 6,99, 97% de 1 484 análises) | Pegar notas com a mão, depois com um balde, depois com um aspirador que faz um redemoinho, e jogar no triturador. Mais de 100 melhorias, árvore de habilidades, relíquias e notas douradas; números até trilhões; um cofre de 5 níveis para baixo, com buracos para cavar; no fim, uma chave dourada abre uma porta enorme (Steam, nov 2026; Game*Spark, nov 2026) | A meta gigante e finita; as ferramentas que trocam o gesto; os andares; o fim escondido; as relíquias (colecionáveis com bônus) | Os drones (até 16: é a automação dele) e o jogo em grupo |
| **Punch The Walls** (BoomGames, 06/11/2026, US$ 2,99, 89% de 727) | Socar paredes de concreto, que viram cubos; aspirar e triturar por dinheiro. Socos mais fortes, mais largos e mais rápidos, aspirador maior, explosivos; 8 tipos de rocha, cada um mais duro; ouro, relógios e coroas dentro das paredes. Fugir é o fim; depois, uma marreta que melhora sem limite e a conquista de demolir tudo (Steam e iXBT, nov 2026) | **A dureza do material como trava** (é a "trava por força"); "de poucos por golpe a centenas de uma vez"; tesouros dentro das paredes; um pós-jogo com melhoria sem teto e a conquista de limpar tudo. É o mais parecido com a escolha de não ter automação | O mapa sorteado a cada jogo |
| **Find The Needle** (Needless Games, 06/11/2026, 849 de 1 023 análises positivas, mediana de 11 h) | Achar uma agulha num palheiro de uns 6 milhões de fios, cavando à mão, e depois com esteiras e máquinas (Wasdland e iXBT, nov 2026; as fontes divergem sobre ser acesso antecipado) | A busca num volume enorme (o papel do Faro); a prova de que as pessoas ficam muitas horas num gesto simples | A fábrica |
| **Potato Please** (Golden Horn Studios, 03/11/2026, 91% de 4 260) | Descascar batata à mão, fino, para não desperdiçar; depois ferramentas e máquinas (games.gg, nov 2026) | O capricho no gesto manual: o prazer está em fazer bem feito | As máquinas |
| **We March as One** (dux, 13/11/2026, sem análises ainda) | Auto-batalha incremental em que cada soldado de um exército enorme é simulado (Deku Deals, nov 2026) | Ver uma massa enorme se mexendo (o tapete de cupins) | A batalha automática |
| **Dungeonbound** (louidev) | Pela ficha de uma loja, um incremental de masmorra em 1ª pessoa, com 5 ambientes diferentes. A página não abriu: **não verificado** | Se se confirmar: cada andar com cara própria | O combate |

O padrão dos quatro primeiros: **um gesto à mão, em 1ª pessoa, que passa de
1 por vez a centenas de uma vez; ferramentas que mudam o gesto; preço
baixo.** Os três primeiros também têm um espaço finito para esvaziar e um fim
escondido (a porta do cofre, a fuga, a agulha). O SHRED, o Find The Needle e
o Potato Please têm automação (drones, esteiras, máquinas); o Banquete troca
isso por gestos maiores, como o Punch The Walls.

---

## 7. O ciclo, com regras e números

### 7.1 A meta

- **1 bilhão de insetos** (estimativa de partida; o número é parecido com o
  do SHRED A BILLION, veja a pergunta 2).
- **O fim** chega ao comer a rainha-mãe, que só fica exposta quando o
  cupinzeiro está 100% limpo (como a rainha da área 1, que só sai depois da
  corte).
- **O campo e a mata não precisam acabar** para o fim. Limpar o mapa inteiro
  vira a conquista do pós-jogo (como a demolição total do Punch The Walls).
- **A conta é a de hoje**: cada inseto comido conta 1, e 10 insetos valem 1
  ponto. Na tela, os números grandes ficam curtos: 12,3 mil · 4,5 mi · 1,2 bi.

### 7.2 As três zonas (estimativas)

| Zona | Como é | Insetos | Tempo de uma pessoa | Gestos que estreiam |
|---|---|---|---|---|
| **1. Cerrado aberto** (o começo) | Como a área 1: capim, formigueiros de saúva, trilhas, arbustos; o tamanduá acorda numa caverna e vê o cupinzeiro por cima da mata | ~60 mil | 0:00 – 0:35 | Lamber, Lambida Rápida, Bocado, Cavar, Olheiro |
| **2. Mata de galeria** (a maior) | Mata fechada e escura ao longo de um córrego; muitas árvores sem nada, algumas cheias de insetos; troncos caídos | ~3 mi | 0:35 – 2:15 | Empinar, Sacudir, Rasgar |
| **3. Campo de murundus e o cupinzeiro gigante** | Campo com montinhos de cupim em volta do cupinzeiro; 10 andares por dentro | ~1 bi | 2:15 – 5:00 | Varrer, Terremoto, Fungada |

"Mata de galeria" e "campo de murundus" são paisagens de verdade do cerrado:
a mata fechada que acompanha os córregos e o campo pontilhado de montes de
terra. Dão um motivo para a mata ser densa e para haver cupinzeiros em volta
do gigante.

A conta por trás (estimativa): se o que o tamanduá come por segundo **dobra a
cada ~20 minutos** de jogo, ele come uns 60 mil na zona 1, uns 3 milhões na
mata e quase todo o bilhão no cupinzeiro. É o jeito dos incrementais: a última
parte tem a maioria dos números.

### 7.3 Insetos um a um e insetos em tapete

- **Até alguns milhares juntos, cada inseto anda sozinho**, como hoje: nas
  trilhas, em volta das câmaras, subindo os troncos, saindo das câmaras
  abertas.
- **Acima disso, a massa vira tapete**: as formigas que caem de uma árvore
  sacudida, o ninho de papelão que racha no chão, o miolo dos murundus e as
  salas do cupinzeiro. O tapete guarda quantos insetos sobram em cada
  pedacinho; a ponta da língua apaga o pedaço que toca, e a conta desce pelo
  número exato. Na beira do tapete, uns cupins (ou formigas) de verdade
  andam soltos, para ver de perto.
- **Nos andares de cima os cupins se amontoam**: o tapete fica mais grosso e
  vira monte, e o monte baixa quando você come (como os montes de dinheiro do
  SHRED A BILLION).

### 7.4 A escada dos gestos (o que faz o papel da automação)

| # | Gesto | O que muda | Quando (estimativa) |
|---|---|---|---|
| 1 | Lamber | 1 inseto por clique | 0:00 |
| 2 | Lambida Rápida | segurar o botão | ~0:01 |
| 3 | Bocado | vários por lambida (2 → milhares) | ~0:03 |
| 4 | Cavar | abre as câmaras (e, depois, as salas) | ~0:08 |
| 5 | Olheiro | a língua entra no buraco e puxa os escondidos (formigueiro, oco de árvore) | ~0:15 |
| 6 | Empinar | em pé nas patas de trás: lambe até 1,5 → 2,0 → 2,5 m | ~0:40 |
| 7 | Sacudir | as garras batem no tronco: as formigas caem como chuva, e os ninhos de papelão despencam | ~0:55 |
| 8 | Rasgar | abre os troncos caídos em pedaços (cada pedaço é uma câmara) | ~1:10 |
| 9 | Varrer | segurando, a língua arrasta pelo tapete e limpa uma faixa | ~2:15 |
| 10 | Terremoto | o pulo que puxa tudo em volta (o Tremor de hoje, maior) | ~3:00 |
| 11 | Fungada | o focinho puxa um cone de insetos de uma vez (o "aspirador" do SHRED e do Punch) | ~3:45 |

O tamanduá-bandeira de verdade empina nas patas de trás, apoiado na cauda, e
rasga cupinzeiros e madeira podre com as garras. A Fungada é a licença do
desenho (pergunta 7).

### 7.5 Trava por força: a dureza

O mapa inteiro está aberto desde o começo. O que segura é a **dureza** do que
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
- **Cada andar** guarda uns 1,7 vez os insetos do anterior (estimativa):
  andar 1 com ~3 mi, andar 10 com ~350 mi.
- **Bônus de ninho limpo**, como os 20 pontos de hoje, proporcional ao ninho.
- **Frenesi** (tanajuras e cogumelos) continua, e no Banquete multiplica.
  Uma ideia a mais: de vez em quando saem **aleluias** (cupins com asas)
  pelas janelas do cupinzeiro, e comê-las dá Frenesi.

### 7.7 Os ninhos

Espécies sugeridas com base na vida real; dá para trocar (pergunta 5).

| Ninho | Zona | Insetos (estimativa) | Como se come | Peças de hoje que servem |
|---|---|---|---|---|
| Formigueiro de saúva | 1 | 2 mil a 15 mil | trilhas, passeio e câmaras, como na área 1 | `nest.gd`, `colony.gd`, `ant_field.gd` |
| Tronco caído (formiga-carpinteira) | 2 | 20 mil a 150 mil | Rasgar abre o tronco em pedaços; serragem no chão denuncia o ninho | câmaras, a terra ao cavar (`dirt_fx.gd`), as lascas do tronco da saída |
| Árvore oca (formiga de embaúba) | 2 | 30 mil a 300 mil | uma fila sobe o tronco; Olheiro nos buracos (Empinar para os altos); Sacudir derruba as de fora | a subida no tronco (`ant_ground.gd`), o Olheiro |
| Ninho de papelão no galho (formiga ou cupim de árvore) | 2 | 100 mil a 800 mil | Sacudir derruba; no chão ele racha e vira tapete | (novo) |
| Correição (formiga-de-correição) | 2 | 200 mil a 1 mi | um rio de formigas atravessa a mata de vez em quando; é correr atrás | as trilhas (`trail_network.gd`) |
| Murundu (cupinzeiro pequeno) | 3 | 1 mi a 5 mi | Cavar abre; dentro, tapete | `nest.gd` |
| Sala do cupinzeiro gigante | 3 | de uns 300 mil (andar 1) a centenas de milhões (andares 9 e 10) | entrar e comer à vontade; tapete no chão e nas paredes | a câmara aberta |
| Rainha-mãe | 3 | a definir | a última; é o fim | a rainha da área 1 |

### 7.8 O cupinzeiro gigante

- **Tamanho** (estimativa): uns 40 m de largura na base e 60 m de altura,
  com 10 andares de uns 6 m. Os olhos do tamanduá ficam a 72 cm do chão:
  cada andar parece enorme.
- **Por dentro**: uma chaminé no meio (como a que alguns cupins de verdade
  fazem, para ventilar), uma rampa em espiral rente à parede de fora e um anel de salas em
  volta da chaminé. O andar 1 tem umas 10 salas; o andar 10, só a da
  rainha-mãe; umas 55 salas ao todo (estimativa).
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
  paredes. Isso existe no cerrado: no Parque
  Nacional das Emas, larvas do besouro *Pyrearinus termitilluminans* vivem em
  cupinzeiros e acendem luzes verdes para atrair presas (FAPESP, jan 2024).
  Por fora, o cupinzeiro também pode pontilhar de verde visto de longe.
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

- **Densidade** (estimativa): 500 a 800 árvores na mata, 1 em cada 10 a 15
  com insetos (as **árvores-ninho**); o resto é só cenário.
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
  automático: segurar a lambida com a ponta no tapete.
- **Mão cansada**: horas segurando o botão cansam. A Lambida Rápida ganha a
  opção "apertar uma vez", como Correr e Cavar já têm.
- **O que precisa ser gostoso** (a lista de capricho):
  - o "+12,3 mil" subindo do medalhão (hoje já sobe o "+1" e o "+20");
  - o monte de cupins baixando enquanto a língua passa;
  - a chuva de formigas ao sacudir, com o barulhinho delas caindo nas folhas;
  - o tronco abrindo em lascas e o ninho de papelão despencando e rachando;
  - o cartão a cada 10 níveis ("o dobro");
  - as salas do andar acendendo em verde no mapa quando ficam limpas;
  - o som de mastigar subindo de tom com o combo;
  - a vista do topo, no fim.

---

## 8. Habilidades do Banquete (rascunho)

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
| | Varrer | sem teto | largura e velocidade da faixa no tapete |
| **Garras** | Cavar e Força | 14 durezas | o que dá para abrir (seção 7.5) |
| | Rapidez | ~20 | o descanso das garras e o tempo de cavar |
| | Sacudir | 4 | a grossura do tronco |
| | Tremor e Terremoto | ~10 | atordoa e puxa as tontas |
| **Patas** | Corrida, Respiro, Passada, Fôlego | ~10 cada | como hoje, com mais níveis |
| | Empinar | 3 | 1,5 → 2,0 → 2,5 m |
| **Faro** | Rastro e Família | ~6 cada | achar ninhos, salas e o que falta |
| | Faro no escuro | ~3 | ver os insetos na mata escura e no fundo das salas |
| **Focinho** (no lugar da Escalada) | Fungada | sem teto | o cone que puxa |

---

## 9. Sistemas, na ordem de construção

### 9.1 Dividir o código entre os dois modos (o primeiro e o mais arriscado)

Hoje quase tudo supõe a área 1:

| Onde | O que é fixo hoje | O que muda |
|---|---|---|
| `scripts/autoload/game_state.gd` | `GOAL` (10 000), `BRANCHES`, `MARCOS`, `UPGRADES` e as contas das habilidades (`lick_capacity()`, `tongue_range()`, `lick_rate()`...), feitas por cliques | Os dados de cada modo em arquivos próprios (`scripts/modes/normal.gd` e `scripts/modes/banquete.gd`); no Banquete, as contas por nível. Números em `int` (64 bits, até 9 × 10^18) |
| `scripts/main.gd` | Sempre monta o `World` da área 1 | Monta o mundo do modo escolhido |
| `scripts/world/terrain.gd` (`SIZE` 160 m, `RES` 256), `scripts/ants/ant_ground.gd` (`SIZE` 64 m), `scripts/ants/ant_field.gd` (`HEIGHT_SIZE` 160 m), `scripts/world/cliffs.gd` (`BASE_RADIUS` 26 m), `scripts/world/world.gd` (`NEST_LAYOUT`, `FOOD_LAYOUT`, `LINKS`) | Tamanhos e posições da área 1 | Viram a configuração de cada mundo |
| `scripts/ants/ant_swarm.gd` (`CAPACITY` 4 096) | Teto das formigas simuladas uma a uma | Continua; o que passar disso vai para o tapete |
| Jogos salvos (`game_state.gd`, `SAVE_VERSION` 9) | 3 jogos do modo normal | Mais 3 só do Banquete (`user://banquete_N.json`), com versão própria; a coleção (`user://save.cfg`) ganha a área 3 |

**Teste de que o modo normal não mudou:** o bot com a mesma semente antes e
depois da divisão (`--autoplay --botlog`), comparando os CSVs (no máximo 5% de
diferença no tempo de cada marco), e capturas do menu, do mapa e da árvore.

### 9.2 A ordem

1. **A divisão do código** (9.1).
2. **Menu e jogos salvos**: o botão novo no `scripts/ui/menus.gd` e a tela
   de jogos salvos do Banquete.
3. **Números grandes**: a forma curta (mil, mi, bi) num lugar só
   (`scripts/ui/ui_theme.gd` ou um `scripts/ui/numeros.gd`), usada no
   medalhão, nos cartões, no mapa e na árvore.
4. **Economia por níveis e a árvore com níveis** (`scripts/ui/skill_tree.gd`):
   ×1, ×10 e Máx, "Nv 37", o cartão a cada 10 níveis.
5. **O mundo da área 3** (`scripts/world/area3/`): terreno de uns 140 × 180 m
   com o platô, penhascos em volta, a caverna, as três zonas e a passagem de
   luz entre elas.
6. **Os formigueiros do começo**: `nest.gd` com números maiores.
7. **O tapete** (`scripts/world/area3/tapete.gd` e
   `shaders/tapete_insetos.gdshader`): uma imagem pequena por tapete guarda
   quantos insetos sobram em cada pedacinho; a ponta da língua apaga, como o
   `mask_paint` do terreno; a altura do monte acompanha. Na beira, uns
   insetos de verdade (o modo "morando numa câmara aberta" do `ant_swarm.gd`).
8. **A mata**: árvores feitas com 12 a 20 modelos repetidos (em vez de uma
   malha para cada árvore), versões simples de longe, sombra só perto, uma
   imagem da copa que escurece o chão, o capim e as formigas embaixo dela
   (mais barato que sombra de verdade de centenas de árvores) e os raios de luz.
9. **Árvores-ninho e troncos caídos**: um tipo novo de trilha em
   `ant_field.gd`, que sobe o tronco; Olheiro nos buracos; Empinar; Sacudir
   (formigas caindo, que viram tapete no chão); Rasgar (o tronco em pedaços);
   o ninho de papelão que cai e vira tapete.
10. **O cupinzeiro por dentro**: andares, rampa, salas, chaminé, janelas,
    colisão, a luz das larvas, e só o andar onde você está (mais o de cima e
    o de baixo) desenhado por dentro.
11. **Objetivos e mapa do Banquete**: a sequência guiada dos primeiros 30
    minutos (como a da área 1) e um objetivo por zona e por andar
    (`scripts/ui/objectives.gd`); no mapa (`scripts/ui/map_view.gd`), uma
    vista por andar do cupinzeiro.
12. **Colecionáveis da área 3, conquistas e estatísticas.**
13. **O bot do Banquete e o balanceamento.**
14. **Desempenho e polimento.**

### 9.3 Desempenho

- **Meta**: pelo menos 60 quadros por segundo no preset Média nos três
  lugares mais pesados (o meio da mata; a beira do cupinzeiro, olhando a
  mata; uma sala cheia de tapete), medido com F3 e `--stats`. Para comparar:
  a área 1 roda hoje entre uns 130 e 180 na máquina de teste (RTX 5070,
  3440×1440), segundo o histórico do `DESIGN.md`.
- **Árvores**: no máximo uns 20 modelos diferentes; o resto repetido.
- **Insetos um a um**: no máximo as 4 096 formigas simuladas de hoje, mais as
  formigas de campo calculadas pela placa de vídeo (medir até quantas cabem
  numa zona; a área 1 tem uns 5 500 andando); o resto em câmaras (como número)
  ou em tapete.
- **Cupinzeiro**: o que está em outros andares não é desenhado por dentro.

---

## 10. Ferramentas primeiro (antes do conteúdo)

1. **Simulador da economia** (`tools/sim_banquete.py`, em Python como os
   outros de `tools/`): lê os mesmos dados que o jogo (`data/banquete.json`:
   insetos de cada ninho, durezas, preços, efeitos) e simula um jogador que
   compra o nível que mais rende por ponto e come o ninho que mais rende por
   segundo. Diz o tempo até o fim, o tempo entre as compras, quando chega cada
   gesto e se alguma trava ficou impossível. Roda em segundos: dá para testar
   dezenas de curvas numa tarde.
2. **Validador das travas** (no mesmo script): para cada dureza, prova que
   os insetos abaixo dela dão os pontos para comprá-la, com folga (1,3 vez),
   mesmo comprando mal. Se falhar, aponta onde e sai com erro.
3. **A planta em dados** (`data/banquete_mapa.json`: zonas, ninhos,
   árvores-ninho, andares, salas, rampas), lida pelo gerador do mundo e pelo
   simulador (as distâncias entram no tempo).
4. **O bot no Banquete** (`--autoplay` e `--botlog`), para conferir o
   simulador no jogo de verdade. Na área 1, o bot é umas 3 vezes mais lento
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
- Os jogos salvos do modo normal (versão 9) continuam abrindo.
- Os números de insetos e pontos em `int` (64 bits).
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
| **B0. Papel e simulador** | A seção 10, a planta do mapa e a do cupinzeiro, e as perguntas da seção 16 respondidas | O simulador dá 4 a 6 h sem trava; o Caio aprova as duas plantas | P |
| **B1. Fundação** | A seção 9.1, o menu, os jogos salvos, os números grandes e a economia por níveis | "Banquete" no menu abre um mapa vazio de uns 140 × 180 m, com penhascos e caverna; o modo normal fica igual (bot e capturas); os jogos salvos dos dois não se misturam | M |
| **B2. Fatia jogável** | Um campo pequeno com 3 formigueiros, 1 tronco caído, 1 árvore-ninho (Empinar e Sacudir), 1 andar do cupinzeiro com 3 salas de tapete, e a árvore com níveis | 30 minutos jogáveis, do começo até limpar o 1º andar; o teste com 3 pessoas da seção 4 | G |
| **B3. Cerrado aberto** | A zona 1 inteira | O bot limpa a zona no equivalente a uns 35 min de uma pessoa | M |
| **B4. Mata de galeria** | A zona 2 inteira: escuridão, árvores-ninho, troncos, ninhos de papelão, correição | Pelo menos 60 quadros por segundo no Média no meio da mata; o bot chega ao cupinzeiro no equivalente a umas 2h15 de uma pessoa | G |
| **B5. O cupinzeiro** | Os 10 andares, salas, rampas, chaminé, larvas, a rainha-mãe e o fim | Dá para subir do chão ao topo e terminar; nenhuma sala sem saída; nenhum lugar onde a câmera atravessa a parede | G |
| **B6. Economia fechada** | Balanceamento com o simulador e o bot, colecionáveis, conquistas, objetivos, o mapa por andar | O bot termina na faixa de 4 a 6 h de uma pessoa, sem trava, com 3 sementes diferentes | M |
| **B7. Polimento e versão de teste** | Textos, sons, desempenho e a versão para os amigos (a automação do GitHub que já existe) | 3 pessoas jogam pelo menos 2 h, e anotamos onde pararam de sorrir | M |

P = alguns dias de sessões; M = 1 a 2 semanas; G = 3 semanas ou mais
(estimativa, pelo ritmo do repositório em novembro).

---

## 14. Como conferir cada etapa

- **B0**: `python3 tools/sim_banquete.py` mostra a tabela do ritmo e sai com
  erro se alguma trava falhar.
- **B1 a B7**: a sessão baixa o Godot 4.7.2 (do mesmo jeito que o
  `.github/workflows/versao.yml`) e roda o bot e as capturas. A opção para
  começar direto no Banquete (`--start=banquete`) é criada na B1, junto com as
  de hoje (`--autoplay`, `--timescale`, `--botlog`, `--captures`, `--quit`).
- **O modo normal**: a mesma linha do bot de hoje, comparada com os
  `docs/dados/bot-marcos-*.csv`.
- **Desempenho**: `--stats` e F3 nos três lugares da seção 9.3, numa máquina
  com placa de vídeo (as capturas do servidor sem placa de vídeo não servem
  para medir quadros por segundo).
- **Os registros** do bot vão para `docs/dados/bot-banquete-*.csv`, como os
  da área 1.

---

## 15. Riscos (do maior para o menor)

1. **Conteúdo demais.** 4 a 6 horas são de 12 a 18 vezes a área 1. Saída:
   ferramentas e dados primeiro, peças repetidas com variação (como as
   câmaras), e a fatia jogável antes do resto.
2. **Quebrar o modo normal ao dividir o código.** Saída: a seção 9.1, com o
   bot e as capturas antes de cada junção.
3. **Travar no fim.** Num modo finito e sem automação, se faltar ponto o jogo
   para. Saída: o validador, redistribuir de graça e a rede de segurança.
4. **O tapete não convencer** (parecer uma textura, e não insetos). Saída:
   testar já na B2; insetos de verdade na beira; o monte que baixa.
5. **Mão cansada.** Saída: a Lambida Rápida com "apertar uma vez"; Varrer e
   Fungada cobrem mais área com menos cliques.
6. **Mata escura demais** para ver as formigas. Saída: o contorno, o Faro no
   escuro, os raios de luz; testar nos presets Baixa e Média.
7. **Desempenho da mata** (centenas de árvores). Saída: modelos repetidos,
   versões de longe, sombra só perto, a imagem da copa no lugar de sombras de
   verdade.
8. **Dentro do cupinzeiro**: em 1ª pessoa, em lugar fechado, a câmera pode
   atravessar a parede, e dá para se perder. Saída: salas largas, janelas, o
   mapa por andar e o losango do objetivo.
9. **Parecer cópia** do "bilhão" do SHRED A BILLION. Saída: a pergunta 2.
10. **Dois modos para manter** (dois balanceamentos). Saída: dados separados
    e as mesmas peças.

---

## 16. Perguntas em aberto (e o que vale se ninguém responder)

| # | Pergunta | Vale, se ninguém responder |
|---|---|---|
| 1 | O Banquete fica junto das áreas 2 a 4 do modo normal, ou as substitui? | Os dois seguem, e tudo é feito para servir aos dois |
| 2 | A meta: 1 bilhão (como o SHRED A BILLION) ou outro número? | 1 bilhão de insetos |
| 3 | As massas grandes viram tapete (a conta é exata, o desenho é uma massa)? | Sim, acima de alguns milhares juntos; abaixo disso, cada inseto anda sozinho, como hoje |
| 4 | O nome no menu | "Banquete" |
| 5 | As espécies: saúva, formiga-carpinteira, formiga de embaúba, ninho de papelão (formiga ou cupim de árvore), correição e cupim de murundu | Essas |
| 6 | Os colecionáveis da área 3 dão bônus (como as relíquias do SHRED)? | Sim, de 3% a 5% cada, só no Banquete; no modo normal continuam só coleção |
| 7 | A Fungada (o "aspirador" do focinho) como último gesto? | Sim, a partir do andar 7 |
| 8 | A correição (o rio de formigas que atravessa a mata)? | Sim, mas só na B6 |
| 9 | O combo dá pontos? | Sim, pouco (até 20% a mais) |
| 10 | O Banquete entra na demo da Steam? | Não: a demo continua sendo a área 1 |
| 11 | Dá para continuar depois do fim, para limpar o mapa inteiro? | Sim, com a conquista de limpar tudo |
| 12 | Os amigos que testarem mandam um registro da partida (um arquivo que eles enviam se quiserem)? | Não: só o bot e as estatísticas de hoje, nada pela internet |

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
