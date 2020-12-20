USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_FATRLOTE]    Script Date: 05/05/2017 19:09:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [sankhya].[STP_FATRLOTE] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) WITH EXECUTE AS 'SANKHYA' AS
DECLARE
/* Variáveis da TGFCAB */
@NUNOTA INT,
@AD_STATUSPGTO VARCHAR(30),
@CODTIPOPER INT,
@P_NUNOTA INT,
@P_ULTIMO_CODIGO INT,
@CODEMP INT,
@NUMNOTA INT,
@SERIENOTA VARCHAR(1),
@CODCENCUS INT,
@HRMOV VARCHAR(12),
@CODPARC INT,
@CODTIPVENDA INT,
@AD_PEDORIGINAL INT,
@CODVEND INT,
@CODUSU INT,
@TIPFRETE VARCHAR(1),
@CIF_FOB  VARCHAR(1),
@CODNAT INT,
@CODPROJ INT,
@ISSRETIDO VARCHAR(1),
@IRFRETIDO VARCHAR(1),
@AD_CODCOMOSOUBE INT,

/* Variáveis da TGFITE */
@CODPROD INT,
@VLRUNIT DECIMAL,
@VLRTOT DECIMAL,
@QTDNEG DECIMAL,
@SEQUENCIA INT,
@SEQUENCIAORIG INT,
@NUTAB INT,
@CODLOCALORIG INT,
@CONTROLE VARCHAR(1),
@CODCFO INT,
@QTDENTREGUE DECIMAL,
@QTDCONFERIDA DECIMAL,
@VLRCUS DECIMAL,
@BASEICMS DECIMAL,
@VLRICMS DECIMAL,
@VLRDESC DECIMAL,
@BASESUBSTIT DECIMAL,
@VLRSUBST DECIMAL,
@ALIQICMS DECIMAL,
@PENDENTE VARCHAR(1),
@CODVOL VARCHAR(2), 
@RESERVA VARCHAR(2),
@ATUALIZAESTOQUE VARCHAR(1),
@STATUSNOTA_ITE VARCHAR(1),
@CODVEND_ITE INT,
@PERCDESC DECIMAL,
@CODUSU_ITE INT,
@CUSTO DECIMAL,
@CODPARCEXEC INT,
@SUMVLRTOT DECIMAL,
@ULTIMASEQUENCIA INT,


/* Variáveis temporárias */
@QTD INT,

/* Variáveis TGFVAR */
@SEQUENCIA_VAR INT



