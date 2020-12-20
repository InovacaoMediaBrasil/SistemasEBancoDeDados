BEGIN TRY
	BEGIN TRANSACTION

		SET NOCOUNT ON;

		DECLARE 
		@PEDORIGINAL INT;
		
		DECLARE cursor_orders CURSOR FAST_FORWARD FOR
			SELECT C.AD_PEDORIGINAL
			FROM sankhya.TGFCAB AS C WITH (NOLOCK)
			LEFT JOIN sankhya.AD_PEDIDOVTEXSCFLUXO AS F WITH (NOLOCK)
			ON (C.NUNOTA = F.NUNOTA OR F.NUNOTA IS NULL)
			WHERE C.CODTIPOPER = 502
			AND F.NUNOTA IS NULL 
			AND C.AD_CODREENVIO = 0
			AND YEAR(C.DTNEG) > 2016;

		OPEN cursor_orders;

		FETCH NEXT FROM cursor_orders
		INTO @PEDORIGINAL;
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			IF NOT EXISTS(
				SELECT 1
				FROM sankhya.AD_IMPORTACAOPEDPENDENTE WITH (NOLOCK)
				WHERE CODPED = @PEDORIGINAL
			)
			INSERT INTO sankhya.AD_IMPORTACAOPEDPENDENTE (CODPED, STATUS, CODUSU) 
			VALUES (@PEDORIGINAL, 'M', 0);  
			
			FETCH NEXT FROM cursor_orders
			INTO @PEDORIGINAL;			
		END
		CLOSE cursor_orders;
		DEALLOCATE cursor_orders;
	COMMIT
END TRY
BEGIN CATCH
	PRINT 'Erro';
	IF @@TRANCOUNT > 0
		ROLLBACK
	CLOSE cursor_orders;
	DEALLOCATE cursor_orders;
END CATCH