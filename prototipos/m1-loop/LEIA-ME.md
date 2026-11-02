# Protótipo M1 — sensação do loop

Protótipo descartável que existe pra responder **uma** pergunta:
*comer um inseto é gostoso o bastante pra sustentar 3–5 horas?*

Tudo é arte de programador de propósito. Gráficos são desenhados em código,
o som é sintetizado em runtime. Não tem asset externo nenhum.

## Como rodar

1. Godot 4.2 ou mais novo
2. **Importar** → aponte pra esta pasta (a que tem o `project.godot`)
3. **F5**

## Controles

| Ação | Como |
|---|---|
| Bicada | Clique (come 1 inseto por clique) |
| Lambida | Segure e arraste — destrava aos 50 insetos |
| Faro | Botão no canto ou tecla `F` |
| Reiniciar | `R` |

## O ninho

6 câmaras, 259 insetos e a rainha. A câmara do topo é o **ponto mais cheio do
ninho** — 68 insetos num raio de 58, mais do que o triplo da densidade da base —
e é onde a rainha fica, coberta por eles, exatamente como no documento. Só dá
pra comer ela depois que a câmara está limpa.

O caminho até o topo tem um **bloqueio de terra** que as Garras quebram.

## Marcos de progressão

Por total de insetos comidos. Não tem economia de pontos: não é isso que está
sendo testado aqui.

| Insetos | Destrava |
|---|---|
| 25 | **Faro I** — avisa que sobrou algo perto, raio curto, sem direção |
| 50 | **Lambida** + alcance da língua |
| 100 | **Faro II** — aponta qual câmara ainda tem inseto |
| 150 | **Garras** — quebra o bloqueio no caminho do topo |
| 175 | **Faro III** — marca o inseto exato, à distância |
| 185 | **Língua III** — alcance total + velocidade |

Os três níveis do Faro seguem a escada do documento. O nível I de propósito
**não** dá direção: ele preserva a busca em vez de apagá-la. Vale testar se isso
é tensão gostosa ou só irritação.

## O número que importa

Na tela final: **insetos/min** e tempo total.

| Resultado | Leitura |
|---|---|
| 3–6 min | O número de insetos do documento está calibrado. |
| > 8 min | Ninho grande demais ou lambida lenta. Corte insetos antes de ninhos. |
| < 2 min | Cabe mais por ninho, ou o mapa pode ter menos ninhos. |

Anote também **em que momento a lambida destravou** e se aquilo foi um alívio.
É o teste da melhor ideia do documento: progressão que vira gesto novo, não
número subindo.
