-- ==========================================================================
-- PROJETO : A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)
-- SGBD    : MySQL / MariaDB (XAMPP)
-- ARQUIVO : 03_01_TIPO_OCORRENCIA_AGREGADO.sql
-- ASSUNTO : Armadilha 1 - tipos de ocorrencia que sao TOTAIS de outros tipos
--
-- PROBLEMA
--   A base do ISP mistura, na mesma lista de 51 indicadores, tipos atomicos
--   (hom_doloso, furto_celular...) e tipos que sao a SOMA de outros tipos
--   (letalidade_violenta, total_furtos). Somar a coluna de quantidade sem
--   distinguir os dois conta os mesmos crimes duas vezes:
--     - categoria Furtos ....... 376.530 em vez de 187.984
--     - categoria Letalidade ... 7.803   em vez de 3.892
--
-- SOLUCAO
--   Marcar os agregados em uma coluna propria (TIOC_FL_AGREGADO) e filtrar
--   TIOC_FL_AGREGADO = 'N' em toda medida de soma. Os agregados continuam na
--   tabela e sao usados APENAS pelos KPIs que sao, eles mesmos, o agregado.
--
-- ORDEM  : executar depois de 02_CARGA.sql (ver sql/RUNBOOK.md)
-- ROLLBACK:
--   ALTER TABLE SEG_TIPO_OCORRENCIA DROP COLUMN TIOC_FL_AGREGADO;
-- ==========================================================================

USE seg_dashboard;

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-001
-- comment: Adicionando coluna TIOC_FL_AGREGADO em SEG_TIPO_OCORRENCIA
-- obs: IF NOT EXISTS exige MariaDB 10.0+ (padrao do XAMPP). No MySQL 8, que
--      nao suporta a clausula, remover "IF NOT EXISTS" e rodar uma unica vez.
-- --------------------------------------------------------------------------
ALTER TABLE SEG_TIPO_OCORRENCIA
	ADD COLUMN IF NOT EXISTS TIOC_FL_AGREGADO CHAR(1) NOT NULL DEFAULT 'N'
		AFTER CAOC_ID_CATEGORIA_OCORRENCIA;

-- comment on column SEG_TIPO_OCORRENCIA.TIOC_FL_AGREGADO is 'Indica se o tipo e a soma de outros tipos da base (S - Agregado/N - Atomico)';

ALTER TABLE SEG_TIPO_OCORRENCIA
	ADD CONSTRAINT IF NOT EXISTS TIOC_CK_02 CHECK (TIOC_FL_AGREGADO IN ('S','N'));

CREATE INDEX IF NOT EXISTS TIOC_IX_02 ON SEG_TIPO_OCORRENCIA (TIOC_FL_AGREGADO);

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-002
-- comment: Marcando os agregados confirmados (letalidade_violenta e total_furtos)
-- --------------------------------------------------------------------------
-- letalidade_violenta = hom_doloso + lesao_corp_morte + latrocinio
--                     + hom_por_interv_policial + feminicidio
--                     (2.844 + 77 + 66 + 800 + 105 = 3.892)
-- total_furtos        = furto_veiculos + furto_transeunte + furto_coletivo
--                     + furto_celular + furto_bicicleta + outros_furtos
UPDATE SEG_TIPO_OCORRENCIA
SET TIOC_FL_AGREGADO = 'S'
WHERE TIOC_CD_TIPO_OCORRENCIA IN ('letalidade_violenta', 'total_furtos');

-- --------------------------------------------------------------------------
-- changeset paulo.alves:20261123-003
-- comment: Marcando apreensao_drogas como agregado SOMENTE se o dado confirmar
-- obs: o plano levanta a suspeita (25.830) mas nao a confirma. Em vez de
--      decidir no escuro, o proprio dado decide: a coluna so vira 'S' se o
--      total de apreensao_drogas for igual a soma dos tres componentes.
--      As variaveis evitam o erro 1093 do MySQL (subquery na tabela alterada).
-- --------------------------------------------------------------------------
SET @qt_apreensao_drogas = (
	SELECT COALESCE(SUM(O.OCME_QT_OCORRENCIA), 0)
	FROM SEG_OCORRENCIA_MENSAL O
	JOIN SEG_TIPO_OCORRENCIA T ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
	WHERE T.TIOC_CD_TIPO_OCORRENCIA = 'apreensao_drogas'
);

SET @qt_componentes_drogas = (
	SELECT COALESCE(SUM(O.OCME_QT_OCORRENCIA), 0)
	FROM SEG_OCORRENCIA_MENSAL O
	JOIN SEG_TIPO_OCORRENCIA T ON T.TIOC_ID_TIPO_OCORRENCIA = O.TIOC_ID_TIPO_OCORRENCIA
	WHERE T.TIOC_CD_TIPO_OCORRENCIA IN ('posse_drogas', 'trafico_drogas', 'apreensao_drogas_sem_autor')
);

UPDATE SEG_TIPO_OCORRENCIA
SET TIOC_FL_AGREGADO = 'S'
WHERE TIOC_CD_TIPO_OCORRENCIA = 'apreensao_drogas'
  AND @qt_apreensao_drogas = @qt_componentes_drogas;

-- Resultado da verificacao, para registro no log de execucao.
SELECT
	@qt_apreensao_drogas						AS QT_APREENSAO_DROGAS,
	@qt_componentes_drogas						AS QT_SOMA_COMPONENTES,
	CASE WHEN @qt_apreensao_drogas = @qt_componentes_drogas
		THEN 'AGREGADO - marcado como S'
		ELSE 'ATOMICO - mantido como N'
	END											AS DS_DECISAO;
