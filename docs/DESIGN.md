# Anteater Simulator: documento do jogo (consolidado)

Este documento junta, em um lugar só, tudo o que já foi definido sobre o jogo:

- o **documento de design** original (antes no README da `main`);
- o **plano de produção** (`docs/PLANO.md`, na branch `m1-prototipo-do-loop`);
- o **protótipo 2D do loop** (mesma branch, pasta `prototipos/m1-loop/`);
- a **demo 3D** (PR #1) e as escolhas feitas na conversa em que ela foi criada;
- as **decisões de 02/11/2026**, tomadas para resolver o que não batia.

Quando algo aqui contradiz uma fonte antiga, **vale este documento**.

---

## 1. O jogo em poucas palavras

Um jogo **relaxante de "arrumar e limpar"**. Você é um **tamanduá-bandeira**
que come **formigas e cupins** no **cerrado**, evolui habilidades e deixa a
região **100% limpa**. Aí o jogo acaba: não existe loop infinito e não dá para
perder.

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
| **Plano de produção** | Etapas de M1 a M5, riscos e cortes sugeridos | `docs/PLANO.md` na branch `m1-prototipo-do-loop` (resumo na seção 7) | Escrito |
| **Protótipo M1 (2D)** | Testa só a sensação de comer: 1 ninho com 6 câmaras, 259 insetos e a rainha. Gráfico simples de propósito | Branch `m1-prototipo-do-loop` (detalhes na seção 8) | Jogável |
| **Demo 3D** | O Cerrado ao entardecer, em 1ª pessoa: 1000 formigas, 8 formigueiros com câmaras e rainhas, 5 habilidades e jogo salvo | PR #1 (detalhes na seção 8) | Jogável, já seguindo as decisões (seção 4) |

---

## 3. O jogo, como está decidido

### Plataforma, preço, visual e câmera

- **PC primeiro, na Steam.** Mouse e teclado, e também controle. Celular pode
  vir depois.
- **Preço:** no máximo **R$ 20**.
- **3D estilizado**, com cara de filme de animação. Nada de pixel art, nada de
  low poly.
- **1ª pessoa:** você vê o mundo pelos olhos do tamanduá, com o focinho na parte
  de baixo da tela. *Atenção (do plano): câmera livre deixa a criação das fases
  mais cara do que câmera fixa.*
- **Modelos 3D gerados por IA**, todos no mesmo estilo. Os prompts estão em
  [`prompts-ia.md`](prompts-ia.md). O formigueiro já foi gerado na Artlist e
  falta baixar (precisa de um plano com créditos).
- **Motor:** Godot 4.7.

### Tamanho

- **Um mapa só, com várias regiões.** Você anda de uma região para a outra sem
  telas de carregamento. Por enquanto, só o Cerrado está pronto.
- O cerrado é a savana brasileira (a "Savana" do documento original).
- O Cerrado é uma **região completa de 45 a 60 minutos**, com **8 ninhos**.
- **Os ninhos do Cerrado são só formigueiros.** Os cupinzeiros aparecem apenas
  como cenário.
- **1000 formigas por enquanto.** Na demo de hoje, elas acabam em 6 a 10
  minutos. Para chegar aos 45 a 60 minutos, o tempo a mais deve vir de cavar e
  esvaziar os ninhos, achar as últimas formigas com o Faro e explorar, e não de
  colocar mais formigas. Se não bastar, o número muda nos testes.
- **Depois do Cerrado:** **outra floresta, com lagoas, cupinzeiros e mais**.
  As lagoas são só cenário por enquanto (nada de nadar). O Quintal urbano fica
  para mais tarde.

### Como se come: os dois jeitos juntos

- **Trilhas:** formigas andam pelo mapa entre os ninhos e os arbustos, e chegam
  em ondas. Você lambe as que estão de passagem.
- **Ninhos com câmaras:** cada ninho tem câmaras internas. Você cava com as
  Garras e esvazia uma por uma, com a satisfação de terminar de arrumar uma
  prateleira.
- A **língua** começa comendo um inseto por vez e evolui até a **lambida**, que
  pega vários.
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

Cada habilidade tem **níveis**, comprados com **pontos** que você ganha comendo
(na demo, 1 ponto a cada 100 formigas). Você escolhe onde gastar, e os gestos
novos (lambida, cavar, escalar) também são comprados assim.

| Habilidade | Para que serve | Ideias de níveis (vindas da demo e do documento) |
|---|---|---|
| **Língua** | Comer | Mais comprida, mais grudenta, **lambida**, lamber mais rápido, varrer o caminho todo |
| **Garras** | Abrir ninhos e caminhos bloqueados | **Cavar ninhos**, cavar mais rápido, bater no chão para deixar os insetos tontos |
| **Patas** | Andar | Andar mais rápido, **correr**, galopar sem assustar os insetos |
| **Faro** | Achar insetos e ninhos | Nível 1: "sobrou algo perto"; nível 2: "está nesta área"; nível 3: "está exatamente aqui", e acha a rainha |
| **Escalada + Cauda** | Alcançar o que está no alto | Subir em cupinzeiros altos e árvores; pendurar-se pela cauda para alcançar ninhos difíceis |

**Habilidades por região:** a **Escalada + Cauda** aparece na árvore desde o
começo, mas só pode ser comprada **quando você chegar à floresta**, onde ela é
usada.

**Fora por enquanto:** Camuflagem (repete o que a Língua já faz) e Natação. O
**Focinho** volta junto com o Quintal urbano.

---

## 4. A demo hoje (atualizada em 02/11/2026)

Feito, seguindo as decisões:

1. **8 formigueiros**, 3 deles grandes. Cada um tem **câmaras fechadas**
   (montinhos de terra clara). Segurando **E** com a habilidade Cavar, a câmara
   abre e as moradoras aparecem dentro do buraco.
2. **Rainha** na câmara do topo dos 3 formigueiros grandes. Brilha de leve, fica
   protegida enquanto houver formigas na câmara e **vale 20**.
3. **As 1000 formigas** são divididas assim: cerca de 45% andam pelas trilhas
   (e voltam para casa), o resto mora nas câmaras. 940 operárias + 3 rainhas × 20.
4. **Soldados:** saíram. A **tanajura** continua.
5. **As 5 habilidades**, compradas com pontos (1 a cada 100). No começo a língua
   pega **uma formiga por vez**; a **Lambida** passa a pegar várias (o "gesto
   novo" do documento). Correr também é uma habilidade (Patas). A **Escalada +
   Cauda** aparece travada até a floresta. Dá para **redistribuir os pontos**.
6. **Progresso visível:** contador de formigueiros limpos, avisos de câmara
   limpa, e florzinhas brotam no formigueiro quando ele fica limpo. O Faro nível
   2 mostra na bússola quanto falta em cada formigueiro; o nível 3 marca as
   rainhas.
7. **Jogo salvo:** salva sozinho a cada 30 s, ao pausar e ao sair. A tela
   inicial ganha **Continuar** e **Novo jogo**.

Ainda a ajustar:

- **Duração:** num teste automático (um robô que mira perfeito), as 1000
  formigas acabaram em cerca de 6 minutos. Uma pessoa deve levar bem mais, mas
  é provável que ainda fique abaixo dos 45 a 60 minutos. É o próximo ponto a
  medir com jogadores.

---

## 5. Ainda em aberto

- **A floresta:** os cupinzeiros de lá são ninhos, com rainha? Os formigueiros
  de folha e os ninhos em árvores do documento original continuam?
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

O plano completo está em `docs/PLANO.md`, na branch `m1-prototipo-do-loop`.

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
| **M3: Uma região inteira** | Cerrado completo: 8 ninhos e árvore de habilidades | 45 a 60 min de jogo sem problemas de progressão |
| **M4: Página na Steam + demo** | Medir interesse (lista de desejos) antes da próxima região | Página no ar com demo |
| **M5: Próxima região + lançamento** | Polimento e lançamento | Jogo lançado |

**Onde estamos:** a demo 3D já cobre a M2 (visual final, câmera de verdade,
andar entre ninhos, habilidades e jogo salvo) e boa parte da M3 (o Cerrado com 8
formigueiros e a árvore de habilidades). Falta acertar a duração com testes.

---

## 8. As versões jogáveis

### Protótipo M1 (2D), branch `m1-prototipo-do-loop`

- **Clique:** come 1 inseto. **Segurar e arrastar:** lambida. **F:** Faro.
  **R:** recomeça.
- **Ninho:** 6 câmaras com 259 insetos. A câmara do topo é a mais cheia e guarda
  a rainha, atrás de um bloqueio de terra que as Garras quebram.
- **Evolução automática** pelo total comido: Faro I (25), Lambida (50),
  Faro II (100), Garras (150), Faro III (175), Língua III (185).
- No fim, mostra **insetos por minuto** e o **tempo total**.

### Demo 3D, PR #1

- **1ª pessoa** no cerrado ao entardecer; o sol vai se pondo enquanto você come.
- **8 formigueiros** (3 com rainha) e **25 câmaras** para abrir e esvaziar.
- Formigas andando por **trilhas** até os arbustos, em **ondas** cada vez
  maiores. Correr assusta as formigas.
- **Língua** que estica até onde você mira; **Faro** que mostra as formigas
  através do capim; **tremor** que deixa as formigas tontas.
- **Tanajura** voadora que dá o Frenesi.
- **5 habilidades** com pontos (1 a cada 100) e redistribuição grátis.
- **Salva sozinho**; dá para continuar de onde parou.

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
