# Anteater Simulator: documento do jogo (consolidado)

Este documento junta, em um lugar só, tudo o que já foi definido sobre o jogo:

- o **documento de design** original (antes no README da `main`);
- o **plano de produção** ([`docs/PLANO.md`](PLANO.md));
- o **protótipo 2D do loop** (pasta [`prototipos/m1-loop/`](../prototipos/m1-loop/));
- a **demo 3D** (o projeto principal deste repositório) e as escolhas feitas na
  conversa em que ela foi criada;
- as **decisões de 02/11/2026**, tomadas para resolver o que não batia;
- as **mudanças pedidas depois do primeiro e do segundo teste** da demo (também
  de 02/11/2026).

Quando algo aqui contradiz uma fonte antiga, **vale este documento**.

---

## 1. O jogo em poucas palavras

Um jogo **relaxante de "arrumar e limpar"**. Você é um **tamanduá-bandeira**
que come **formigas e cupins** no **cerrado**, evolui habilidades e deixa a
região **100% limpa**. Aí o jogo acaba: não existe loop infinito e não dá para
perder.

**A história:** o tamanduá acorda numa caverna e vê, lá longe, um **cupinzeiro
gigante**. A barriga ronca: ele quer comer e chegar até lá. O caminho passa por
4 áreas do cerrado (seção 3).

**Para PC (Steam)**, por **até R$ 20**, em **3D estilizado** com cara de filme
de animação, visto **pelos olhos do tamanduá**.

### Inspirações

As principais são ***Leaf it Alone*** e ***Librarian: Tidy Up the Arcane
Library***. O documento original também cita *Supermarket Chaos*. O que
buscamos, no espírito delas:

- uma tarefa simples que dá prazer de repetir;
- progresso sempre visível: dá para ver quanto falta limpar;
- sem pressa e sem punição;
- um fim claro, quando tudo está limpo;
- melhorias que deixam a tarefa mais gostosa, não só mais rápida.

---

## 2. O que já existe

| | O que é | Onde está | Situação |
|---|---|---|---|
| **Documento de design** | As regras e ideias do jogo inteiro | Seção 6 deste documento | Consolidado aqui |
| **Plano de produção** | Etapas de M1 a M5, riscos e cortes sugeridos | [`docs/PLANO.md`](PLANO.md) (resumo na seção 7) | Escrito |
| **Protótipo M1 (2D)** | Testa só a sensação de comer: 1 ninho com 6 câmaras, 259 insetos e a rainha. Gráfico simples de propósito | Pasta [`prototipos/m1-loop/`](../prototipos/m1-loop/), um projeto Godot à parte (detalhes na seção 8) | Jogável |
| **Esboço do mapa** | As 4 áreas do jogo completo, cercadas por penhascos | Seção 3 ([`esboco-mapa.png`](esboco-mapa.png)) | Base para o formato, que pode mudar |
| **Demo 3D** | A área 1 (uma clareira do cerrado, sempre no fim da tarde), em 1ª pessoa: começa numa caverna, cercada por penhascos, com o cupinzeiro gigante lá longe; 3200 formigas, 12 formigueiros e 58 câmaras (12 no meio do campo), rainhas, 5 habilidades (28 níveis), jogo salvo e um tronco caído que fecha a saída | Projeto principal, na raiz do repositório (detalhes na seção 8) | Jogável, já seguindo as decisões (seção 4) |

---

## 3. O jogo, como está decidido

### Plataforma, preço, visual e câmera

- **PC primeiro, na Steam.** Mouse e teclado, e também controle. Celular pode
  vir depois.
- **Preço:** no máximo **R$ 20**.
- **3D estilizado**, com cara de filme de animação. Nada de pixel art, nada de
  low poly.
- **1ª pessoa:** você vê o mundo pelos olhos do tamanduá, com o focinho na parte
  de baixo da tela. Os olhos ficam a **72 cm do chão**, e dá para **subir nos
  formigueiros** para olhar dentro das câmaras. Correndo, a câmera balança de
  leve (dá para desligar). *Atenção (do plano): câmera livre deixa a criação das
  fases mais cara do que câmera fixa.*
- **Tela:** janela, tela cheia ou tela cheia exclusiva, em várias resoluções, e
  opções gráficas separadas (sombras, capim, suavização, efeitos de luz).
