# Estatísticas dos testes

A versão de teste manda as estatísticas de cada partida para um **Formulário do
Google**, e as respostas caem numa **planilha**. Não precisa de servidor nem de
pagar nada.

## O que o jogo manda

Cada envio é uma resposta do formulário, com 10 campos:

| Campo | O que vai |
|---|---|
| jogador | Um número aleatório, o mesmo em todas as partidas daquele computador |
| apelido | O apelido que a pessoa escreveu (se quiser) |
| partida | O número da partida e da sessão (cada vez que o jogo foi aberto) |
| versao | A versão do jogo (com "(editor)" quando é o Caio jogando pelo Godot) |
| evento | Por que mandou: "a cada 10 min", "voltou ao menu", "fechou o jogo", "clareira limpa", "recomeçou do zero" |
| minutos | Tempo de jogo da partida |
| insetos | Insetos comidos |
| computador | Placa de vídeo, processador, memória, sistema, tela, qualidade gráfica e o FPS médio (e o pior, e quanto tempo ficou abaixo de 30) |
| estatisticas | Os números da tela de Estatísticas: habilidades, pontos, formigueiros, câmaras, rainhas, linguadas e acerto, faro, tremores, distância, tempo correndo, parciais |
| registro | A linha do tempo: cada compra (com o preço), cada marco, cada objetivo cumprido, cada formigueiro limpo, quando redistribuiu os pontos, e o progresso a cada 2 minutos |

**Quando manda:** a cada 10 minutos de jogo, ao voltar para o menu, ao fechar o
jogo, ao recomeçar do zero e quando a clareira fica limpa. Cada envio leva tudo
desde que o jogo foi aberto, então, na planilha, **a linha mais nova de cada
partida é a mais completa**. Se alguém desiste no meio, a última linha mostra
onde parou.

**Não vai:** nome, e-mail, nem nenhum arquivo do computador. Na primeira vez que
abre, o jogo explica isso e pergunta se pode mandar; dá para mudar depois em
Configurações › Jogo (e trocar o apelido lá também).

**Cópia no computador:** cada envio também fica salvo em
`%APPDATA%\Godot\app_userdata\Anteater Simulator\registros` (Windows). Se a
internet falhar, o amigo pode mandar esses arquivos.

## Como criar o formulário (passo a passo)

1. Entre em [forms.google.com](https://forms.google.com) com a sua conta do
   Google e clique em **Formulário em branco** (o quadro com o "+").
2. Troque o título "Formulário sem título" por **Anteater Simulator,
   estatísticas dos testes**.
3. Crie **10 perguntas, nesta ordem**, com estes nomes **exatamente assim**
   (sem acento e em minúsculas). Para cada uma: clique no **+** da barrinha à
   direita, escreva o nome no lugar de "Pergunta" e escolha o tipo no menu ao
   lado (que começa como "Múltipla escolha"). Deixe **"Obrigatória" desligado**
   em todas.

   | Nº | Nome da pergunta | Tipo |
   |---|---|---|
   | 1 | jogador | Resposta curta |
   | 2 | apelido | Resposta curta |
   | 3 | partida | Resposta curta |
   | 4 | versao | Resposta curta |
   | 5 | evento | Resposta curta |
   | 6 | minutos | Resposta curta |
   | 7 | insetos | Resposta curta |
   | 8 | computador | Parágrafo |
   | 9 | estatisticas | Parágrafo |
   | 10 | registro | Parágrafo |

   A primeira pergunta já vem criada; é só mudar o nome e o tipo dela.
4. Na aba **Configurações** (no topo), abra **Respostas** e confira:
   - **Coletar endereços de e-mail:** "Não coletar".
   - **Limitar a 1 resposta:** desligado (se ficar ligado, o jogo não
     consegue mandar, porque pediria login).
5. Se aparecer o botão **Publicar** no topo, clique nele e deixe quem pode
   responder como **"Qualquer pessoa com o link"**. Sem publicar, o formulário
   não aceita respostas.
6. **Pegue o link pré-preenchido** (é dele que eu tiro o "endereço" de cada
   pergunta):
   - Clique nos **três pontinhos** (⋮), no canto de cima à direita, e
     escolha **"Gerar link pré-preenchido"** (pode aparecer como "Obter link
     preenchido automaticamente").
   - Na página que abre, **escreva em cada pergunta o próprio nome dela**:
     em "jogador" escreva `jogador`, em "apelido" escreva `apelido`, e assim
     até "registro".
   - Clique em **Gerar link** (ou "Receber link") e depois em **Copiar
     link**.
   - Me mande esse link. Ele começa com
     `https://docs.google.com/forms/d/e/...`.
7. **Ligue à planilha:** na aba **Respostas**, clique em **Vincular ao
   Planilhas** (o ícone verde) e em **Criar**. Cada envio do jogo vira uma
   linha nessa planilha.

Com o link, o endereço do formulário e das perguntas vão para
`scripts/autoload/telemetry.gd` (`FORM_URL` e `ENTRIES`). O número de cada
pergunta também aparece no código da página do formulário (em
`FB_PUBLIC_LOAD_DATA_`, o segundo número de cada pergunta).

**Já configurado (06/11/2026):** o formulário "Estatísticas dos testes" do
Caio, com as 10 perguntas acima. Se o formulário for trocado ou as perguntas
recriadas, os números mudam e precisam ser atualizados.

## Para testar sem o formulário

`--telemetria=http://127.0.0.1:8765/` manda para outro endereço (por exemplo, um
receptor local de teste), mesmo nos testes com outros argumentos e sem tela.
Só `--telemetria` (sem endereço) manda para o formulário de verdade e mostra
no console se o Google aceitou ("resposta 200"). Sem `--telemetria`, os testes
(qualquer argumento depois de "--") não mandam nada.
