DECLARE 
	@CODPARC		INT,
	@NUNOTA			INT,
	@CODPARCOLD		INT;

DECLARE	cursor_pedidos CURSOR FAST_FORWARD FOR
	SELECT CODPARC, NUNOTA, CODPARCDEST
	FROM SANKHYA_PRODUCAO.sankhya.TGFCAB AS C WITH (NOLOCK)
	WHERE CODPARCDEST != CODPARC 
	AND CODPARCDEST != 0
	AND DTNEG >= '2018-01-01'
	AND TIPMOV = 'P';
	
OPEN cursor_pedidos

FETCH NEXT FROM cursor_pedidos 
INTO @CODPARC, @NUNOTA, @CODPARCOLD;

WHILE @@FETCH_STATUS = 0
BEGIN
	IF NOT EXISTS (
		SELECT 1 
		FROM SANKHYA_PRODUCAO.sankhya.TGFACT AS A WITH (NOLOCK)
		WHERE NUNOTA = @NUNOTA 
		AND OCORRENCIAS LIKE 'Código do parceiro alterado de%'
	)
		INSERT INTO SANKHYA_PRODUCAO.sankhya.TGFACT (NUNOTA, SEQUENCIA, DHOCOR, HRACT, OCORRENCIAS, DIGITADO, CODUSU)
		VALUES (@NUNOTA, 1, CAST(GETDATE() AS DATE), CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(2)) + RIGHT('0' + CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(2)), 2) + RIGHT('0' + CAST(DATEPART(SECOND, GETDATE()) AS VARCHAR(2)), 2),
		'Código do parceiro alterado de ' + CAST(@CODPARCOLD AS VARCHAR) + ' para ' + CAST(@CODPARC AS VARCHAR), 'N', 0);
	
	FETCH NEXT FROM cursor_pedidos 
	INTO @CODPARC, @NUNOTA, @CODPARCOLD;
END 
CLOSE cursor_pedidos
DEALLOCATE cursor_pedidos