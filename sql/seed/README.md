# sql/seed/

Dados que não vêm da base do ISP e são **gerados**, nunca digitados.

## 04_POPULACAO_IBGE.sql

População dos 92 municípios do RJ, usada pelas taxas por 100 mil habitantes de [`powerbi/dax/40_taxas.dax`](../../powerbi/dax/40_taxas.dax).

O arquivo não está no repositório de propósito (está no `.gitignore`): ele é saída de um script, e versionar saída de script é guardar duas verdades sobre o mesmo dado. Para gerá-lo:

```bash
python3 -I scripts/gerar_populacao_ibge.py
```

O script lê a API de agregados do IBGE (Censo 2022, agregado 4714), escreve um `UPDATE` por município casado por `MUNI_CD_IBGE`, e leva o ano de referência para `MUNI_AA_POPULACAO` — sem ele a taxa fica sem procedência e não dá para citar a fonte na nota metodológica.

Se a API devolver menos de 92 municípios, o script **não** gera o arquivo. Taxa calculada sobre população parcial é pior do que taxa nenhuma: parece certa.

Para usar as estimativas anuais em vez do Censo:

```bash
python3 -I scripts/gerar_populacao_ibge.py --agregado 6579 --variavel 9324 --periodo 2025
```

Ordem de execução em [`sql/RUNBOOK.md`](../RUNBOOK.md).
