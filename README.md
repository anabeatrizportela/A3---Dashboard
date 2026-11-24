# A3 — Dashboard de Criminalidade no Estado do Rio de Janeiro (2025)

Relatório Power BI sobre as ocorrências registradas pelas 137 delegacias do Rio de Janeiro em 2025, a partir da base pública do ISP-RJ.

## Por onde começar

| Quero… | Vá para |
| --- | --- |
| Entender o que a dashboard vai ser | [docs/PLANO_DASHBOARD.md](docs/PLANO_DASHBOARD.md) |
| Subir o banco no meu computador | [sql/RUNBOOK.md](sql/RUNBOOK.md) |
| Entender o modelo e as correções | [docs/MODELO_DE_DADOS.md](docs/MODELO_DE_DADOS.md) |
| Montar o relatório no Power BI | [powerbi/README.md](powerbi/README.md) |
| Ver o significado de cada coluna | `dados/PLANILHA EXPLICADA.xlsx` |

## Estrutura

```
.
├── dados/        planilha explicada (uma aba por tabela)
├── docs/         plano da dashboard, modelo de dados, guia original em PDF
├── powerbi/      medidas DAX (por camada) e tema visual JSON
├── scripts/      geração do seed de população a partir da API do IBGE
└── sql/
    ├── 01_TABELAS.sql       schema
    ├── 02_CARGA.sql         85.986 linhas de 2025
    ├── migrations/          correções do modelo, forward-only
    ├── qa/                  conferência dos totais e das invariantes
    └── RUNBOOK.md           ordem de execução
```

Cada camada depende só da anterior: `sql/` não sabe nada do Power BI, `powerbi/dax/` não escreve SQL, e as medidas de cada arquivo DAX só usam medidas dos arquivos de número menor.

O arquivo `.pbix` **não** é versionado: é binário, não dá diff e dois integrantes editando o mesmo arquivo geram conflito que o git não resolve. O que o repositório versiona é o que gera o `.pbix` — o modelo, as medidas e o tema.

## Caminho rápido

```bash
# 1. banco
mysql -u root < sql/01_TABELAS.sql
mysql -u root seg_dashboard < sql/02_CARGA.sql
for f in sql/migrations/03_*.sql; do mysql -u root seg_dashboard < "$f"; done

# 2. população (opcional, só para as taxas por 100 mil)
python3 -I scripts/gerar_populacao_ibge.py
mysql -u root seg_dashboard < sql/seed/04_POPULACAO_IBGE.sql

# 3. conferência
mysql -u root seg_dashboard < sql/qa/qa_01_totais_2025.sql
mysql -u root seg_dashboard < sql/qa/qa_02_integridade_modelo.sql
```

Todo teste do passo 3 tem de devolver `OK`. Depois disso, seguir [powerbi/README.md](powerbi/README.md).

## Os números de referência de 2025

Se a dashboard mostrar outro valor para qualquer um destes com nenhum filtro ativo, há erro de medida:

| Indicador | 2025 |
| --- | --- |
| Boletins de ocorrência | 965.208 |
| Letalidade violenta | 3.892 |
| Mortes por intervenção do Estado | 800 |
| Roubos | 98.459 |
| Furtos | 187.984 |
| Estelionato | 146.981 |

As três armadilhas que produzem número errado — tipos que são totais de outros tipos, CVLI sem feminicídio e delegacia que atende mais de um município — estão explicadas e corrigidas em [docs/MODELO_DE_DADOS.md](docs/MODELO_DE_DADOS.md).

## Fonte

Instituto de Segurança Pública do Rio de Janeiro (ISP-RJ), base de evolução mensal por CISP, jan–dez de 2025 — <https://www.ispdados.rj.gov.br>. População dos municípios: IBGE, API de agregados.
