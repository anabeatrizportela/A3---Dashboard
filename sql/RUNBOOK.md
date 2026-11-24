# Runbook do banco

Ordem de execução dos scripts SQL, do banco vazio até o modelo pronto para o Power BI.
Tudo roda no phpMyAdmin do XAMPP (aba **SQL**) ou no cliente de linha de comando.

## Ordem

| # | Arquivo | O que faz | Repetível? |
| --- | --- | --- | --- |
| 1 | `01_TABELAS.sql` | Cria o banco `seg_dashboard` e as 11 tabelas | Não — recria o schema |
| 2 | `02_CARGA.sql` | Insere as 85.986 linhas de 2025 | Não — IDs fixos |
| 3 | `migrations/03_01_TIPO_OCORRENCIA_AGREGADO.sql` | Marca os tipos que são totais de outros tipos | Sim |
| 4 | `migrations/03_02_CISP_MUNICIPIO_SEDE.sql` | Marca o município-sede de cada delegacia | Sim |
| 5 | `migrations/03_03_PERIODO_DATA_REFERENCIA.sql` | Transforma `SEG_PERIODO` em dimensão de tempo | Sim |
| 6 | `migrations/03_04_MUNICIPIO_POPULACAO.sql` | Cria as colunas de população | Sim |
| 7 | `seed/04_POPULACAO_IBGE.sql` | Carrega a população do IBGE | Sim |
| 8 | `qa/qa_01_totais_2025.sql` | Confere os totais de 2025 | Sim |
| 9 | `qa/qa_02_integridade_modelo.sql` | Confere as invariantes do modelo | Sim |

Os passos 3 a 7 são **forward-only**: não desfazem nada de `02_CARGA.sql`, só acrescentam colunas e preenchem. Cada migração tem o `ROLLBACK` comentado no próprio cabeçalho.

O passo 7 não está no repositório: é gerado. Antes dele, rodar

```bash
python3 -I scripts/gerar_populacao_ibge.py
```

O script lê a API do IBGE e escreve `sql/seed/04_POPULACAO_IBGE.sql`. Sem ele, os passos 1 a 6 funcionam e as taxas por 100 mil ficam em branco — o resto da dashboard não depende disso.

## Linha de comando

```bash
cd sql
mysql -u root < 01_TABELAS.sql
mysql -u root seg_dashboard < 02_CARGA.sql
for arquivo in migrations/03_*.sql; do mysql -u root seg_dashboard < "$arquivo"; done
mysql -u root seg_dashboard < seed/04_POPULACAO_IBGE.sql   # se já foi gerado
mysql -u root seg_dashboard < qa/qa_01_totais_2025.sql
mysql -u root seg_dashboard < qa/qa_02_integridade_modelo.sql
```

No XAMPP o usuário padrão é `root` sem senha. Com senha, acrescentar `-p`.

## Como ler o resultado do QA

Toda consulta de QA devolve uma coluna `DS_RESULTADO` com `OK` ou `FALHOU`, fora duas que devolvem **lista**: municípios sem população (`qa_02`, item 2.5) e delegacias com sede irregular (`qa_02`, item 2.1). Nessas duas, lista vazia é o resultado bom.

Qualquer `FALHOU` significa que as medidas DAX vão mostrar número errado. Corrigir o banco antes de abrir o Power BI.

| Teste | Valor esperado |
| --- | --- |
| 1.1 Totais por indicador | letalidade 3.892 · homicídio doloso 2.844 · MDIP 800 · feminicídio 105 · estupro 5.867 · furtos 187.984 · estelionato 146.981 |
| 1.2 Total de BOs | 965.208 |
| 1.3 Categoria sem agregados | Letalidade 3.892 · Roubos 98.459 · Furtos 187.984 |
| 1.4 CVLI com feminicídio | 3.092 (e **não** 2.987) |
| 1.5 Agregado = soma das partes | igualdade entre `letalidade_violenta` e os 5 tipos |
| 1.6 Letalidade por região | 3.892 com filtro de sede · 4.075 sem (diferença de 183) |
| 2.1 Uma sede por delegacia | 0 delegacias irregulares |
| 2.4 Dimensão de tempo | 12 períodos, 12 datas distintas, nenhuma nula |
| 2.6 Grade do fato | 83.844 linhas em `SEG_OCORRENCIA_MENSAL` |

## Compatibilidade

As migrações usam `IF NOT EXISTS` em `ADD COLUMN`, `ADD CONSTRAINT` e `CREATE INDEX` — é o que as torna repetíveis, e é sintaxe **MariaDB 10.0+**, o que o XAMPP instala.

No **MySQL 8** a cláusula não existe nessas três formas. Remover os `IF NOT EXISTS` e rodar cada migração uma única vez; a partir da segunda execução o MySQL reclama de coluna, constraint ou índice duplicado, e aí a coluna "Repetível" da tabela acima passa a valer só para MariaDB.

## Se precisar começar de novo

```sql
DROP DATABASE seg_dashboard;
```

E voltar ao passo 1. Com 86 mil linhas de `INSERT`, a carga leva alguns minutos.
