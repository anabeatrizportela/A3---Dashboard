-- ==========================================================================
-- PROJETO : A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)
-- SGBD    : MySQL / MariaDB (XAMPP)
-- ARQUIVO : 03_04_MUNICIPIO_POPULACAO.sql
-- ASSUNTO : Populacao dos municipios para as taxas por 100 mil habitantes
--
-- PROBLEMA
--   O banco nao tem populacao, entao todo numero da dashboard e absoluto.
--   Comparar a Capital (6,2 mi de habitantes) com Macuco (5 mil) em numeros
--   absolutos sempre aponta a Capital, o que nao diz nada sobre risco.
--
-- SOLUCAO
--   Duas colunas em SEG_MUNICIPIO: a populacao e o ANO da estimativa. Sem o
--   ano a taxa fica sem procedencia e nao da para citar a fonte na nota
--   metodologica.
--
--   Esta migracao cria a estrutura. Os VALORES vem da API do IBGE e sao
--   gerados por scripts/gerar_populacao_ibge.py, que escreve
--   sql/seed/04_POPULACAO_IBGE.sql a partir dos 92 codigos IBGE que ja estao
--   em SEG_MUNICIPIO. Nenhum numero de populacao e digitado a mao neste repo.
--
-- ORDEM  : executar depois de 02_CARGA.sql, antes do seed de populacao
--          (ver sql/RUNBOOK.md)
-- ROLLBACK:
--   ALTER TABLE SEG_MUNICIPIO
--     DROP COLUMN MUNI_QT_POPULACAO,
--     DROP COLUMN MUNI_AA_POPULACAO;
-- ==========================================================================

USE seg_dashboard;

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-010
-- comment: Adicionando colunas de populacao em SEG_MUNICIPIO
-- --------------------------------------------------------------------------
ALTER TABLE SEG_MUNICIPIO
	ADD COLUMN IF NOT EXISTS MUNI_QT_POPULACAO INT  NULL AFTER REGI_ID_REGIAO,
	ADD COLUMN IF NOT EXISTS MUNI_AA_POPULACAO INT  NULL AFTER MUNI_QT_POPULACAO;

-- comment on column SEG_MUNICIPIO.MUNI_QT_POPULACAO is 'Populacao residente do municipio (fonte IBGE)';
-- comment on column SEG_MUNICIPIO.MUNI_AA_POPULACAO is 'Ano de referencia da populacao (ex.: 2022 para o Censo)';

ALTER TABLE SEG_MUNICIPIO
	ADD CONSTRAINT IF NOT EXISTS MUNI_CK_02 CHECK (MUNI_QT_POPULACAO IS NULL OR MUNI_QT_POPULACAO > 0),
	ADD CONSTRAINT IF NOT EXISTS MUNI_CK_03 CHECK (MUNI_AA_POPULACAO IS NULL OR MUNI_AA_POPULACAO BETWEEN 2000 AND 2100);

-- As taxas por 100 mil ficam em branco (DIVIDE devolve vazio) enquanto a
-- populacao for nula. Isso e proposital: melhor um cartao vazio do que uma
-- taxa calculada sobre populacao parcial. A consulta
-- sql/qa/qa_02_integridade_modelo.sql lista os municipios ainda sem populacao.
