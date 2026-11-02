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

Um jogo **relaxante de "arrumar e limpar"**, na linha de *Leaf it Alone*,
*Librarian: Tidy Up the Arcane Library* e *Supermarket Chaos*. Você é um
**tamanduá-bandeira** que come **formigas e cupins** no **cerrado**, evolui
habilidades e deixa a região **100% limpa**. Aí o jogo acaba: não existe loop
infinito e não dá para perder.

**Para PC (Steam)**, em **3D estilizado** com cara de filme de animação, visto
**pelos olhos do tamanduá**.

---

## 2. O que já existe

| | O que é | Onde está | Situação |
|---|---|---|---|
| **Documento de design** | As regras e ideias do jogo inteiro | Seção 6 deste documento | Consolidado aqui |
| **Plano de produção** | Etapas de M1 a M5, riscos e cortes sugeridos | `docs/PLANO.md` na branch `m1-prototipo-do-loop` (resumo na seção 7) | Escrito |
| **Protótipo M1 (2D)** | Testa só a sensação de comer: 1 ninho com 6 câmaras, 259 insetos e a rainha. Gráfico simples de propósito | Branch `m1-prototipo-do-loop` (detalhes na seção 8) | Jogável |
| **Demo 3D** | Uma fase no cerrado ao entardecer, em 1ª pessoa, com 1000 formigas e árvore de habilidades | PR #1 (detalhes na seção 8) | Jogável (precisa de ajustes para seguir as decisões, seção 4) |

---

## 3. O jogo, como está decidido

### Plataforma, visual e câmera

- **PC primeiro, na Steam.** Mouse e teclado, e também controle. Celular pode
  vir depois.
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

- **Só o Cerrado por enquanto.** O cerrado é a savana brasileira (a "Savana" do
  documento original).
- O Cerrado é uma **região completa de 45 a 60 minutos**, com **8 ninhos**.
- A quantidade de insetos será **ajustada em testes** para chegar nesse tempo
  (a demo de hoje tem 1000 formigas e dura de 6 a 10 minutos).
- Floresta e Quintal urbano ficam para **depois de testar o Cerrado com
  jogadores**.

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
- **Sem insetos resistentes:** as formigas-soldado da demo saem.

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

**Fora por enquanto:** Camuflagem (repete o que a Língua já faz) e Natação. O
**Focinho** volta junto com o Quintal urbano.

---

## 4. O que muda na demo para seguir as decisões

1. **Ninhos com câmaras:** hoje cavar um formigueiro só solta formigas. Ele
   passa a ter câmaras para esvaziar, com a rainha nos ninhos grandes.
2. **Rainha:** entra como no documento (só nos ninhos grandes, vale 15 a 20).
3. **Soldados:** saem.
4. **Habilidades:** os 3 ramos de hoje (Língua, Garras, Corpo) viram as 5 do
   plano. A "Pelagem Silenciosa" sai, porque é a Camuflagem com outro nome.
5. **Duração:** a fase de 10 minutos vira uma região de 45 a 60 minutos com 8
   ninhos. A quantidade de formigas e o ritmo de 1 ponto a cada 100 serão
   ajustados nos testes.
6. **Salvar o progresso:** com 45 a 60 minutos, o jogo precisa salvar. A demo
   ainda não salva.

Plataforma (PC), visual, câmera e tanajura já estão como foi decidido.

---

## 5. Ainda em aberto

- **Ninhos do Cerrado:** o documento original fala em cupinzeiros-torre; a demo
  usa formigueiros (e os cupinzeiros são só cenário). Podem ser os dois?
- **Quantos insetos** no Cerrado: será definido nos testes, para durar 45 a 60
  minutos.
- **Preço:** o plano sugere pesquisar quanto cobram os jogos parecidos.
- **Depois do Cerrado:** Floresta e Quintal urbano, e em que ordem.

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

**Onde estamos:** a demo 3D já cobre boa parte da M2 (visual final, câmera de
verdade, andar entre ninhos, upgrades). Faltam as câmaras dentro dos ninhos, a
rainha e salvar o progresso (seção 4).

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
- **1000 formigas** saem de 5 formigueiros, andam por trilhas até os arbustos e
  chegam em **ondas** cada vez maiores. Correr assusta as formigas.
- **Língua** que estica até onde você mira; **Faro** que mostra as formigas
  através do capim; **cavar formigueiros**; **tremor** que deixa as formigas tontas.
- **Formigas-soldado** (vão sair) e **tanajura** (fica).
- **Árvore de habilidades:** 1 ponto a cada 100 formigas, 3 ramos (Língua,
  Garras, Corpo) com 4 níveis cada (vai virar as 5 habilidades decididas).
- Uma partida dura de 6 a 10 minutos.

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
