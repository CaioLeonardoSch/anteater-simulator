# Modelos 3D gerados por IA

Coloque aqui os arquivos `.glb` gerados com os prompts de
[`docs/prompts-ia.md`](../../docs/prompts-ia.md). Ao abrir o projeto, o Godot
importa cada arquivo e o jogo passa a usá-lo no lugar da versão feita por código.

| Arquivo | Substitui | Tamanho no jogo |
|---|---|---|
| `formigueiro.glb` | monte de terra dos formigueiros | 3,8 m de largura |
| `formiga_operaria.glb` | saúva operária | 15 cm de comprimento |
| `formiga_soldado.glb` | saúva soldado | 20 cm |
| `formiga_tanajura.glb` | tanajura | 22 cm |
| `tamandua_focinho.glb` | focinho em 1ª pessoa | 62 cm, ponta na boca |
| `tamandua.glb` | tamanduá no menu inicial | 2,2 m |
| `cupinzeiro.glb` | cupinzeiros | 0,9 a 2,4 m de altura |
| `arvore_cerrado.glb` | árvores retorcidas | 4,5 a 6,5 m de altura |
| `ipe_amarelo.glb` | ipês-amarelos | 6,5 a 8,5 m de altura |
| `ipe_roxo.glb` | ipê-roxo | 6,5 a 8,5 m de altura |
| `pedra.glb` | pedras | 0,7 a 3 m de largura |
| `arbusto.glb` | arbustos | 0,8 a 1,6 m de altura |
| `tronco_caido.glb` | troncos caídos | 3,6 m de comprimento |

Os tamanhos são aplicados automaticamente: não importa a escala em que o modelo
veio do gerador. O modelo também é centralizado e apoiado no chão.

## Ajustes finos (`ajustes.cfg`)

Se um modelo aparecer virado, grande ou pequeno demais, ou afundado, crie o
arquivo `assets/models/ajustes.cfg` com uma seção por modelo:

```ini
; A formiga anda de costas? Gire 180 graus. E deixe 10% maior.
[formiga_operaria]
rotacao_y=180.0
escala=1.1

; Afunda o formigueiro 8 cm no chão.
[formigueiro]
deslocamento=Vector3(0, -0.08, 0)
```

> Ao exportar o jogo, inclua `*.cfg` em *Filtros para exportar arquivos que não
> são recursos* (aba **Recursos** da predefinição de exportação), senão o
> `ajustes.cfg` fica de fora.

## Dicas

- As formigas aparecem às centenas: mantenha cada uma com até ~4 mil triângulos.
- As pernas das formigas são animadas automaticamente pela posição dos
  vértices. Para funcionar, o modelo precisa estar olhando para a frente (-Z),
  com as pernas abertas e separadas do corpo.
- Para voltar à versão feita por código, é só apagar ou renomear o `.glb`.