- **Modelos 3D gerados por IA**, todos no mesmo estilo. Os prompts estão em
  [`prompts-ia.md`](prompts-ia.md). O formigueiro já foi gerado na Artlist e
  falta baixar (precisa de um plano com créditos).
- **Motor:** Godot 4.7.

### Tamanho e mapa

- **Um mapa só, todo no cerrado, com 4 áreas** ligadas por passagens estreitas
  e cercado por **penhascos**, que são o limite do mapa. Você anda de uma área
  para a outra sem telas de carregamento. O formato do esboço (abaixo) é uma
  base e pode mudar com o tempo.
- O cerrado é a savana brasileira (a "Savana" do documento original). As árvores
  vão ficar um pouco mais densas.
- **A demo é a área 1**, uma **região completa de 45 a 60 minutos**, com **12
  ninhos**: 8 em volta e 4 no meio. Os formigueiros ficaram cerca de 45% maiores.
- **Na área 1, os ninhos são só formigueiros**, de uma formiga que fica só no
  chão, com as câmaras da demo. Os cupinzeiros aparecem apenas como cenário.
- **3200 formigas** (eram 1000). Somando o preço de todas as habilidades do
  Cerrado dá **2485 pontos**: dá para aprender tudo e ainda sobram cerca de
  **715 formigas** (uns 3 formigueiros) para jogar com tudo liberado.
- **Por enquanto as habilidades ficam como estão.** A pontuação e a quantidade
  de formigas e cupins para liberar tudo serão reavaliadas mais para a frente.

### O mapa: 4 áreas (esboço de 02/11/2026)

![Esboço do mapa: a área 1 pequena embaixo, a área 2 no meio e a área 3 grande, com o cupinzeiro gigante (área 4) dentro; a borda amarela são os penhascos](esboco-mapa.png)

| Área | Como é | Insetos | Como se chega |
|---|---|---|---|
| **1** | Uma clareira: onde se passa a demo | Formigas que ficam só no chão, com as câmaras da demo | É o começo: o tamanduá sai de uma caverna |
| **2** | Árvores mais densas | Outro tipo de formiga, que consegue ficar nas árvores | Liberada ao limpar 100% da área 1 |
| **3** | A área grande, em volta do cupinzeiro gigante | Cupins | Depois da área 2 |
| **4** | Um **cupinzeiro gigante**: dá para ir subindo nele e comendo os cupins | Cupins | Dentro da área 3 |

- **A área 4 aparece desde a área 1**, lá longe: é o lugar aonde o tamanduá
  quer chegar.
- **História:** o tamanduá acorda numa caverna, vê o cupinzeiro gigante lá de
  longe, a barriga ronca, e ele decide comer e ir até lá.
- **Foco agora:** a demo (área 1) e o refinamento dela.

### A área 1 (a demo), decidida em 02/11/2026

- **Tamanho:** continua com cerca de 120 m de um lado ao outro. Em volta, no
  lugar da parede invisível, ficam **penhascos de arenito** (faixas creme e
  vermelhas), com árvores no platô lá em cima.
- **Começo:** o tamanduá acorda no fundo de uma **caverna** no pé do penhasco,
  já de frente para o cupinzeiro gigante, e a **barriga ronca** uma vez. Dá para
  jogar logo; um vídeo de abertura fica para depois.
- **O cupinzeiro gigante** aparece lá longe, por cima dos penhascos, no rumo da
  saída. Ele fica dentro do mapa, nas áreas mais adiante. **Não brilha.**
- **Horário fixo:** é sempre o mesmo fim de tarde. O sol não se põe enquanto
  você joga.
- **Saída para a área 2:** uma passagem estreita entre os penhascos, fechada
  por um **tronco caído**. Com a clareira 100% limpa, a bússola mostra a saída;
  perto do tronco, segure **E** e as garras quebram o tronco. Na demo, isso é o
  fim: o caminho até o cupinzeiro fica aberto.
- **Lagoas:** uma ou duas, **só de enfeite** (não têm insetos nem mudam o jogo).
- **A barriga não aponta o caminho:** ela só ronca no começo.
- **Ideia para a área 2:** um nível das **Garras** que deixa **escalar ou
  quebrar a árvore** para comer as formigas que moram nela (a outra opção é a
  Escalada + Cauda).

