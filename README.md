# Anteater Simulator

Jogo relaxante de tarefas, no estilo de *Leaf it Alone*, *Librarian: Tidy Up the Arcane Library* e *Supermarket Chaos*. Você controla um tamanduá que se alimenta de cupins e formigas, evoluindo habilidades e desbloqueando regiões até limpar o mapa por completo.

## Escopo

- **Tempo alvo:** 3–5h ou menos para o 100%, por um jogador comum
- **Sem loop infinito:** mapa 100% limpo = fim do jogo, como em *Leaf it Alone*
- **3 regiões:** Savana, Floresta e Quintal urbano
- **8–10 ninhos por região** (~27 no total)
- **3–6 min por ninho** (~90–160 min de "comer" puro, com espaço para deslocamento e habilidades dentro do teto de 3–5h)
- **~800–1.200 insetos** ao todo, crescendo por ninho conforme a região avança

## Loop principal

1. Toque em um inseto: ele é comido e some, com feedback visual/sonoro rápido.
2. A língua evoluída desbloqueia a **lambida**: arrastar o dedo pelo ninho come vários insetos de uma vez. A progressão vira gesto novo, não só número subindo.
3. Cada ninho tem **câmaras internas**; esvaziar cada uma dá a mesma satisfação de terminar de organizar uma prateleira.

## Regiões

| Região | Arquitetura do ninho |
|---|---|
| Savana | Cupinzeiros-torre |
| Floresta | Formigueiros de folha + ninhos em árvore |
| Quintal urbano | Fendas de cimento |

> O desbloqueio de cada região por Faro ou Garras (ordem exata e critério) ainda está em aberto.

## Árvore de habilidades

| Habilidade | Efeito |
|---|---|
| **Língua** | Come mais rápido; mais comprida e grudenta; desbloqueia a lambida |
| **Patas** | Anda mais rápido; desbloqueia corrida |
| **Garras** | Abre ninhos maiores/mais resistentes e bloqueios no caminho; chave para novas regiões |
| **Escalada + Cauda preênsil** | Sobe em árvores; a cauda permite pendurar e balançar entre galhos para alcançar ninhos embaixo de um galho ou do outro lado de um vão |
| **Focinho** | Sonda fendas estreitas que a garra não abre; essencial para o quintal urbano |
| **Camuflagem** | Insetos reagem menos à presença (ficam mais estáticos); rota alternativa à língua para ganhar eficiência |
| **Faro** | Três usos que evoluem juntos (veja abaixo) |
| **Natação** *(opcional / futuro)* | Nadar; chave natural para uma eventual 4ª região, como brejo ou beira de rio |

### Faro em detalhe

Aumenta em precisão e alcance conforme evolui:

- Revela ninhos escondidos, incluindo entradas de novas regiões
- Revela a "qualidade" de um ninho antes de você ir até lá (vale a pena ou não)
- Detecta insetos esquecidos, em 3 níveis:
  - **Nível 1:** avisa que sobrou algo perto (raio curto, sem direção)
  - **Nível 2:** aponta a área dentro do ninho
  - **Nível 3:** marca o inseto exato, funciona à distância e avisa até em ninhos que pareciam "prontos"

## Rainha

- Aparece no ponto mais cheio do ninho, coberta por outros insetos; só dá para comer depois de limpar tudo ao redor
- Vale **15–20x** um inseto comum
- Efeito visual/sonoro próprio ao comer, para marcar o momento
- Faro nível 3 (o mesmo que acha insetos esquecidos) ajuda a localizar a rainha

## Descartado por enquanto

- **Ninhos retomados/dominados** por vizinhos: ia contra o escopo curto e finito definido
- **Insetos mais fortes/resistentes:** a rainha já cobre a necessidade de desafio extra, sem precisar de sistema de dano
