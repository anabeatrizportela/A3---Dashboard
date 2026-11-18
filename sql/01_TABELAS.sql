

-- ==========================================================================
-- PROJETO : A3 - Dashboard Criminalidade no Estado do Rio de Janeiro (2025)
-- SGBD    : MySQL / MariaDB (XAMPP)
-- OBS     : Criacao das tabelas do modelo normalizado da base ISP-RJ
--           (BaseDPEvolucaoMensalCisp.csv). Executar antes do script de carga.
-- ==========================================================================

CREATE DATABASE IF NOT EXISTS seg_dashboard CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE seg_dashboard;

-- changeset bia.portela:20261118-001
-- comment: Criando tabela SEG_REGIAO
CREATE TABLE SEG_REGIAO (
	REGI_ID_REGIAO	INT			NOT NULL AUTO_INCREMENT,
	REGI_NM_REGIAO	VARCHAR(50)	NOT NULL,
	REGI_FL_SITUAC	CHAR(1)		NOT NULL DEFAULT 'A',
	CONSTRAINT REGI_PK PRIMARY KEY (REGI_ID_REGIAO),
	CONSTRAINT REGI_UK_01 UNIQUE (REGI_NM_REGIAO),
	CONSTRAINT REGI_CK_01 CHECK (REGI_FL_SITUAC IN ('A','I'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_REGIAO is 'Regioes do estado do Rio de Janeiro usadas pelo ISP';
-- comment on column SEG_REGIAO.REGI_ID_REGIAO is 'Identificador da regiao';
-- comment on column SEG_REGIAO.REGI_NM_REGIAO is 'Nome da regiao (Capital, Baixada Fluminense, Grande Niteroi, Interior)';
-- comment on column SEG_REGIAO.REGI_FL_SITUAC is 'Situacao do registro (A - Ativo/I - Inativo)';

-- changeset bia.portela:20261118-002
-- comment: Criando tabela SEG_MUNICIPIO
CREATE TABLE SEG_MUNICIPIO (
	MUNI_ID_MUNICIPIO	INT				NOT NULL AUTO_INCREMENT,
	MUNI_CD_IBGE		INT				NOT NULL,
	MUNI_NM_MUNICIPIO	VARCHAR(100)	NOT NULL,
	REGI_ID_REGIAO		INT				NOT NULL,
	MUNI_FL_SITUAC		CHAR(1)			NOT NULL DEFAULT 'A',
	CONSTRAINT MUNI_PK PRIMARY KEY (MUNI_ID_MUNICIPIO),
	CONSTRAINT MUNI_FK_01 FOREIGN KEY (REGI_ID_REGIAO) REFERENCES SEG_REGIAO (REGI_ID_REGIAO),
	CONSTRAINT MUNI_UK_01 UNIQUE (MUNI_CD_IBGE),
	CONSTRAINT MUNI_CK_01 CHECK (MUNI_FL_SITUAC IN ('A','I')),
	INDEX MUNI_IX_01 (REGI_ID_REGIAO)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_MUNICIPIO is 'Municipios do estado do Rio de Janeiro';
-- comment on column SEG_MUNICIPIO.MUNI_ID_MUNICIPIO is 'Identificador do municipio';
-- comment on column SEG_MUNICIPIO.MUNI_CD_IBGE is 'Codigo oficial do municipio no IBGE (7 digitos)';
-- comment on column SEG_MUNICIPIO.MUNI_NM_MUNICIPIO is 'Nome oficial do municipio (grafia do IBGE)';
-- comment on column SEG_MUNICIPIO.REGI_ID_REGIAO is 'Regiao a que o municipio pertence';
-- comment on column SEG_MUNICIPIO.MUNI_FL_SITUAC is 'Situacao do registro (A - Ativo/I - Inativo)';

-- changeset bia.portela:20261118-003
-- comment: Criando tabela SEG_RISP
CREATE TABLE SEG_RISP (
	RISP_ID_RISP	INT				NOT NULL AUTO_INCREMENT,
	RISP_NR_RISP	INT				NOT NULL,
	RISP_NM_RISP	VARCHAR(100)	NOT NULL,
	RISP_DS_AREA	VARCHAR(500)	NULL,
	RISP_FL_SITUAC	CHAR(1)			NOT NULL DEFAULT 'A',
	CONSTRAINT RISP_PK PRIMARY KEY (RISP_ID_RISP),
	CONSTRAINT RISP_UK_01 UNIQUE (RISP_NR_RISP),
	CONSTRAINT RISP_UK_02 UNIQUE (RISP_NM_RISP),
	CONSTRAINT RISP_CK_01 CHECK (RISP_FL_SITUAC IN ('A','I'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_RISP is 'Regioes Integradas de Seguranca Publica (RISP)';
-- comment on column SEG_RISP.RISP_ID_RISP is 'Identificador da RISP';
-- comment on column SEG_RISP.RISP_NR_RISP is 'Numero oficial da RISP (1 a 7)';
-- comment on column SEG_RISP.RISP_NM_RISP is 'Nome descritivo da RISP';
-- comment on column SEG_RISP.RISP_DS_AREA is 'Regioes de governo e quantidade de municipios cobertos pela RISP';
-- comment on column SEG_RISP.RISP_FL_SITUAC is 'Situacao do registro (A - Ativo/I - Inativo)';

-- changeset bia.portela:20261118-004
-- comment: Criando tabela SEG_AISP
CREATE TABLE SEG_AISP (
	AISP_ID_AISP	INT				NOT NULL AUTO_INCREMENT,
	AISP_NR_AISP	INT				NOT NULL,
	AISP_NM_AISP	VARCHAR(50)		NOT NULL,
	AISP_DS_AREA	VARCHAR(1000)	NULL,
	RISP_ID_RISP	INT				NOT NULL,
	AISP_FL_SITUAC	CHAR(1)			NOT NULL DEFAULT 'A',
	CONSTRAINT AISP_PK PRIMARY KEY (AISP_ID_AISP),
	CONSTRAINT AISP_FK_01 FOREIGN KEY (RISP_ID_RISP) REFERENCES SEG_RISP (RISP_ID_RISP),
	CONSTRAINT AISP_UK_01 UNIQUE (AISP_NR_AISP),
	CONSTRAINT AISP_UK_02 UNIQUE (AISP_NM_AISP),
	CONSTRAINT AISP_CK_01 CHECK (AISP_FL_SITUAC IN ('A','I')),
	INDEX AISP_IX_01 (RISP_ID_RISP)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_AISP is 'Areas Integradas de Seguranca Publica (AISP) - area de um batalhao da PM';
-- comment on column SEG_AISP.AISP_ID_AISP is 'Identificador da AISP';
-- comment on column SEG_AISP.AISP_NR_AISP is 'Numero oficial da AISP';
-- comment on column SEG_AISP.AISP_NM_AISP is 'Nome da AISP com o batalhao correspondente (ex.: AISP 5 - 5o BPM)';
-- comment on column SEG_AISP.AISP_DS_AREA is 'Area coberta pela AISP (municipios ou bairros da capital)';
-- comment on column SEG_AISP.RISP_ID_RISP is 'RISP a que a AISP pertence';
-- comment on column SEG_AISP.AISP_FL_SITUAC is 'Situacao do registro (A - Ativo/I - Inativo)';

-- changeset bia.portela:20261118-005
-- comment: Criando tabela SEG_CISP
CREATE TABLE SEG_CISP (
	CISP_ID_CISP				INT				NOT NULL AUTO_INCREMENT,
	CISP_NR_CISP				INT				NOT NULL,
	CISP_NM_CISP				VARCHAR(20)		NOT NULL,
	CISP_DS_UNIDADE_TERRITORIAL	VARCHAR(500)	NULL,
	CISP_FL_SITUAC				CHAR(1)			NOT NULL DEFAULT 'A',
	CONSTRAINT CISP_PK PRIMARY KEY (CISP_ID_CISP),
	CONSTRAINT CISP_UK_01 UNIQUE (CISP_NR_CISP),
	CONSTRAINT CISP_UK_02 UNIQUE (CISP_NM_CISP),
	CONSTRAINT CISP_CK_01 CHECK (CISP_FL_SITUAC IN ('A','I'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_CISP is 'Circunscricoes Integradas de Seguranca Publica (CISP) - area de uma delegacia';
-- comment on column SEG_CISP.CISP_ID_CISP is 'Identificador da CISP';
-- comment on column SEG_CISP.CISP_NR_CISP is 'Numero oficial da delegacia';
-- comment on column SEG_CISP.CISP_NM_CISP is 'Nome da delegacia (ex.: 5a DP)';
-- comment on column SEG_CISP.CISP_DS_UNIDADE_TERRITORIAL is 'Bairros/distritos atendidos pela delegacia (unidade territorial oficial do ISP)';
-- comment on column SEG_CISP.CISP_FL_SITUAC is 'Situacao do registro (A - Ativo/I - Inativo)';

-- changeset bia.portela:20261118-006
-- comment: Criando tabela SEG_CISP_MUNICIPIO (relacionamento Atende)
CREATE TABLE SEG_CISP_MUNICIPIO (
	CIMU_ID_CISP_MUNICIPIO	INT	NOT NULL AUTO_INCREMENT,
	CISP_ID_CISP			INT	NOT NULL,
	MUNI_ID_MUNICIPIO		INT	NOT NULL,
	CONSTRAINT CIMU_PK PRIMARY KEY (CIMU_ID_CISP_MUNICIPIO),
	CONSTRAINT CIMU_FK_01 FOREIGN KEY (CISP_ID_CISP) REFERENCES SEG_CISP (CISP_ID_CISP),
	CONSTRAINT CIMU_FK_02 FOREIGN KEY (MUNI_ID_MUNICIPIO) REFERENCES SEG_MUNICIPIO (MUNI_ID_MUNICIPIO),
	CONSTRAINT CIMU_UK_01 UNIQUE (CISP_ID_CISP, MUNI_ID_MUNICIPIO),
	INDEX CIMU_IX_01 (CISP_ID_CISP),
	INDEX CIMU_IX_02 (MUNI_ID_MUNICIPIO)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_CISP_MUNICIPIO is 'Municipios atendidos por cada delegacia';
-- comment on column SEG_CISP_MUNICIPIO.CIMU_ID_CISP_MUNICIPIO is 'Identificador da ligacao delegacia x municipio';
-- comment on column SEG_CISP_MUNICIPIO.CISP_ID_CISP is 'Delegacia';
-- comment on column SEG_CISP_MUNICIPIO.MUNI_ID_MUNICIPIO is 'Municipio atendido pela delegacia';

-- changeset bia.portela:20261118-007
-- comment: Criando tabela SEG_PERIODO
CREATE TABLE SEG_PERIODO (
	PERI_ID_PERIODO	INT	NOT NULL AUTO_INCREMENT,
	PERI_NR_MES		INT	NOT NULL,
	PERI_NR_ANO		INT	NOT NULL,
	CONSTRAINT PERI_PK PRIMARY KEY (PERI_ID_PERIODO),
	CONSTRAINT PERI_UK_01 UNIQUE (PERI_NR_MES, PERI_NR_ANO),
	CONSTRAINT PERI_CK_01 CHECK (PERI_NR_MES BETWEEN 1 AND 12)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_PERIODO is 'Meses de referencia dos registros';
-- comment on column SEG_PERIODO.PERI_ID_PERIODO is 'Identificador do periodo';
-- comment on column SEG_PERIODO.PERI_NR_MES is 'Mes (1 a 12)';
-- comment on column SEG_PERIODO.PERI_NR_ANO is 'Ano';

-- changeset bia.portela:20261118-008
-- comment: Criando tabela SEG_CATEGORIA_OCORRENCIA
CREATE TABLE SEG_CATEGORIA_OCORRENCIA (
	CAOC_ID_CATEGORIA_OCORRENCIA	INT			NOT NULL AUTO_INCREMENT,
	CAOC_NM_CATEGORIA				VARCHAR(50)	NOT NULL,
	CAOC_FL_SITUAC					CHAR(1)		NOT NULL DEFAULT 'A',
	CONSTRAINT CAOC_PK PRIMARY KEY (CAOC_ID_CATEGORIA_OCORRENCIA),
	CONSTRAINT CAOC_UK_01 UNIQUE (CAOC_NM_CATEGORIA),
	CONSTRAINT CAOC_CK_01 CHECK (CAOC_FL_SITUAC IN ('A','I'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_CATEGORIA_OCORRENCIA is 'Categorias que agrupam os tipos de ocorrencia';
-- comment on column SEG_CATEGORIA_OCORRENCIA.CAOC_ID_CATEGORIA_OCORRENCIA is 'Identificador da categoria';
-- comment on column SEG_CATEGORIA_OCORRENCIA.CAOC_NM_CATEGORIA is 'Nome da categoria';
-- comment on column SEG_CATEGORIA_OCORRENCIA.CAOC_FL_SITUAC is 'Situacao do registro (A - Ativo/I - Inativo)';

-- changeset bia.portela:20261118-009
-- comment: Criando tabela SEG_TIPO_OCORRENCIA
CREATE TABLE SEG_TIPO_OCORRENCIA (
	TIOC_ID_TIPO_OCORRENCIA			INT				NOT NULL AUTO_INCREMENT,
	TIOC_CD_TIPO_OCORRENCIA			VARCHAR(50)		NOT NULL,
	TIOC_NM_TIPO_OCORRENCIA			VARCHAR(100)	NOT NULL,
	CAOC_ID_CATEGORIA_OCORRENCIA	INT				NOT NULL,
	TIOC_FL_SITUAC					CHAR(1)			NOT NULL DEFAULT 'A',
	CONSTRAINT TIOC_PK PRIMARY KEY (TIOC_ID_TIPO_OCORRENCIA),
	CONSTRAINT TIOC_FK_01 FOREIGN KEY (CAOC_ID_CATEGORIA_OCORRENCIA) REFERENCES SEG_CATEGORIA_OCORRENCIA (CAOC_ID_CATEGORIA_OCORRENCIA),
	CONSTRAINT TIOC_UK_01 UNIQUE (TIOC_CD_TIPO_OCORRENCIA),
	CONSTRAINT TIOC_UK_02 UNIQUE (TIOC_NM_TIPO_OCORRENCIA),
	CONSTRAINT TIOC_CK_01 CHECK (TIOC_FL_SITUAC IN ('A','I')),
	INDEX TIOC_IX_01 (CAOC_ID_CATEGORIA_OCORRENCIA)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_TIPO_OCORRENCIA is 'Tipos de ocorrencia (indicadores do ISP)';
-- comment on column SEG_TIPO_OCORRENCIA.TIOC_ID_TIPO_OCORRENCIA is 'Identificador do tipo de ocorrencia';
-- comment on column SEG_TIPO_OCORRENCIA.TIOC_CD_TIPO_OCORRENCIA is 'Nome da coluna no CSV original do ISP (ex.: roubo_celular)';
-- comment on column SEG_TIPO_OCORRENCIA.TIOC_NM_TIPO_OCORRENCIA is 'Nome do tipo de ocorrencia para exibicao';
-- comment on column SEG_TIPO_OCORRENCIA.CAOC_ID_CATEGORIA_OCORRENCIA is 'Categoria do tipo de ocorrencia';
-- comment on column SEG_TIPO_OCORRENCIA.TIOC_FL_SITUAC is 'Situacao do registro (A - Ativo/I - Inativo)';

-- changeset bia.portela:20261118-010
-- comment: Criando tabela SEG_REGISTRO_MENSAL
CREATE TABLE SEG_REGISTRO_MENSAL (
	REME_ID_REGISTRO_MENSAL			INT	NOT NULL AUTO_INCREMENT,
	CISP_ID_CISP					INT	NOT NULL,
	AISP_ID_AISP					INT	NOT NULL,
	PERI_ID_PERIODO					INT	NOT NULL,
	REME_QT_REGISTRO_OCORRENCIAS	INT	NOT NULL,
	CONSTRAINT REME_PK PRIMARY KEY (REME_ID_REGISTRO_MENSAL),
	CONSTRAINT REME_FK_01 FOREIGN KEY (CISP_ID_CISP) REFERENCES SEG_CISP (CISP_ID_CISP),
	CONSTRAINT REME_FK_02 FOREIGN KEY (AISP_ID_AISP) REFERENCES SEG_AISP (AISP_ID_AISP),
	CONSTRAINT REME_FK_03 FOREIGN KEY (PERI_ID_PERIODO) REFERENCES SEG_PERIODO (PERI_ID_PERIODO),
	CONSTRAINT REME_UK_01 UNIQUE (CISP_ID_CISP, PERI_ID_PERIODO),
	CONSTRAINT REME_CK_01 CHECK (REME_QT_REGISTRO_OCORRENCIAS >= 0),
	INDEX REME_IX_01 (CISP_ID_CISP),
	INDEX REME_IX_02 (AISP_ID_AISP),
	INDEX REME_IX_03 (PERI_ID_PERIODO)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_REGISTRO_MENSAL is 'Registro mensal de cada delegacia (delegacia x mes)';
-- comment on column SEG_REGISTRO_MENSAL.REME_ID_REGISTRO_MENSAL is 'Identificador do registro mensal';
-- comment on column SEG_REGISTRO_MENSAL.CISP_ID_CISP is 'Delegacia';
-- comment on column SEG_REGISTRO_MENSAL.AISP_ID_AISP is 'AISP em que a delegacia estava no mes';
-- comment on column SEG_REGISTRO_MENSAL.PERI_ID_PERIODO is 'Mes de referencia';
-- comment on column SEG_REGISTRO_MENSAL.REME_QT_REGISTRO_OCORRENCIAS is 'Total de registros de ocorrencia (BOs) da delegacia no mes';

-- changeset bia.portela:20261118-011
-- comment: Criando tabela SEG_OCORRENCIA_MENSAL
CREATE TABLE SEG_OCORRENCIA_MENSAL (
	OCME_ID_OCORRENCIA_MENSAL	INT	NOT NULL AUTO_INCREMENT,
	REME_ID_REGISTRO_MENSAL		INT	NOT NULL,
	TIOC_ID_TIPO_OCORRENCIA		INT	NOT NULL,
	OCME_QT_OCORRENCIA			INT	NOT NULL,
	CONSTRAINT OCME_PK PRIMARY KEY (OCME_ID_OCORRENCIA_MENSAL),
	CONSTRAINT OCME_FK_01 FOREIGN KEY (REME_ID_REGISTRO_MENSAL) REFERENCES SEG_REGISTRO_MENSAL (REME_ID_REGISTRO_MENSAL),
	CONSTRAINT OCME_FK_02 FOREIGN KEY (TIOC_ID_TIPO_OCORRENCIA) REFERENCES SEG_TIPO_OCORRENCIA (TIOC_ID_TIPO_OCORRENCIA),
	CONSTRAINT OCME_UK_01 UNIQUE (REME_ID_REGISTRO_MENSAL, TIOC_ID_TIPO_OCORRENCIA),
	CONSTRAINT OCME_CK_01 CHECK (OCME_QT_OCORRENCIA >= 0),
	INDEX OCME_IX_01 (REME_ID_REGISTRO_MENSAL),
	INDEX OCME_IX_02 (TIOC_ID_TIPO_OCORRENCIA)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- comment on table SEG_OCORRENCIA_MENSAL is 'Quantidade de ocorrencias por delegacia, mes e tipo';
-- comment on column SEG_OCORRENCIA_MENSAL.OCME_ID_OCORRENCIA_MENSAL is 'Identificador da ocorrencia mensal';
-- comment on column SEG_OCORRENCIA_MENSAL.REME_ID_REGISTRO_MENSAL is 'Registro mensal (delegacia x mes)';
-- comment on column SEG_OCORRENCIA_MENSAL.TIOC_ID_TIPO_OCORRENCIA is 'Tipo de ocorrencia';
-- comment on column SEG_OCORRENCIA_MENSAL.OCME_QT_OCORRENCIA is 'Quantidade de ocorrencias do tipo na delegacia no mes';