### Como se come: os dois jeitos juntos

- **Trilhas:** formigas andam pelo mapa entre os ninhos e os arbustos, e chegam
  em ondas. Você lambe as que estão de passagem.
- **Ninhos com câmaras:** cada ninho tem câmaras internas. Você cava com as
  Garras e esvazia uma por uma, com a satisfação de terminar de arrumar uma
  prateleira. Ao abrir, as moradoras **saem correndo** e fogem quando você chega
  perto (como as das trilhas); depois voltam para a câmara. Algumas câmaras
  ficam **sozinhas no meio do campo**, longe das trilhas: o Faro ajuda a achá-las.
- Depois de abrir uma câmara, **as garras descansam** (25 s no começo).
- A **língua** começa com **um clique por lambida**, e cada lambida pega um
  inseto. A primeira habilidade (**Lambida Contínua**, 25 pontos) deixa segurar
  o botão; a linha de **Bocado** aumenta quantas vêm de uma vez: 5, 15, 25 e 40.
- **O fim:** a região está limpa quando não sobra nenhum inseto, nem nas trilhas
  nem dentro dos ninhos.

### Desafio extra: rainha e tanajura

- **Rainha:** aparece **só nos ninhos grandes**, na câmara mais cheia, coberta
  por outros insetos. Só dá para comê-la depois de limpar tudo em volta. Vale
  **15 a 20 vezes** um inseto comum e tem efeito e som próprios. O Faro nível 3
  ajuda a encontrá-la.
- **Tanajura:** rainha voadora e rara que cruza o mapa. Comê-la deixa a língua
  mais rápida por alguns segundos.
- **Sem insetos resistentes:** as formigas-soldado saíram da demo.

### Habilidades: as 5 do plano

**Cada formiga comida vale 1 ponto** (a rainha vale 20), e **cada habilidade tem
o seu preço**. Você escolhe onde gastar, e os gestos novos (segurar para lamber,
lambida, cavar, escalar) também são comprados assim. Dá para redistribuir os
pontos de graça.

Cada ramo começa com uma habilidade e depois se divide em **duas linhas que não
se excluem** (dá para seguir as duas).

| Habilidade | Linha | Níveis (preço em pontos) |
|---|---|---|
| **Língua** | começo | Lambida Contínua (25: segurar para lamber) |
| | Bocado | Lambida (40: até 5 por lambida) · Lambida Larga (75: até 15) · Lambida Gulosa (115: até 25) · Lambida Voraz (170: até 40) |
| | Destreza | Língua Comprida (70: +50% de alcance) · Saliva Grudenta (100: gruda num raio 70% maior) · Língua Turbo (150: 2x mais rápida) |
| **Garras** | começo | Cavar (35: abre as câmaras; depois as garras descansam 25 s) |
| | Força | Garras Fortes (70: as moradoras ficam tontas ao abrir) · Tremor (110: pulo com pancada; recarga de 21 s) · Terremoto (170: pulo mais alto, tremor maior, puxa as tontas) |
| | Rapidez | Garras Ágeis (50: descanso de 15 s) · Garras Incansáveis (95: descanso de 5 s e cava na metade do tempo) · Recarga do Tremor (130: Tremor em 14 s) · Recarga Relâmpago (150: Tremor em 7 s) |
| **Patas** | começo | Corrida (30: +25% de velocidade; correndo não dá para lamber) |
| | Velocidade | Patas Ligeiras (80: mais 25%) · Galope Silencioso (130: correr não assusta) |
| | Agilidade | Lamber Correndo (60) |
| **Faro** | começo | Farejar (20: diz quantas formigas há a até 10 m e a distância da mais perto) |
| | Alcance | Faro Atento (40: 16 m, 25 formigas) · Faro Apurado (70: 24 m, 50) · Faro Aguçado (110: 34 m, 100, e quanto falta em cada formigueiro) · Faro Lendário (160: 50 m, 200, e as rainhas). Cada nível também recarrega mais rápido (10 s → 6 s) |
| | Precisão | Faro Preciso (45: nuvem borrada onde estão) · Faro Nítido (85: as formigas brilham nítidas) · Faro de Câmara (100: colunas de cheiro nas câmaras fechadas) |
| **Escalada + Cauda** | | Escalada (300) · Cauda Preênsil (400): ainda não feitas, aparecem com cadeado |

