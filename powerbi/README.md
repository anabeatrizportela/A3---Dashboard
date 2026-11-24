# Camada Power BI

O que fica aqui: as medidas DAX e o tema visual. O arquivo `.pbix` em si não entra no repositório — é binário, não dá diff e dois integrantes editando o mesmo `.pbix` geram conflito que o git não resolve. O que o repositório versiona é o que **gera** o `.pbix`: o modelo (em `sql/`), as medidas e o tema.

```
powerbi/
├── dax/
│   ├── 00_base.dax         medida base e regras de negócio do somatório
│   ├── 10_kpis.dax          um indicador por medida
│   ├── 20_tempo.dax         variação mês a mês
│   ├── 30_territorio.dax    somas por município/região sem duplicar
│   └── 40_taxas.dax         taxas por 100 mil habitantes
└── tema/
    └── tema-a3-criminalidade-rj.json
```

## Antes de começar

Rodar os passos 1 a 7 de [`sql/RUNBOOK.md`](../sql/RUNBOOK.md) e conferir que o QA passou. As medidas deste diretório **dependem** das colunas que as migrações criam: sem `TIOC_FL_AGREGADO`, `CIMU_FL_SEDE` e `PERI_DT_REFERENCIA`, metade delas nem valida.

## 1. Conectar

`Obter dados` → `Banco de dados MySQL` → servidor `localhost:3306`, banco `seg_dashboard`. Importar as 11 tabelas (`Importar`, não DirectQuery — a base é fechada em 2025 e não muda).

> **Maiúsculas e minúsculas.** No XAMPP para Windows o MySQL guarda os nomes de tabela em minúsculas, então o Power BI importa `seg_ocorrencia_mensal`. No Linux e no macOS os nomes vêm como foram criados: `SEG_OCORRENCIA_MENSAL`. As medidas em `dax/` usam **minúsculas**. Se as suas tabelas vierem em maiúsculas, renomeie no Power Query — é mais barato do que ajustar 50 medidas, e deixa o modelo igual para todo o grupo.

## 2. Relacionamentos

| De (1) | Para (muitos) | Filtro cruzado |
| --- | --- | --- |
| `seg_risp[RISP_ID_RISP]` | `seg_aisp[RISP_ID_RISP]` | Simples |
| `seg_aisp[AISP_ID_AISP]` | `seg_registro_mensal[AISP_ID_AISP]` | Simples |
| `seg_cisp[CISP_ID_CISP]` | `seg_registro_mensal[CISP_ID_CISP]` | Simples |
| `seg_periodo[PERI_ID_PERIODO]` | `seg_registro_mensal[PERI_ID_PERIODO]` | Simples |
| `seg_registro_mensal[REME_ID_REGISTRO_MENSAL]` | `seg_ocorrencia_mensal[REME_ID_REGISTRO_MENSAL]` | Simples |
| `seg_tipo_ocorrencia[TIOC_ID_TIPO_OCORRENCIA]` | `seg_ocorrencia_mensal[TIOC_ID_TIPO_OCORRENCIA]` | Simples |
| `seg_categoria_ocorrencia[CAOC_ID_CATEGORIA_OCORRENCIA]` | `seg_tipo_ocorrencia[CAOC_ID_CATEGORIA_OCORRENCIA]` | Simples |
| `seg_regiao[REGI_ID_REGIAO]` | `seg_municipio[REGI_ID_REGIAO]` | Simples |
| `seg_municipio[MUNI_ID_MUNICIPIO]` | `seg_cisp_municipio[MUNI_ID_MUNICIPIO]` | Simples |
| **`seg_cisp[CISP_ID_CISP]`** | **`seg_cisp_municipio[CISP_ID_CISP]`** | **Ambas** |

A última linha é a única bidirecional, e é obrigatória: sem ela o filtro de município não chega ao fato (precisa andar município → ponte → delegacia → registro → ocorrência). É também o que faz a duplicação da armadilha 3 — por isso toda soma por município ou região usa as medidas `(por sede)` de `30_territorio.dax`.

## 3. Dimensão de tempo

Selecionar `seg_periodo` → `Ferramentas de tabela` → **Marcar como tabela de data** → coluna `PERI_DT_REFERENCIA`.

Depois, em `seg_periodo[PERI_NM_MES]` → `Classificar por coluna` → `PERI_NR_MES`, senão os meses aparecem em ordem alfabética (abr, ago, dez…).

Sem esses dois passos, `PREVIOUSMONTH` dá erro e `20_tempo.dax` não funciona.

## 4. Medidas

