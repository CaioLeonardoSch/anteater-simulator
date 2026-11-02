# Tamanduá — do papel ao jogo

Você tem um documento de design bom e zero código. O risco nesse ponto não é
falta de ideia: é passar mais seis meses melhorando o documento. Este plano
existe pra empurrar tudo pro lado de lá.

---

## 1. A única pergunta que importa agora

**Comer um inseto é gostoso o bastante pra sustentar 3–5 horas?**

Tudo no seu documento — 3 regiões, 27 ninhos, 8 habilidades — é multiplicação
em cima desse único ato. Se o ato base for morno, 27 ninhos de conteúdo morno
não salvam; só alongam. Se ele for ótimo, o resto é execução.

O protótipo em `tamandua-prototipo/` responde só isso. Ele é feio de propósito:
gráfico é círculo desenhado em código, som é seno sintetizado. Se você se pegar
limpando a última câmara sem perceber o tempo passar, o jogo tem pé. Se você
fechar antes do fim, melhor descobrir agora do que depois de modelar 27 ninhos.

**Jogue até o fim uma vez. Depois dê pra 3 pessoas jogarem e fique calado
olhando.** Onde elas param de sorrir é onde está o problema.

---

## 2. O que medir

A tela final cospe **insetos/min** e **tempo total** do ninho de 265 insetos.

| Resultado | O que significa |
|---|---|
| 3–6 min | O número de insetos do documento está calibrado. Siga. |
| > 8 min | Ninho grande demais ou lambida lenta. Corte insetos antes de cortar ninhos. |
| < 2 min | Cabe mais conteúdo por ninho — ou o mapa pode ter menos ninhos. |

Anote também: **em que momento a lambida destravou** e se aquilo foi um alívio.
Esse é o teste da sua melhor ideia de design — progressão que vira gesto novo,
não número subindo. Se destravar a lambida não deu vontade de rir, o resto da
árvore de habilidades precisa ser repensado.

---

## 3. Os três riscos reais do documento

**Repetição disfarçada de conteúdo.** Savana, floresta e quintal, do jeito que
estão descritos, mudam a *arquitetura do ninho* — mas o verbo continua o mesmo:
tocar/lamber inseto. Só duas habilidades mudam o verbo de verdade: **Escalada +
Cauda** (movimento vira quebra-cabeça) e **Focinho** (sondar em vez de lamber).
Essas duas são as mais caras de fazer e as mais importantes. Priorize as duas
acima de Patas, Camuflagem e Natação.

**Camuflagem é redundante.** Ela e a Língua entregam a mesma coisa — eficiência.
Duas rotas pro mesmo destino não é escolha, é ruído na árvore. Cortaria.

**A caça aos últimos 5%.** É onde jogos desse gênero morrem: 95% de fluxo
gostoso e 5% de vasculhar cantinho atrás de uma folha. Seu Faro nível 3 já
resolve isso — mas cuidado com o oposto: se o Faro apontar cedo demais, você
apaga a busca inteira e o jogo vira só arrastar o dedo. No protótipo o Faro tem
cooldown de 4s por isso. Teste os dois extremos.

---

## 4. Escopo: o corte que eu faria

| Documento | Recomendação |
|---|---|
| 3 regiões, ~27 ninhos | **2 regiões, ~16 ninhos** na v1. Savana + Floresta. |
| Quintal urbano | Vira DLC/atualização gratuita pós-lançamento. |
| Natação / 4ª região | Fora. Já estava marcado como futuro — mantenha fora. |
| Camuflagem | Cortada. |
| 8 habilidades | 5: Língua, Garras, Patas, Escalada+Cauda, Faro. |

Você é solo, em Godot, sem código escrito. 16 ninhos bem-feitos com dois verbos
distintos batem 27 ninhos genéricos, e é a diferença entre lançar e não lançar.
Dá pra crescer depois — nunca dá pra encolher depois de anunciar.

---

## 5. Ordem de construção

**M1 — Sensação (você está aqui).** O protótipo. Só valide o toque.
Critério de saída: você e mais 2 pessoas quiseram terminar o ninho.

**M2 — Fatia vertical.** Um ninho no estilo visual final, câmera de verdade,
tamanduá que anda entre dois ninhos, um upgrade comprável, save. Sem menu, sem
título, sem tutorial. É o menor pedaço que já *parece* o jogo.
Critério de saída: um GIF de 15 segundos que dá vontade de jogar.

**M3 — Uma região inteira.** Savana completa, 8 ninhos, árvore de habilidades
funcionando, curva de progressão fechada.
Critério de saída: 45–60 min de jogo sem bug de progressão.

**M4 — Página na Steam + demo.** Antes de fazer a região 2. Uma demo da Savana
mede interesse com dinheiro real na mesa (wishlists) enquanto ainda dá tempo de
mudar de rumo. Jogo desse gênero vive de "isso parece relaxante" no vídeo — e
isso você já consegue provar no M3.

**M5 — Região 2 + polimento + lançamento.**

Reordenar M4 pra depois de tudo pronto é o erro clássico: você descobre se
alguém quer o jogo no dia em que já não pode mais mudar nada.

---

## 6. Decisões que o documento ainda deixa em aberto

1. **Ordem de desbloqueio das regiões.** Proposta: Savana (início) → Floresta
   (Garras + Escalada) → Quintal (Focinho). Cada região pede a habilidade cara
   que ela vai usar como verbo principal.
2. **2D ou 3D.** O protótipo é 2D porque a pergunta do M1 não depende disso.
   Decida no M2, e considere 3D de câmera fixa/isométrica: você tem Blender,
   mas câmera livre triplica o custo de level design.
3. **Preço e plataforma.** 3–5h finitas, sem loop infinito, vende num patamar
   baixo. Isso é decisão de escopo, não de marketing — define quanto você pode
   gastar em arte. Vale pesquisar quanto os similares cobram antes do M2.
4. **Rainha por ninho ou só nos grandes?** Uma em cada um dos 27 dilui. Se ela é
   momento, precisa ser rara.

---

## 7. Se você fizer só uma coisa esta semana

Abrir o protótipo, jogar até o fim, e anotar em uma linha o que você sentiu
quando comeu a rainha. Essa linha decide o resto do projeto.