**Habilidades por região:** a **Escalada + Cauda** aparece na árvore desde o
começo, com um cadeado, e só vai poder ser comprada **quando você chegar à
floresta**, onde ela é usada.

**Fora por enquanto:** Camuflagem (repete o que a Língua já faz) e Natação. O
**Focinho** volta junto com o Quintal urbano.

---

## 4. A demo hoje (atualizada em 02/11/2026)

Feito, seguindo as decisões:

1. **12 formigueiros**, 5 deles grandes, com **46 câmaras fechadas**, e mais
   **12 câmaras sozinhas no meio do campo**, longe das trilhas (cada uma conta
   para o formigueiro mais perto). Segurando **E** com a habilidade Cavar, a
   câmara abre e as moradoras **saem correndo**; elas fogem quando você chega
   perto e depois voltam para casa. Até 40 ficam à vista; as outras saem do
   túnel conforme você come. Depois de cavar, as garras descansam.
2. **Dá para subir nos formigueiros** e olhar dentro das câmaras lá de cima.
3. **Rainha** na câmara do topo dos 5 formigueiros grandes. Brilha de leve, fica
   protegida enquanto houver formigas na câmara e **vale 20**.
4. **As 3200 formigas** são divididas assim: cerca de 45% andam pelas trilhas
   (e voltam para casa), o resto mora nas câmaras. 3100 operárias + 5 rainhas × 20.
5. **Soldados:** saíram. A **tanajura** continua.
6. **As 5 habilidades, com 28 níveis**, cada um com seu preço (seção 3). A
   língua começa com um clique por lambida; correndo não dá para lamber até
   aprender Lamber Correndo. Farejar também precisa ser aprendido. O **Tremor**
   é um pulo: a pancada vem ao cair. A **Escalada + Cauda** aparece com cadeado.
   Dá para **redistribuir os pontos**.
7. **Progresso visível:** contador de formigueiros limpos, pontos e a próxima
   habilidade no canto da tela, avisos de câmara limpa e de habilidade nova, e
   florzinhas no formigueiro quando ele fica limpo. O Faro mostra, conforme os
   níveis, quantas formigas há, uma nuvem onde elas estão, as formigas brilhando
   e as câmaras fechadas; o Faro Aguçado mostra na bússola quanto falta em cada
   formigueiro e o Faro Lendário marca as rainhas. O aviso de **onda** fica
   discreto no painel da direita.
8. **Jogo salvo:** salva sozinho a cada 30 s, ao pausar e ao sair. A tela
   inicial ganha **Continuar** e **Novo jogo**. Jogos salvos da versão com 1000
   formigas não são carregados (o mapa mudou).
9. **Configurações** em abas (Tela, Gráficos, Jogo, Áudio): janela, tela cheia
   ou tela cheia exclusiva, resolução, resolução do 3D, VSync, limite de FPS,
   sombras, capim, suavização, efeitos de luz, balanço da câmera e **cor do
   faro** (vermelho, ciano, magenta ou branco). **F11** ou **Alt+Enter**
   alternam a tela cheia.
10. **Pausa de verdade:** na pausa e na árvore de habilidades, as formigas e as
   ondas param.
11. **Penhascos** em volta da clareira, que são o fim do mapa, com árvores no
   platô e pedras soltas no pé.
12. **Começo na caverna:** o tamanduá acorda numa caverna no pé do penhasco,
   olhando para o **cupinzeiro gigante** lá longe, e a barriga ronca.
13. **Fim da demo:** a passagem para a área 2 fica fechada por um **tronco
   caído**. Com 100% limpo, a bússola mostra a saída; segurando **E** perto do
   tronco, as garras quebram o tronco e a demo termina.
14. **Sempre o mesmo fim de tarde** (o sol não se põe mais) e **duas lagoas** de
   enfeite.

Ainda a ajustar:

- **Duração:** a meta é de 45 a 60 minutos, e ela vai ser medida jogando (sem
  o robô de testes). Como referência: num teste automático da segunda rodada, um
  robô de mira perfeita terminou as 3200 formigas em cerca de 19 minutos.