BEGIN


	/* Variáveis temporárias */
	set @QTD = 0

	/* Criar cursor para percorrer pedidos na AD_PEDIDASS */
	DECLARE PEDIDOSASS CURSOR
	FOR (SELECT NUNOTA FROM AD_PEDIDASS)
	OPEN PEDIDOSASS
	FETCH NEXT FROM PEDIDOSASS
	INTO @NUNOTA
	WHILE @@FETCH_STATUS = 0
	BEGIN
	
		/* Obtém dados do pedido */
			SELECT @CODPARC = CODPARC,
				   @CODEMP = CODEMP,
				   @CODTIPVENDA = CODTIPVENDA,
				   @AD_PEDORIGINAL = AD_PEDORIGINAL,
				   @NUMNOTA = NUMNOTA,
				   @SERIENOTA = SERIENOTA,
				   @CODCENCUS = CODCENCUS,
				   @CODVEND = CODVEND,
				   @CODUSU = CODUSU,
				   @TIPFRETE = TIPFRETE,
				   @CIF_FOB = CIF_FOB,
				   @CODNAT = CODNAT,
				   @CODPROJ = CODPROJ,
				   @ISSRETIDO = ISSRETIDO,
				   @IRFRETIDO = IRFRETIDO,
				   @AD_COMOSOUBE = AD_COMOSOUBE
			FROM sankhya.TGFCAB WITH (NOLOCK)
			WHERE NUNOTA = @NUNOTA

			/* Busca ultimo número para usar no NUNOTA */
			BEGIN TRANSACTION;
            SELECT @P_ULTIMO_CODIGO = ULTCOD FROM sankhya.TGFNUM WHERE ARQUIVO = 'TGFCAB';
            SET @P_NUNOTA = @P_ULTIMO_CODIGO + 1;
            UPDATE sankhya.tgfnum SET ULTCOD = @P_NUNOTA WHERE ARQUIVO = 'TGFCAB' AND ULTCOD = @P_ULTIMO_CODIGO; 
            COMMIT;
            
            /* Formata o horário da movimentação */
            SELECT @HRMOV = replace(convert(varchar, getdate(), 108),':','');		
            
            	
			BEGIN TRANSACTION;
			/* Cria o pedido na TGFCAB */
			INSERT INTO sankhya.TGFCAB (
            /*1*/nunota,codemp,numnota,serienota,codcencus,
            /*2*/dtneg, dtentsai,dtmov,hrmov,codempnegoc,
            /*3*/codparc,codtipoper,dhtipoper,CODTIPVENDA, DHTIPVENDA,
            /*4*/codvend,DTALTER,codusu,TIPFRETE,CIF_FOB,
            /*5*/CODNAT,CODPROJ,ISSRETIDO,IRFRETIDO,
            /*6*/CODPARCDEST, VLRNOTA,
            /*7*/AD_STATUSPGTO, AD_CODCOMOSOUBE,
            /*8*/AD_IDMOD, VLRFRETE, CODPARCTRANSP, AD_PEDORIGINAL
             ) VALUES (
             /*1*/@P_NUNOTA,@CODEMP,@NUMNOTA,@SERIENOTA ,@CODCENCUS,
             /*2*/CAST(SYSDATETIME() AS DATE),CAST(SYSDATETIME() AS DATE),CAST(SYSDATETIME() AS DATE), @HRMOV, @CODEMP,
             /*3*/@CODPARC,509,(SELECT MAX(DHALTER) FROM sankhya.TGFTOP WHERE CODTIPOPER = 509),@CODTIPVENDA,(SELECT MAX(DHALTER) FROM SANKHYA.TGFTPV WHERE CODTIPVENDA = @CODTIPVENDA),
             /*4*/@CODVEND,SYSDATETIME(),@P_CODUSU,@TIPFRETE,@CIF_FOB,
             /*5*/@CODNAT,@CODPROJ,@ISSRETIDO,@IRFRETIDO,
             /*6*/@CODPARC, 0.00,
             /*7*/@AD_STATUSPGTO, @AD_CODCOMOSOUBE,
             /*8*/6, 0.00, 36024, @AD_PEDORIGINAL);  

			/* Adiciona um evento no sistema na TGFACT */
			INSERT INTO sankhya.TGFACT
			(NUNOTA,SEQUENCIA, DHOCOR, HRACT,CODUSU,REFERENCIA,OCORRENCIAS,DIGITADO)
			values
			(@P_NUNOTA, ISNULL((SELECT MAX(SEQUENCIA) FROM TGFACT WHERE NUNOTA = @P_NUNOTA),0)+1, CAST(SYSDATETIME() AS DATE), @HRMOV,@P_CODUSU, 'N', 'EXPEDIÇÃO DE ASSINATURA GERADA','N')
			
			/* Obtem CODPROD da AD_PEDIDASS */
			SELECT @CODPROD = CODPROD FROM AD_PEDIDASS WHERE NUNOTA = @NUNOTA

			
			/* Obtém informações do item */
			SELECT 
					   @VLRUNIT = VLRUNIT,
					   @VLRTOT = VLRTOT,
					   @QTDNEG = QTDNEG,
					   @SEQUENCIA = SEQUENCIA,
					   @NUTAB = NUTAB,
					   @CODLOCALORIG = CODLOCALORIG,
					   @CONTROLE = CONTROLE,
					   @CODCFO = CODCFO,
					   @QTDENTREGUE = QTDENTREGUE,
					   @QTDCONFERIDA = QTDCONFERIDA,
					   @VLRCUS = VLRCUS,
					   @BASEICMS = BASEICMS,
					   @VLRICMS = VLRICMS,
					   @VLRDESC = VLRDESC,
					   @BASESUBSTIT = BASESUBSTIT,
					   @VLRSUBST = VLRSUBST,
					   @ALIQICMS = ALIQICMS,
					   @PENDENTE  = PENDENTE,
					   @CODVOL = CODVOL,
					   @ATUALIZAESTOQUE = ATUALESTOQUE,
					   @STATUSNOTA_ITE = STATUSNOTA,
					   @CODVEND_ITE = CODVEND,
					   @PERCDESC  = PERCDESC,
					   @CODUSU_ITE = CODUSU,
					   @CUSTO = CUSTO,
					   @CODPARCEXEC = CODPARCEXEC,
					   @RESERVA = RESERVA
					   FROM sankhya.TGFITE
					   WHERE NUNOTA = @NUNOTA AND CODPROD = @CODPROD
			
			
					/*Inclui item no pedido*/
					INSERT INTO sankhya.TGFITE (
					/*1*/NUTAB, NUNOTA, SEQUENCIA, CODEMP, CODPROD,
					/*2*/CODLOCALORIG, CONTROLE, USOPROD, CODCFO,QTDNEG,
					/*3*/QTDENTREGUE, QTDCONFERIDA, VLRUNIT, VLRTOT, VLRCUS,
					/*4*/BASEIPI, VLRIPI, BASEICMS, VLRICMS, VLRDESC,
					/*5*/BASESUBSTIT, VLRSUBST, ALIQICMS, ALIQIPI, PENDENTE,
					/*6*/CODVOL,ATUALESTOQUE, RESERVA,
					/*7*/STATUSNOTA, CODVEND,
					/*8*/VLRREPRED, VLRDESCBONIF, PERCDESC,
					/*9*/CODPARCEXEC, CUSTO, CODUSU, DTALTER
					) VALUES (
					/*1*/@NUTAB, @P_NUNOTA, ISNULL((SELECT MAX(i.SEQUENCIA) FROM sankhya.TGFCAB c INNER JOIN sankhya.TGFITE i on (c.NUNOTA = i.nunota) where c.NUNOTA = @P_NUNOTA),0)+1, @CODEMP, @CODPROD,
					/*2*/@CODLOCALORIG, @CONTROLE, 'R', @CODCFO, @QTDNEG,
					/*3*/@QTDENTREGUE, @QTDCONFERIDA, @VLRUNIT, @VLRTOT, @VLRCUS,
					/*4*/0, 0, @BASEICMS, @VLRICMS, @VLRDESC,
					/*5*/@BASESUBSTIT, @VLRSUBST, @ALIQICMS, 0, 'S',
					/*6*/@CODVOL, @ATUALIZAESTOQUE, @RESERVA,
					/*7*/@STATUSNOTA_ITE, @CODVEND_ITE, 
					/*8*/0, 0, @PERCDESC,
					/*9*/@CODPARCEXEC, @CUSTO, @P_CODUSU, CAST(SYSDATETIME() AS DATE)
										  );


				/* Inclui na TGFVAR */
				SELECT @SEQUENCIA_VAR = SEQUENCIA FROM sankhya.TGFITE where CODPROD = @CODPROD AND NUNOTA = @P_NUNOTA
				PRINT 'VAR: ' + CAST(@P_NUNOTA AS VARCHAR) + ' - ' + CAST(@SEQUENCIA_VAR AS VARCHAR) + ' - ' + CAST(@NUNOTA AS VARCHAR) + ' - ' + CAST(@SEQUENCIA AS VARCHAR)
				
				
					INSERT INTO SANKHYA.TGFVAR
					(NUNOTA
					,SEQUENCIA
					,NUNOTAORIG
					,SEQUENCIAORIG
					,QTDATENDIDA
					,STATUSNOTA)
					VALUES
					(@P_NUNOTA,
					@SEQUENCIA_VAR,
					@NUNOTA,
					@SEQUENCIA,
					NULL,
					'A');
			
				COMMIT;
			
				UPDATE sankhya.TGFITE SET
				PENDENTE = 'N',
				QTDENTREGUE = QTDNEG,
				QTDFAT = QTDNEG
				WHERE NUNOTA = @NUNOTA AND CODPROD = @CODPROD


				SELECT
				@SUMVLRTOT = SUM(VLRTOT)
				FROM sankhya.TGFITE
				WHERE NUNOTA = @P_NUNOTA	
				
				ALTER TABLE sankhya.TGFCAB DISABLE TRIGGER TRG_UPD_TGFCAB
				UPDATE sankhya.TGFCAB
			    SET VLRNOTA = @SUMVLRTOT,
					STATUSNOTA = 'L'
			    WHERE NUNOTA = @P_NUNOTA
			    ALTER TABLE sankhya.TGFCAB ENABLE TRIGGER TRG_UPD_TGFCAB
			    
			    set @QTD = @QTD+1
				
				DELETE FROM AD_PEDIDASS where NUNOTA = @NUNOTA
	
	FETCH NEXT FROM PEDIDOSASS
	INTO @NUNOTA    			
	END /*CURSOR*/
	CLOSE PEDIDOSASS
	DEALLOCATE PEDIDOSASS
	
	
	set @P_MENSAGEM = 'Foram geradas ' + cast(@qtd as varchar) + ' expedições com sucesso.'
	

END
