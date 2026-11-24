-- ==========================================================================
-- PROJETO : A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)
-- ARQUIVO : qa_02_integridade_modelo.sql
-- ASSUNTO : Invariantes do modelo - o que tem de ser verdade sempre
--
-- COMO USAR
--   Rodar depois das migracoes 03_*. Toda consulta aqui devolve OK ou FALHOU
--   (ou uma lista vazia, quando a lista e o problema). Nenhuma linha
--   FALHOU = modelo pronto para o Power BI.
-- ==========================================================================

USE seg_dashboard;

-- --------------------------------------------------------------------------
-- QA 2.1 - Toda delegacia tem EXATAMENTE uma sede
-- Esta e a invariante que sustenta a correcao da armadilha 3. Se falhar, o
-- mapa e os rankings por municipio voltam a duplicar (ou a perder) ocorrencia.
-- --------------------------------------------------------------------------
SELECT
	'2.1 Uma sede por delegacia'					AS DS_TESTE,
	COUNT(*)										AS QT_DELEGACIA_IRREGULAR,
	CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHOU' END AS DS_RESULTADO
FROM (
	SELECT CISP_ID_CISP
	FROM SEG_CISP_MUNICIPIO
	GROUP BY CISP_ID_CISP
	HAVING SUM(CASE WHEN CIMU_FL_SEDE = 'S' THEN 1 ELSE 0 END) <> 1
) IRREGULAR;

-- Detalhe, para quando a 2.1 falhar
SELECT
	C.CISP_NM_CISP									AS NM_DELEGACIA,
	COUNT(*)										AS QT_MUNICIPIO_ATENDIDO,
	SUM(CASE WHEN CM.CIMU_FL_SEDE = 'S' THEN 1 ELSE 0 END) AS QT_SEDE,
	GROUP_CONCAT(M.MUNI_NM_MUNICIPIO ORDER BY M.MUNI_NM_MUNICIPIO SEPARATOR ', ') AS DS_MUNICIPIOS
FROM SEG_CISP_MUNICIPIO CM
JOIN SEG_CISP      C ON C.CISP_ID_CISP = CM.CISP_ID_CISP
JOIN SEG_MUNICIPIO M ON M.MUNI_ID_MUNICIPIO = CM.MUNI_ID_MUNICIPIO
GROUP BY C.CISP_ID_CISP, C.CISP_NM_CISP
HAVING QT_SEDE <> 1
ORDER BY C.CISP_NR_CISP;

-- --------------------------------------------------------------------------
-- QA 2.2 - Delegacias multi-municipio e a sede escolhida
-- Lista de revisao: sao as 9 unicas decisoes manuais do modelo.
-- --------------------------------------------------------------------------
SELECT
	C.CISP_NM_CISP									AS NM_DELEGACIA,
	MAX(CASE WHEN CM.CIMU_FL_SEDE = 'S'
		THEN M.MUNI_NM_MUNICIPIO END)				AS NM_SEDE,
	GROUP_CONCAT(CASE WHEN CM.CIMU_FL_SEDE = 'N'
		THEN M.MUNI_NM_MUNICIPIO END
		ORDER BY M.MUNI_NM_MUNICIPIO SEPARATOR ', ') AS DS_TAMBEM_ATENDE
FROM SEG_CISP_MUNICIPIO CM
JOIN SEG_CISP      C ON C.CISP_ID_CISP = CM.CISP_ID_CISP
JOIN SEG_MUNICIPIO M ON M.MUNI_ID_MUNICIPIO = CM.MUNI_ID_MUNICIPIO
GROUP BY C.CISP_ID_CISP, C.CISP_NM_CISP, C.CISP_NR_CISP
HAVING COUNT(*) > 1
ORDER BY C.CISP_NR_CISP;