---

## 5. Ainda em aberto

- **O vídeo de abertura:** o tamanduá acordando na caverna (fica para depois).
- **A formiga das árvores (área 2):** que espécie é, e qual habilidade leva até
  ela: a Escalada + Cauda ou um nível das Garras que escala ou quebra a árvore.
- **Os cupins (áreas 3 e 4):** como são os ninhos (câmaras, rainha?) e como é
  subir no cupinzeiro gigante.
- **A "outra floresta":** era a ideia anterior para depois do Cerrado. Com o
  mapa todo no cerrado, fica de fora? (As lagoas já entraram, só de enfeite.)
- **Quintal urbano:** quando entra, e se o Focinho volta com ele.

---

## 6. Documento de design original (referência)

Como estava no README da `main`. Onde ele contradiz a seção 3, vale a seção 3.

### Escopo

- **Duração:** 3 a 5 horas para fazer 100%, para um jogador comum.
- **Regiões:** Savana, Floresta e Quintal urbano.
- **Ninhos:** 8 a 10 por região (~27 no total), de 3 a 6 minutos cada (~90 a
  160 minutos só comendo, sobrando tempo para andar e usar habilidades).
- **Insetos:** ~800 a 1.200 no jogo inteiro, aumentando de ninho para ninho.
- **Sem loop infinito:** mapa 100% limpo = fim, como em *Leaf it Alone*.

### Como se come

1. Tocar num inseto: ele é comido na hora, com efeito e som rápidos.
2. A língua evoluída libera a **lambida**: arrastar pelo ninho come vários.
   Evoluir vira um **gesto novo**, não só um número subindo.
3. Cada ninho tem **câmaras**; esvaziar uma dá a satisfação de terminar de
   arrumar uma prateleira.

### Regiões e seus ninhos

| Região | Como são os ninhos |
|---|---|
| Savana (Cerrado) | Cupinzeiros em forma de torre |
| Floresta | Formigueiros de folha e ninhos em árvores |
| Quintal urbano | Fendas no cimento |

> A ordem de liberar as regiões (por Faro ou Garras) estava em aberto.

### Habilidades

| Habilidade | Para que serve |
|---|---|
| **Língua** | Come mais rápido; fica mais comprida e grudenta; libera a lambida |
| **Patas** | Anda mais rápido; libera a corrida |
| **Garras** | Abre ninhos maiores e bloqueios; chave para novas regiões |
| **Escalada + Cauda** | Sobe em árvores e se pendura na cauda para alcançar ninhos embaixo de galhos ou do outro lado de um vão |
| **Focinho** | Sonda fendas estreitas que a garra não abre; essencial no Quintal |
| **Camuflagem** | Os insetos reagem menos à sua presença (ficam mais parados); outro caminho, além da Língua, para ficar mais eficiente |
| **Faro** | Ver abaixo |
| **Natação** *(futuro)* | Chave para uma possível 4ª região, como brejo ou beira de rio |

**O Faro em detalhe:** fica mais preciso e alcança mais longe conforme evolui.

- Revela ninhos escondidos, inclusive entradas de novas regiões.
- Mostra a "qualidade" de um ninho antes de você ir até lá (vale a pena ou não).
- Acha insetos esquecidos, em 3 níveis:
  - **Nível 1:** avisa que sobrou algo perto (raio curto, sem direção).
  - **Nível 2:** aponta a área dentro do ninho.
  - **Nível 3:** marca o inseto exato, funciona à distância e avisa até em
    ninhos que pareciam prontos.

### Rainha

- Fica no ponto mais cheio do ninho, coberta por outros insetos.
- Só dá para comê-la depois de limpar tudo em volta.
- Vale **15 a 20 vezes** um inseto comum, com efeito e som próprios.
- O Faro nível 3 ajuda a encontrá-la.

### Descartado

- Ninhos que os vizinhos "retomam" (iria contra um jogo curto e com fim).
- Insetos mais fortes ou resistentes (a rainha já é o desafio extra).

---

## 7. Plano de produção (resumo)

O plano completo está em [`docs/PLANO.md`](PLANO.md).

