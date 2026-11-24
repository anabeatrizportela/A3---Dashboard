# Modelo de dados

Referência técnica do banco `seg_dashboard` e das três correções que o modelo recebeu.
Para o plano da dashboard (páginas, visuais, identidade visual), ver [PLANO_DASHBOARD.md](PLANO_DASHBOARD.md).

## Origem

Base pública do ISP-RJ (`BaseDPEvolucaoMensalCisp.csv`), filtrada para jan–dez de 2025, normalizada em 11 tabelas e enriquecida com os códigos IBGE dos municípios.

## Esquema em estrela

O fato principal é `SEG_OCORRENCIA_MENSAL`, com 83.844 linhas (137 delegacias × 12 meses × 51 tipos). Ele não se liga às dimensões direto: passa por `SEG_REGISTRO_MENSAL`, que é o fato de granularidade delegacia × mês e guarda o total de BOs.

```
SEG_RISP (7)
   └── SEG_AISP (40)
          └── SEG_REGISTRO_MENSAL ──── SEG_PERIODO (12)
                 │      │                  (dimensão de tempo)
                 │      └── SEG_CISP (137)
                 │                └── SEG_CISP_MUNICIPIO (147, ponte N:N)
                 │                          └── SEG_MUNICIPIO (92)
                 │                                   └── SEG_REGIAO (4)
                 └── SEG_OCORRENCIA_MENSAL (83.844)
                            └── SEG_TIPO_OCORRENCIA (51)
                                     └── SEG_CATEGORIA_OCORRENCIA (8)
```

Duas hierarquias de território convivem no modelo e **não** são a mesma coisa:

- **Policial** — RISP (7) → AISP (40, batalhão da PM) → CISP (137, delegacia). Hierarquia limpa: cada delegacia pertence a uma AISP e cada AISP a uma RISP. Somar por aqui nunca duplica.
- **Civil** — Região (4) → Município (92), alcançada pela ponte `SEG_CISP_MUNICIPIO`. É muitos-para-muitos e **duplica** se usada sem cuidado (ver armadilha 3).

## As três correções aplicadas

Cada uma virou uma migração em [`sql/migrations/`](../sql/migrations/) e um teste em [`sql/qa/`](../sql/qa/).

### 1. Tipos que são totais de outros tipos

A base do ISP mistura, na mesma lista de 51 indicadores, tipos atômicos (`hom_doloso`, `furto_celular`) e tipos que são a soma de outros (`letalidade_violenta`, `total_furtos`). Somar sem distinguir conta os mesmos crimes duas vezes:

| Soma | Com agregado | Real |
| --- | --- | --- |
| Categoria Furtos | 376.530 | 187.984 |
| Categoria Letalidade violenta | 7.803 | 3.892 |
| Total de ocorrências | 946.380 | — |

**Correção:** coluna `SEG_TIPO_OCORRENCIA.TIOC_FL_AGREGADO` (`S`/`N`). Toda soma de criminalidade filtra `N`; os agregados são usados só pelos KPIs que são, eles mesmos, o agregado.

Marcados como agregados:

| Tipo | Composição |
| --- | --- |
| `letalidade_violenta` | `hom_doloso` + `lesao_corp_morte` + `latrocinio` + `hom_por_interv_policial` + `feminicidio` |
| `total_furtos` | os 6 tipos de furto da categoria |
| `apreensao_drogas` | marcado **só se o dado confirmar** — a migração compara o total com `posse_drogas` + `trafico_drogas` + `apreensao_drogas_sem_autor` e decide pelo resultado, em vez de assumir |

A categoria **Atividade policial** (prisão em flagrante, mandado, recuperação de veículo) não é agregado, mas também não é crime: mede produção da polícia. Fica fora da medida base `[Ocorrências]` e tem medidas próprias.

### 2. CVLI sem feminicídio

A medida do guia original soma `hom_doloso` + `lesao_corp_morte` + `latrocinio` e devolve 2.987. Nesta base o homicídio doloso **não** inclui feminicídio — a prova é que 2.844 + 77 + 66 + 800 + 105 fecha exatamente a letalidade violenta (3.892). Sem o feminicídio o CVLI perde 105 mortes.