-- --------------------------------------------------------------------------
-- QA 2.3 - Tipos marcados como agregados
-- Esperado: letalidade_violenta e total_furtos (e apreensao_drogas apenas se
-- a migracao 03_01 confirmou que ela e a soma dos componentes).
-- --------------------------------------------------------------------------
SELECT
	T.TIOC_CD_TIPO_OCORRENCIA						AS CD_TIPO,
	T.TIOC_NM_TIPO_OCORRENCIA						AS NM_TIPO,
	C.CAOC_NM_CATEGORIA								AS NM_CATEGORIA
FROM SEG_TIPO_OCORRENCIA T
JOIN SEG_CATEGORIA_OCORRENCIA C ON C.CAOC_ID_CATEGORIA_OCORRENCIA = T.CAOC_ID_CATEGORIA_OCORRENCIA
WHERE T.TIOC_FL_AGREGADO = 'S'
ORDER BY T.TIOC_CD_TIPO_OCORRENCIA;

-- --------------------------------------------------------------------------
-- QA 2.4 - Dimensao de tempo pronta para o Power BI
-- 12 meses, nenhuma data nula, nenhuma data repetida, sem buraco na sequencia
-- --------------------------------------------------------------------------
SELECT
	'2.4 Dimensao de tempo'							AS DS_TESTE,
	COUNT(*)										AS QT_PERIODO,
	COUNT(DISTINCT PERI_DT_REFERENCIA)				AS QT_DATA_DISTINTA,
	SUM(CASE WHEN PERI_DT_REFERENCIA IS NULL THEN 1 ELSE 0 END) AS QT_DATA_NULA,
	TIMESTAMPDIFF(MONTH, MIN(PERI_DT_REFERENCIA), MAX(PERI_DT_REFERENCIA)) + 1 AS QT_MES_NO_INTERVALO,
	CASE WHEN COUNT(*) = COUNT(DISTINCT PERI_DT_REFERENCIA)
			AND SUM(CASE WHEN PERI_DT_REFERENCIA IS NULL THEN 1 ELSE 0 END) = 0
			AND COUNT(*) = TIMESTAMPDIFF(MONTH, MIN(PERI_DT_REFERENCIA), MAX(PERI_DT_REFERENCIA)) + 1
		THEN 'OK' ELSE 'FALHOU' END					AS DS_RESULTADO
FROM SEG_PERIODO;

-- --------------------------------------------------------------------------
-- QA 2.5 - Municipios ainda sem populacao
-- Enquanto houver linha aqui, as taxas por 100 mil ficam incompletas.
-- Rodar scripts/gerar_populacao_ibge.py e aplicar o seed gerado.
-- --------------------------------------------------------------------------
SELECT
	M.MUNI_CD_IBGE									AS CD_IBGE,
	M.MUNI_NM_MUNICIPIO								AS NM_MUNICIPIO,
	R.REGI_NM_REGIAO								AS NM_REGIAO
FROM SEG_MUNICIPIO M
JOIN SEG_REGIAO R ON R.REGI_ID_REGIAO = M.REGI_ID_REGIAO
WHERE M.MUNI_QT_POPULACAO IS NULL
ORDER BY M.MUNI_NM_MUNICIPIO;

-- --------------------------------------------------------------------------
-- QA 2.6 - Grade do fato completa (137 delegacias x 12 meses x 51 tipos)
-- --------------------------------------------------------------------------
SELECT
	'2.6 Grade do fato'								AS DS_TESTE,
	(SELECT COUNT(*) FROM SEG_CISP)					AS QT_CISP,
	(SELECT COUNT(*) FROM SEG_PERIODO)				AS QT_PERIODO,
	(SELECT COUNT(*) FROM SEG_TIPO_OCORRENCIA)		AS QT_TIPO,
	(SELECT COUNT(*) FROM SEG_REGISTRO_MENSAL)		AS QT_REGISTRO_MENSAL,
	(SELECT COUNT(*) FROM SEG_OCORRENCIA_MENSAL)	AS QT_OCORRENCIA_MENSAL,
	CASE WHEN (SELECT COUNT(*) FROM SEG_OCORRENCIA_MENSAL) = 83844
		THEN 'OK' ELSE 'FALHOU' END					AS DS_RESULTADO;