**A pergunta que vem antes de tudo:** comer um inseto é gostoso o bastante para
sustentar o jogo inteiro? O protótipo 2D existe só para responder isso: jogue
até o fim e depois veja 3 pessoas jogando, sem falar nada.

| Tempo para limpar o ninho do protótipo | O que significa |
|---|---|
| 3 a 6 min | O número de insetos está certo |
| Mais de 8 min | Ninho grande demais ou lambida lenta (cortar insetos antes de cortar ninhos) |
| Menos de 2 min | Cabe mais conteúdo por ninho, ou o mapa pode ter menos ninhos |

Anote também **quando a lambida foi liberada** e se aquilo foi um alívio: é o
teste da melhor ideia do documento (evoluir vira gesto novo).

**Riscos apontados**

1. **Repetição:** só **Escalada + Cauda** (e o Focinho, no Quintal) mudam o
   gesto de verdade. São as mais caras e as mais importantes.
2. **Camuflagem repetida:** cortada (decisão de 02/11).
3. **Caçar os últimos 5%:** procurar o último inseto pode ser chato. O Faro
   resolve, mas não pode entregar tudo cedo demais.

**Corte que o plano sugeria** (antes das decisões de 02/11): 2 regiões
(Savana e Floresta, ~16 ninhos), Quintal como atualização depois do lançamento,
sem Natação e sem Camuflagem, e 5 habilidades. Para a ordem das regiões, a
sugestão era Savana → Floresta (com Garras + Escalada) → Quintal (com Focinho).
Também recomendava lançar a página na Steam **antes** da segunda região.

**Etapas**

| Etapa | Objetivo | Pronto quando... |
|---|---|---|
| **M1: Sensação** | Protótipo do ato de comer | Você e mais 2 pessoas quiseram terminar o ninho |
| **M2: Fatia vertical** | Um ninho no visual final, câmera de verdade, andar entre dois ninhos, um upgrade, salvar o jogo | Um vídeo de 15 s que dá vontade de jogar |
| **M3: Uma região inteira** | Cerrado completo: todos os ninhos da região e a árvore de habilidades | 45 a 60 min de jogo sem problemas de progressão |
| **M4: Página na Steam + demo** | Medir interesse (lista de desejos) antes da próxima região | Página no ar com demo |
| **M5: Próxima região + lançamento** | Polimento e lançamento | Jogo lançado |

**Onde estamos:** a demo 3D já cobre a M2 (visual final, câmera de verdade,
andar entre ninhos, habilidades e jogo salvo) e boa parte da M3 (o Cerrado com
12 formigueiros e a árvore de habilidades). Falta acertar a duração com testes.

---

## 8. As versões jogáveis

### Protótipo M1 (2D), pasta `prototipos/m1-loop/`

- **Como abrir:** é um projeto separado da demo 3D. No Godot, clique em
  **Importar** e escolha o `project.godot` de dentro de `prototipos/m1-loop/`.
  Testado no Godot 4.7, jogado do começo ao fim.
- **Clique:** come 1 inseto. **Segurar e arrastar:** lambida. **F:** Faro.
  **R:** recomeça.
- **Ninho:** 6 câmaras com 259 insetos. A câmara do topo é a mais cheia e guarda
  a rainha, atrás de um bloqueio de terra que as Garras quebram.
- **Evolução automática** pelo total comido: Faro I (25), Lambida (50),
  Faro II (100), Garras (150), Faro III (175), Língua III (185).
- No fim, mostra **insetos por minuto** e o **tempo total**.

### Demo 3D, projeto principal

- **1ª pessoa** numa clareira do cerrado, sempre no mesmo fim de tarde, cercada
  por **penhascos**. Começa numa **caverna**, de frente para o **cupinzeiro
  gigante** lá longe, e termina quebrando o **tronco caído** que fecha a saída.
- **12 formigueiros** (5 com rainha) e **58 câmaras** para abrir e esvaziar (12
  delas no meio do campo); dá para subir nos montes. As formigas das câmaras
  saem correndo quando você abre.
- Formigas andando por **trilhas** até os arbustos, em **ondas** cada vez
  maiores. Correr assusta as formigas.
- **Língua** que estica até onde você mira; **Faro** que mostra as formigas
  através do capim; **tremor** que deixa as formigas tontas.
