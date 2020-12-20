USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFCAB_BRINDES]    Script Date: 05/05/2017 19:39:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author: Rafael Turra Silva / Guilherme Branco
-- Create date: 25/05/2016
-- Description: Subtrai o valor de todos os brindes do valor final da nota
-- =============================================
ALTER TRIGGER [sankhya].[TRG_UPD_TGFCAB_BRINDES] ON [sankhya].[TGFCAB] AFTER UPDATE
AS 
DECLARE

/* Variáveis da TGFCAB */
@NUNOTA				INT,
@CODTIPOPER			INT,
@VLRTOT				FLOAT,
@VLRNOTA			FLOAT,
@VLRFRETE			FLOAT
BEGIN
	SET NOCOUNT ON;
	
	/* Obtem o código da operação */
	SELECT @NUNOTA = NUNOTA,
		   @CODTIPOPER = CODTIPOPER,
		   @VLRNOTA = VLRNOTA,
		   @VLRFRETE = VLRFRETE
	FROM INSERTED
		
	/* 1. Verifica se é um pedido com as operação de venda */
	IF (@CODTIPOPER IN (500,501,502,515))
	BEGIN
		-- DECLARA O VALOR PARA OS BRINDES
		DECLARE
		@VLRBRINDES FLOAT

		-- SELECIONA O VALOR TOTAL DOS BRINDES NA NOTA
		SELECT @VLRBRINDES = SUM(VLRTOT-VLRDESC)
		FROM INSERTED CAB
		INNER JOIN TGFITE AS ITE WITH (NOLOCK)
		ON ITE.NUNOTA = CAB.NUNOTA AND ITE.USOPROD = 'B'

		-- SELECIONA O VALOR TOTAL DOS PRODUTOS DA NOTA
		SELECT @VLRTOT = SUM(VLRTOT-VLRDESC)
		FROM INSERTED AS CAB
		INNER JOIN TGFITE AS ITE WITH (NOLOCK)
		ON ITE.NUNOTA = CAB.NUNOTA AND ITE.USOPROD = 'R'

		-- VERIFICA SE REALMENTE TEM BRINDES E VALOR DA NOTA É MAIOR QUE OS PRODUTOS (SEM BRINDE) MAIS FRETE, EXECUTA O UPDATE
		IF (@VLRBRINDES > 0 AND @@NESTLEVEL < 3 AND (@VLRNOTA > @VLRTOT + @VLRFRETE))
				-- ALTERA O VALOR DA NOTA PARA DESCONTAR O BRINDE
				UPDATE TGFCAB SET VLRNOTA = (VLRNOTA - @VLRBRINDES) WHERE NUNOTA = @NUNOTA
	END

END
		