**Correção:** `feminicidio` entra no CVLI, que passa a 3.092. É correção de medida DAX, não de banco — ver [`powerbi/dax/10_kpis.dax`](../powerbi/dax/10_kpis.dax).

### 3. Delegacia que atende mais de um município

A ponte `SEG_CISP_MUNICIPIO` tem 147 linhas para 137 delegacias: 9 delegacias do Interior atendem mais de um município. Somar por município ou por região repete a mesma ocorrência em cada município atendido — a letalidade por região soma 4.075 em vez de 3.892, 183 mortes a mais.

**Correção:** coluna `SEG_CISP_MUNICIPIO.CIMU_FL_SEDE` (`S`/`N`), com exatamente uma sede por delegacia. Mapas, rankings por município e somas por região filtram `S`.

Das 137 delegacias, 128 têm município único e a sede sai do próprio dado. As 9 restantes são as únicas decisões manuais do modelo, concentradas em um bloco de 9 linhas na migração:

| Delegacia | Sede | Também atende |
| --- | --- | --- |
| 96ª DP | Miguel Pereira | Paty do Alferes |
| 100ª DP | Porto Real | Quatis |
| 108ª DP | Três Rios | Areal, Comendador Levy Gasparian |
| 130ª DP | Quissamã | Carapebus |
| 136ª DP | Santo Antônio de Pádua | Aperibé |
| 140ª DP | Natividade | Varre-Sai |
| 143ª DP | Itaperuna | São José de Ubá |
| 148ª DP | Italva | Cardoso Moreira |
| 154ª DP | Cordeiro | Macuco |

O critério é **onde a delegacia está instalada**, não a ordem de `CISP_DS_UNIDADE_TERRITORIAL`: a 108ª fica em Três Rios e a descrição começa por Areal. O item 2.2 de `qa_02_integridade_modelo.sql` imprime esta tabela a partir do banco, para o grupo revisar as 9 linhas sem abrir o SQL.

## Acréscimos ao modelo

| Tabela | Coluna | Para que |
| --- | --- | --- |
| `SEG_TIPO_OCORRENCIA` | `TIOC_FL_AGREGADO` | Armadilha 1 |
| `SEG_CISP_MUNICIPIO` | `CIMU_FL_SEDE` | Armadilha 3 |
| `SEG_PERIODO` | `PERI_DT_REFERENCIA`, `PERI_NM_MES`, `PERI_NR_TRIMESTRE` | Inteligência de tempo no DAX |
| `SEG_MUNICIPIO` | `MUNI_QT_POPULACAO`, `MUNI_AA_POPULACAO` | Taxas por 100 mil |

### Por que `SEG_PERIODO` e não uma `dCalendario`

O plano deixava as duas opções abertas. O modelo usa `SEG_PERIODO`: o fato **já** é mensal e **já** se liga a essa tabela. Uma tabela de calendário paralela acrescentaria um relacionamento e um risco de granularidade divergente sem resolver nada. Só falta marcá-la como tabela de datas no Power BI, por `PERI_DT_REFERENCIA`.

### Por que a população é gerada, não digitada

92 números digitados à mão é a maneira mais fácil de colocar um erro invisível no trabalho — ninguém confere 92 números. [`scripts/gerar_populacao_ibge.py`](../scripts/gerar_populacao_ibge.py) lê a API do IBGE e gera o seed, levando o ano de referência junto para a nota metodológica. Se a API devolver menos de 92 municípios, o script falha em pé em vez de gerar um seed pela metade.

## Convenções herdadas da carga

Mantidas em todos os arquivos novos, para o repositório continuar legível de ponta a ponta:

- Prefixo de 4 letras por tabela nas colunas (`TIOC_`, `CIMU_`, `MUNI_`).
- `_ID_` chave, `_CD_` código externo, `_NM_` nome, `_DS_` descrição, `_QT_` quantidade, `_DT_` data, `_NR_` número, `_AA_` ano, `_FL_` flag.
- Flags em `CHAR(1)` com `CHECK` do domínio.
- Cada bloco de mudança anotado com `-- changeset <autor>:<data>-<sequência>` e um `-- comment:`.