- **Tanajura** voadora que dá o Frenesi.
- **5 habilidades com 28 níveis**: 1 formiga = 1 ponto, cada nível com seu
  preço, e redistribuição grátis.
- **Salva sozinho**; dá para continuar de onde parou.
- **Tela cheia e várias resoluções**, com opções gráficas separadas.

---

## 9. Histórico das decisões

| Data | Assunto | Antes (o que cada fonte dizia) | Decidido |
|---|---|---|---|
| 02/11/2026 | Visual | Plano: 2D ou 3D, decidir na M2 | 3D estilizado, tipo filme de animação |
| 02/11/2026 | Câmera | Plano: considerar câmera fixa | 1ª pessoa |
| 02/11/2026 | Como se come | Documento: ninhos com câmaras. Demo: trilhas e ondas | Os dois juntos |
| 02/11/2026 | Tamanho | Documento: 3 regiões. Plano: 2 | Só o Cerrado por enquanto |
| 02/11/2026 | Duração do Cerrado | Plano: 45 a 60 min. Demo: 6 a 10 min | 45 a 60 min, com 8 ninhos |
| 02/11/2026 | Plataforma | Documento: tocar e arrastar. Plano: Steam | PC (Steam) primeiro |
| 02/11/2026 | Desafio extra | Documento: só a rainha. Demo: soldados e tanajura | Rainha nos ninhos grandes + tanajura; sem soldados |
| 02/11/2026 | Habilidades | Documento: 8. Plano: 5. Demo: 3 ramos | As 5 do plano |
| 02/11/2026 | Como evoluir | Protótipo: marcos automáticos. Demo: pontos | Pontos para escolher |
| 02/11/2026 | Ninhos do Cerrado | Documento: cupinzeiros-torre. Demo: formigueiros | Só formigueiros (cupinzeiros só como cenário) |
| 02/11/2026 | Quantidade de insetos | Documento: ~800 a 1.200 no jogo todo. Demo: 1000 numa fase | 1000 por enquanto |
| 02/11/2026 | Preço | Plano: pesquisar quanto cobram os similares | Até R$ 20 |
| 02/11/2026 | Depois do Cerrado | Documento: Floresta (formigueiros de folha, ninhos em árvores) e Quintal | Outra floresta, com lagoas e cupinzeiros |
| 02/11/2026 | Inspirações | Documento: Leaf it Alone, Librarian e Supermarket Chaos | Principais: Leaf it Alone e Librarian |
| 02/11/2026 | Mapa | Documento: regiões separadas | Um mapa só, com várias regiões |
| 02/11/2026 | Escalada + Cauda | Sem uso no Cerrado (ninhos só no chão) | Só pode ser comprada ao chegar à floresta |
| 02/11/2026 | Lagoas da floresta | Poderiam trazer a Natação | Só cenário por enquanto |
| 02/11/2026 | Organização do repositório | Demo 3D num PR; protótipo e plano numa branch à parte | Tudo junto na `main`; as outras branches foram apagadas |
| 02/11/2026 | Altura da visão | Olhos a 50 cm do chão | 72 cm, e dá para subir nos formigueiros |
| 02/11/2026 | Lamber segurando | Liberado desde o começo | Habilidade inicial de 25 pontos (Lambida Contínua); antes dela, um clique por lambida |
| 02/11/2026 | Preço das habilidades | 1 ponto a cada 100 formigas; tudo custava 1 ponto | 1 formiga = 1 ponto; cada habilidade tem seu preço (25 a 200; Escalada 300 e 400) |
| 02/11/2026 | Garras e Faro | Uma linha de níveis cada | Duas linhas que não se excluem: Força e Rapidez (Garras), Alcance e Fôlego (Faro) |
| 02/11/2026 | Correr | Corrida bem mais rápida; dava para lamber correndo | +25%, e mais 25% com Patas Ligeiras; lamber correndo virou habilidade |
| 02/11/2026 | Quantidade de formigas | 1000 | 3200: dá para aprender tudo (2180 pontos) e ainda jogar com tudo liberado |
| 02/11/2026 | Formigueiros | 8, menores | 12 (4 novos no meio do mapa), cerca de 45% maiores |
| 02/11/2026 | Tela | Janela de 1600x900 e só "tela cheia: sim/não" | Janela, tela cheia ou exclusiva; várias resoluções; opções gráficas separadas |
| 02/11/2026 | Câmera ao correr | Quase parada | Leve balanço de galope (dá para desligar) |
| 02/11/2026 | Farejar | Liberado desde o começo | Habilidade inicial (20 pontos) |
| 02/11/2026 | Alcance do Faro | Em saltos (14, 30, 45 m e o mapa todo) | 4 passos graduais: 10 → 16 → 24 → 34 → 50 m e 10 → 25 → 50 → 100 → 200 formigas |
| 02/11/2026 | Precisão do Faro | As formigas sempre brilhavam | Sem precisão, só conta; Faro Preciso: nuvem borrada; Faro Nítido: formigas brilhando |
| 02/11/2026 | Fôlego do Faro | Linha própria (espera e duração) | Entrou nos níveis de Alcance: cada nível recarrega mais rápido; a linha virou Precisão |
| 02/11/2026 | Faro e câmaras | Só formigas | Faro de Câmara mostra as câmaras fechadas por perto |
| 02/11/2026 | Lambida | Pegava todas as formigas perto da ponta | Linha de Bocado: até 5, 15, 25 e 40 por lambida |
| 02/11/2026 | Cavar | Rapidez reduzia o tempo segurando E | Descanso de 25 s depois de cada câmara; a Rapidez reduz para 15 s e 5 s |
| 02/11/2026 | Tremor | Botão, recarga de 8 s | Pulo com pancada ao cair, recarga de 21 s (14 s e 7 s com as melhorias da Rapidez) |
| 02/11/2026 | Moradoras das câmaras | Ficavam dentro da câmara | Saem correndo ao abrir e fogem quando você chega perto; depois voltam |
| 02/11/2026 | Câmaras no campo | Só nos formigueiros | 12 câmaras no meio do campo, longe das trilhas |
| 02/11/2026 | Cor do faro | Dourada | Vermelha, com opção de ciano, magenta ou branco |
| 02/11/2026 | Aviso de onda | Grande, no meio da tela | Discreto, no painel da direita |
| 02/11/2026 | Pausa | As formigas continuavam andando | Pausa de verdade |
| 02/11/2026 | Habilidades ainda não feitas | Mostravam "na Floresta" | Só um cadeado |
| 02/11/2026 | Mapa do jogo completo | Um mapa com regiões: o Cerrado e depois outra floresta, com lagoas | Um mapa todo de cerrado, com 4 áreas cercadas por penhascos (esboço na seção 3) |
| 02/11/2026 | A demo | O Cerrado inteiro | A área 1, uma clareira; limpar 100% libera a área 2 |
| 02/11/2026 | Insetos por área | Formigas no Cerrado; cupinzeiros só como cenário | Área 1: formigas de chão; área 2: formigas que sobem em árvores; áreas 3 e 4: cupins |
| 02/11/2026 | Objetivo do jogo | Limpar cada região | Chegar ao cupinzeiro gigante (área 4), visível desde a área 1, e subir nele comendo cupins |
| 02/11/2026 | História | Não havia | O tamanduá acorda numa caverna, vê o cupinzeiro gigante e a barriga ronca |
| 02/11/2026 | Horário | O sol se punha conforme você comia | Sempre o mesmo fim de tarde |
| 02/11/2026 | Limite da clareira | Parede invisível | Penhascos de arenito, com árvores no platô |
| 02/11/2026 | Começo da demo | No meio da clareira | Numa caverna no pé do penhasco, de frente para o cupinzeiro gigante; a barriga ronca (o vídeo fica para depois) |
| 02/11/2026 | Cupinzeiro gigante | Não aparecia | Lá longe, por cima dos penhascos, sem brilho |
| 02/11/2026 | Passagem para a área 2 | Em aberto | Fechada por um tronco caído; com 100% limpo, as garras quebram o tronco e a demo termina |
| 02/11/2026 | Lagoas | Só na "outra floresta" | Uma ou duas na clareira, só de enfeite |
| 02/11/2026 | Barriga | Ideia: roncar mais forte na direção certa | Só ronca no começo; não aponta caminho |