Criar as medidas **na ordem dos arquivos** (`00_` → `40_`): cada camada só usa medidas das anteriores, então fora de ordem o Power BI reclama de referência inexistente.

Para cada medida: `Modelagem` → `Nova medida`, colar o bloco (só o corpo, sem os comentários `//` do cabeçalho do arquivo — comentário em DAX é permitido, mas o painel fica mais limpo sem).

Depois de criar:

1. **Ocultar `[_Ocorrências brutas]`.** Ela ignora as regras de negócio de propósito; em visual nenhum ela deve aparecer. Clique direito → `Ocultar`.
2. **Pasta de exibição** por camada (`00 Base`, `10 KPIs`, `20 Tempo`, `30 Território`, `40 Taxas`). Com 50 medidas, sem pastas ninguém acha nada.
3. **Formato**: inteiro com separador de milhar para contagens, percentual com 1 decimal para as de `%` e `variação %`, 1 decimal para as taxas.

### A regra que não pode ser quebrada

| Visual | Medida |
| --- | --- |
| Cartão de KPI do topo | `10_kpis.dax` — ignora o segmentador de categoria de propósito |
| Barras por categoria, árvore de decomposição, matriz de tipos | `[Ocorrências]` de `00_base.dax` — obedece aos segmentadores |
| Eixo = delegacia, AISP ou RISP | qualquer medida normal |
| Eixo = município ou região, e o mapa | as medidas `(por sede)` de `30_territorio.dax` |
| Página 4, produção da polícia | `[Atividade policial]` e as medidas de `apf`/`cmp`/recuperação |

Trocar uma dessas por outra não dá erro: dá número errado em silêncio. É o motivo de cada arquivo começar explicando qual é a sua camada.

### Alternativa mais enxuta para `20_tempo.dax`

As 12 medidas de tempo são o mesmo cálculo repetido 6 vezes. Um **grupo de cálculo** "Tempo" com três itens (`Valor`, `Mês anterior`, `Variação %`) usando `SELECTEDMEASURE()` substitui as 12 por 3 definições e passa a valer para qualquer KPI novo sem escrever mais nada. Exige o [Tabular Editor](https://tabulareditor.com/) (versão gratuita), que não é pré-requisito do trabalho — por isso o caminho padrão aqui é explícito.

## 5. Tema

`Exibição` → `Temas` → `Procurar temas` → `tema/tema-a3-criminalidade-rj.json`.

O tema entrega de uma vez a direção visual do plano: fundo `#F5F6F8`, cartões brancos de canto 8 px, azul petróleo `#1F4E79` como cor principal, vermelho tijolo `#C0392B` como única cor de alerta, Segoe UI nos tamanhos 30/14/10 pt, eixo de valor começando em zero e sem linha de grade vertical.

O vermelho está na **segunda** posição de `dataColors`, não na primeira: assim um gráfico de uma série sai azul por padrão e o vermelho só aparece quando alguém o escolhe, que é o comportamento certo para um tema sobre mortes.

Ao mudar cor ou fonte, mudar **no JSON** e recarregar o tema — nunca no painel de formatação de um visual. Formatação local sobrescreve o tema e some do controle de versão.

## 6. Mapa de formas

O Shape map do Power BI aceita um TopoJSON customizado. A malha dos municípios do RJ sai da API do IBGE:

```bash
curl -o rj-municipios.geojson \
  "https://servicodados.ibge.gov.br/api/v3/malhas/estados/33?formato=application/vnd.geo+json&intrarregiao=municipio&qualidade=intermediaria"
```

Converter em [mapshaper.org](https://mapshaper.org): abrir o GeoJSON, `Simplify` para ~15% (o arquivo cru é grande demais para o Shape map), `Export` → TopoJSON. Salvar em `powerbi/mapa/rj-municipios.topo.json`.

No Power BI: `Shape map` → `Adicionar mapa` → o TopoJSON. A chave de ligação é `MUNI_CD_IBGE` contra a propriedade `codarea` da malha — conferir o nome da propriedade no mapshaper, porque muda de versão para versão da API.

E o campo de valor do mapa tem de ser uma medida `(por sede)`. Com `[Letalidade violenta]` direto, os 9 municípios vizinhos das delegacias multi-município aparecem pintados com números que não são deles.

## 7. Verificação final

Antes de considerar a página pronta, conferir que o cartão de letalidade mostra **3.892** com nenhum filtro ativo. Se mostrar 7.803, a medida veio da categoria em vez do tipo agregado; se mostrar 2.987, alguém usou a medida de CVLI do guia antigo.

As demais referências de valor estão na tabela do final de [`sql/RUNBOOK.md`](../sql/RUNBOOK.md).
