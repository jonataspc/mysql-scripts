/*
*** Descrição *** 
Script SQL para processamento consolidado de dados de aluguel de ativos da B3 (BTC) no formato de extrato bancário 
do banco Inter (CSV) para que seja importado de maneira simplificada do app web Dlombello (https://app.dlombelloplanilhas.com)

*** Detalhes ***
O relatório irá ser extraído de maneira consolidada (agrupada) por ativo, já no formato esperado pelo app web.

*** Instruções *** 
1. Obter o extrato mensal a partir do app Inter referente ao mês desejado (ex: 01/01/2023 - 31/01/2023). Exportar em CSV.
2. O arquivo CSV deverá conter estrutura de cabeçalho e conteúdo conforme exemplo abaixo:

------------------------------------------------------------------------------
 Extrato Conta Corrente 
Conta ;XXXXX
Período ;01/01/2023 a 31/01/2023

Data Lançamento;Histórico;Descrição;Valor;Saldo
31/01/2023;Débito B3;* Prov * Custo Operacional Aluguel Vale3;-0,01
31/01/2023;Débito B3;* Prov * Irrf - Btb  Vale;-0,01
31/01/2023;Crédito B3;* Prov * Remuneracao De Aluguel Vale;0,01
------------------------------------------------------------------------------

3. Informar o caminho do arquivo CSV no script (procurar por 'informe aqui o path do arquivo CSV')
4. Executar o script.
5. Exporte o texto do resultado e cole no painel de importação de proventos do app web (https://app.dlombelloplanilhas.com/proventos)

*** Informações importantes *** 
1. Caso não haja o ticker no formato completo no extrato, o ativo ficará com o sufixo '!!!' indicando que deverá ser analisado manualmente

*** Disclaimer *** 
Use este script por sua conta e risco. Sempre confira os valores ao realizar os lançamentos. 

*/


### Parametros de configuração ###
SET @PrefixoidentificacaoDescricaoIrrf = '* Prov * Irrf - Btb';
SET @IdentificadorTickerNaoEncontrato = '!!!';

### Data loader ###
SET GLOBAL local_infile=1;

DROP TABLE IF EXISTS lancamentos_inter; 
CREATE TABLE lancamentos_inter 
(
DATA DATE NOT NULL,
historico VARCHAR(500) NOT NULL,
descricao VARCHAR(500) NOT NULL,
valor DECIMAL (10,2) NOT NULL
);


LOAD DATA LOCAL 
INFILE 'C:/tmp/Extrato-01-01-2023-a-31-01-2023.csv' /* informe aqui o path do arquivo CSV */
    INTO TABLE lancamentos_inter 
    CHARACTER SET UTF8
    FIELDS TERMINATED BY ';' 

IGNORE 5 LINES
(@data ,historico, descricao, @valor)
SET DATA = STR_TO_DATE(@data, '%d/%m/%Y') ,
valor = CAST(REPLACE(@valor, ',', '.') AS DECIMAL(18,2));

### Main report ###

SELECT 

# *
# para formato tabular, descomentar linha acima e comentar linha abaixo
GROUP_CONCAT(CONCAT_WS('\t', ativo, data_referencia, evento, total_bruto_ja_descontado_custo_corretora, irrf, moeda, Corretora) SEPARATOR '\n') AS result

FROM 
(

	SELECT 
	UCASE(ticker_higienizado) AS Ativo, 
	(SELECT MAX(DATA) FROM lancamentos_inter ) AS data_referencia, 
	# SUM(valor) AS valor_liquido, 
	'BTC' AS Evento,
	SUM(
	IF( t1.descricao NOT LIKE CONCAT('%', @PrefixoidentificacaoDescricaoIrrf, '%') , valor, 0)
	) AS total_bruto_ja_descontado_custo_corretora,
	'INTER' AS Corretora, 
	'BRL' AS Moeda,
	SUM(
	  IF( t1.descricao LIKE CONCAT('%', @PrefixoidentificacaoDescricaoIrrf, '%') , valor, 0)
	) * -1 AS Irrf 

	 
	 FROM 
		(
		SELECT 
		a.valor, 
		a.descricao, 
		@ticker_bruto := TRIM(REGEXP_REPLACE(RIGHT(a.descricao,5), '[0-9]+', '')) AS ticker_bruto,

		COALESCE
		(
			(
			SELECT 
			REGEXP_SUBSTR(descricao, '[:alnum:]{4}[:digit:]{1,2}') FROM lancamentos_inter l
			WHERE  
			REGEXP_SUBSTR(descricao, '[:alnum:]{4}[:digit:]{1}') LIKE CONCAT('%', @ticker_bruto, '_') /* tcker bruto*/
			LIMIT 1),
		CONCAT(@ticker_bruto, @IdentificadorTickerNaoEncontrato)
		) AS ticker_higienizado

		 FROM lancamentos_inter a
		WHERE 
		(descricao LIKE '%Irrf%' OR descricao LIKE '%aluguel%')
		) t1 

	GROUP BY ticker_higienizado 
	ORDER BY data_referencia, ticker_higienizado
) t2 
;

DROP TABLE lancamentos_inter; 
