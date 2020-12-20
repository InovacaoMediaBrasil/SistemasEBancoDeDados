USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_UPD_AD_PRODUTOLOJA]    Script Date: 25/09/2018 13:59:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	20/11/2013
	Description:	Valida o preço de venda do item na atualização/inserção no canal de vendas
	
	Author:			Guilherme Branco Stracini
	Change date:	04/05/2017
	Description:	Valida se o produto está com a flag que permite vender fora do KIT e adicionado WITH (NOLOCK)

	Author:			Guilherme Branco Stracini
	Change date:	2018-09-14
	Description:	Copia a descrição  (campo CARACTERISTICAS da TGFPRO) do produto para esta tabela caso esteja em branco e seja loja > 0
	
	Author:			Guilherme Branco Stracini
	Change date:	2018-09-24
	Description:	Cursor alterado para CURSOR LOCAL e modificado a validação por espaços em branco.

	============================================= */
ALTER TRIGGER [sankhya].[TRG_INC_UPD_AD_PRODUTOLOJA]
   ON  [sankhya].[AD_PRODUTOLOJA] 
   AFTER INSERT, UPDATE
AS 
DECLARE
@CODPROD INT,
@CODPRODPAI INT,
@CODLOJA INT,
@NOMELOJA VARCHAR(100),
@VLRVENDA MONEY,
@ATIVO CHAR(1),
@VENDAFORAKIT CHAR(1),
@POSSUIIMAGEM INT,
@SOLICITANTE CHAR(30),
@CODVOL VARCHAR(10),
@CODCAT INT,
@CODMARCA INT,
@ERRORMSG VARCHAR(4000)
BEGIN
	SET NOCOUNT ON;

	DECLARE cItens CURSOR LOCAL FOR
	SELECT I.CODPROD, P.AD_CODPAI, I.CODLOJA, I.CODCAT, M.CODMARCA, 
	P.CODVOL, I.ATIVO, L.NOMELOJA, P.VENCOMPINDIV, 
	CASE WHEN P.IMAGEM IS NULL THEN 0 ELSE 1 END AS IMAGEM
	FROM INSERTED AS I
	INNER JOIN sankhya.TGFPRO AS P WITH (NOLOCK) 
	ON P.CODPROD = I.CODPROD
	INNER JOIN sankhya.AD_LOJA AS L WITH (NOLOCK) 
	ON L.CODLOJA = I.CODLOJA
	INNER JOIN sankhya.AD_MULTILOJA AS M WITH (NOLOCK) 
	ON M.CODPROD = I.CODPROD;

	OPEN cItens;

	FETCH NEXT FROM cItens
	INTO @CODPROD, @CODPRODPAI, @CODLOJA, @CODCAT, @CODMARCA, @CODVOL, @ATIVO, @NOMELOJA, @VENDAFORAKIT, @POSSUIIMAGEM;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		IF @CODLOJA > 0
		AND EXISTS(
			SELECT 1 
			FROM AD_PRODUTOLOJA WITH (NOLOCK)
			WHERE CODPROD = @CODPROD 
			AND CODLOJA = @CODLOJA 
			AND (DESCRICAO IS NULL OR LEN(REPLACE(CAST(DESCRICAO AS VARCHAR(MAX)) , ' ', '')) = 0)
		)
		AND (@CODPRODPAI IS NULL OR @CODPRODPAI = 0 OR @CODPRODPAI = @CODPROD)
			UPDATE AD_PRODUTOLOJA
			SET DESCRICAO = (SELECT CARACTERISTICAS FROM TGFPRO WITH (NOLOCK) WHERE CODPROD = @CODPROD)
			WHERE CODLOJA = @CODLOJA
			AND CODPROD = @CODPROD;
		IF @CODLOJA = 0
			UPDATE AD_PRODUTOLOJA 
			SET DESCRICAO = 'Descrição (HTML) apenas para lojas VTEX (código canal de vendas maior que 0)'
			WHERE CODPROD = @CODPROD 
			AND CODLOJA = 0;
		IF @CODPRODPAI > 0 
		AND @CODLOJA > 0
		AND @CODPRODPAI != @CODPROD
			UPDATE AD_PRODUTOLOJA 
			SET DESCRICAO = 'Produto usa grade! Descrição (HTML) apenas para o produto pai ' + CAST(@CODPRODPAI AS VARCHAR) 
			WHERE CODPROD = @CODPROD 
			AND CODLOJA = @CODLOJA;
		IF @CODLOJA != 0
		AND EXISTS(SELECT 1 FROM TGFPRO WITH (NOLOCK) WHERE CODPROD = @CODPROD AND CARACTERISTICAS IS NULL)
		AND EXISTS(SELECT 1 FROM AD_PRODUTOLOJA WITH (NOLOCK) WHERE CODPROD = @CODPROD AND CODLOJA = @CODLOJA AND ATIVO = 'S' AND (DESCRICAO IS NULL OR LEN(REPLACE(CAST(DESCRICAO AS VARCHAR(MAX)) , ' ', '')) = 0))
		AND (@CODPRODPAI IS NULL OR @CODPRODPAI = 0 OR @CODPRODPAI = @CODPROD)
		BEGIN
			SET @ERRORMSG = 'Não foi possível copiar a descrição do produto ' + CAST(@CODPROD AS VARCHAR) + ' no canal de vendas ' + @NOMELOJA + ' porque ela está em branco no cadastro de produtos!';
			GOTO ERROR;
		END
		IF @CODLOJA != 0 AND @CODCAT IN (89, 106) AND @ATIVO = 'S'
		BEGIN
			DECLARE @NOMECAT VARCHAR(15);
			SET @NOMECAT = (CASE WHEN @CODCAT = 89 THEN 'Inativa' ELSE 'Integração' END);
			SET @ERRORMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' cadastrado na categoria ' + @NOMECAT + ', corrija a categoria antes de liberar no canal de vendas' + @NOMELOJA;
			GOTO ERROR;
		END
		IF @CODLOJA != 0 AND @CODMARCA = 2000032 AND @ATIVO = 'S'
		BEGIN
			SET @ERRORMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' cadastrado na marca Integração, corrija a marca antes de liberar no canal de vendas ' + @NOMELOJA;
			GOTO ERROR;
		END

		IF UPDATE(ATIVO)
		BEGIN
			IF @POSSUIIMAGEM = 0 
			AND @ATIVO = 'S' 
			AND @CODLOJA > 0
			BEGIN
				SET @ERRORMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' não possui imagem cadastrada!';
				GOTO ERROR;
			END		
			
			IF @VENDAFORAKIT != 'S'
			BEGIN
				SET @ERRORMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' não permite venda fora do KIT!';
				GOTO ERROR;
			END
		
			IF NOT EXISTS (SELECT 1 FROM TGFCUS WHERE CODPROD = @CODPROD) AND @ATIVO = 'S' AND @CODVOL != 'KT'
			BEGIN
				SET @ERRORMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' não possui preço de custo cadastrado!';
				GOTO ERROR;
			END

			IF @ATIVO = 'S' AND @CODPRODPAI > 0 AND @CODPRODPAI != @CODPROD
			AND NOT EXISTS (SELECT 1 FROM AD_PRODUTOLOJA AS P (NOLOCK) WHERE P.CODPROD = @CODPRODPAI AND P.CODLOJA = @CODLOJA AND P.ATIVO = 'S')
			BEGIN
				SELECT @NOMELOJA = NOMELOJA FROM AD_LOJA AS L WITH (NOLOCK) WHERE L.CODLOJA = @CODLOJA;
				SET @ERRORMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' é usa grade e o produto pai  ' + @CODPRODPAI + ' não está ativo no canal de vendas ' + @NOMELOJA;
				GOTO ERROR;
			END
		END
	
		IF UPDATE(VLRVENDA) OR UPDATE(VLRVENDADE)
			UPDATE AD_MULTILOJA SET DTMODIF = GETDATE(), ALTPRECO = 'S' 
			WHERE CODPROD = @CODPROD;
		
		IF UPDATE (CODCAT) OR UPDATE(ATIVO) AND @CODLOJA > 0
			UPDATE AD_MULTILOJA SET DTMODIF = GETDATE(), ALTLOJA = 'S' 
			WHERE CODPROD = @CODPROD;

		IF UPDATE (CODCAT) AND @CODLOJA > 0
			INSERT INTO AD_LOGALTERACOESVTEX (CODPROD, DTALTER, OCORRENCIA)
			VALUES (@CODPROD, GETDATE(), 'Categoria alterada')
		
		IF UPDATE (PESTTLOJA)
			UPDATE AD_MULTILOJA SET DTMODIF = GETDATE(), ALTESTOQUE = 'S' 
			WHERE CODPROD = @CODPROD;
	
		IF NOT UPDATE(VLRVENDA) OR NOT EXISTS(SELECT 1 FROM DELETED) 
		BEGIN		
			SELECT @VLRVENDA = EXC.VLRVENDA
			FROM sankhya.TGFEXC AS EXC 
			INNER JOIN sankhya.TGFTAB AS TAB ON (EXC.NUTAB = TAB.NUTAB) 
			INNER JOIN sankhya.AD_LOJA AS LOJA ON (LOJA.CODTAB = TAB.CODTAB)
			WHERE EXC.CODPROD = @CODPROD 
			AND LOJA.CODLOJA = @CODLOJA
			AND TAB.DTALTER IN (
				SELECT MAX(DTALTER) 
				FROM sankhya.TGFTAB T2 
				WHERE NUTAB IN 
					(SELECT NUTAB 
					FROM sankhya.TGFEXC 
					WHERE CODPROD = @CODPROD) 
				AND CODTAB = LOJA.CODTAB);
			
			IF(@VLRVENDA IS NULL AND @ATIVO = 'S')
			BEGIN
				SET @ERRORMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' não possui valor de venda na tabela de preços do canal de vendas ' + @NOMELOJA + '!';
				GOTO ERROR;
			END
			ELSE
				UPDATE AD_PRODUTOLOJA SET VLRVENDA = @VLRVENDA WHERE CODPROD = @CODPROD AND CODLOJA = @CODLOJA;
		END

		FETCH NEXT FROM cItens
		INTO @CODPROD, @CODPRODPAI, @CODLOJA, @CODCAT, @CODMARCA, @CODVOL, @ATIVO, @NOMELOJA, @VENDAFORAKIT, @POSSUIIMAGEM;

	END

	CLOSE cItens;
	DEALLOCATE cItens;

	RETURN

	ERROR: 
		RAISERROR(@ERRORMSG, 16, 1);

		SELECT @SOLICITANTE = program_name
		FROM MASTER.DBO.SYSPROCESSES
		WHERE SPID = @@SPID;

		IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
		OR @SOLICITANTE = 'MS SQLEM'
		OR @SOLICITANTE = 'MS SQL QUERY ANALYZER'
		OR UPPER(@SOLICITANTE) LIKE 'TOAD%'
			ROLLBACK  TRANSACTION;
END