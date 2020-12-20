DECLARE 
@NUNOTA			INT,
@PEDORIGINAL	INT,
@ORDERID		VARCHAR(100),
@CODMODTRANSP	INT;

DECLARE cPedidos CURSOR FAST_FORWARD FOR
SELECT C.NUNOTA, C.AD_PEDORIGINAL, P.ORDERID, C.AD_IDMOD
FROM sankhya.TGFCAB AS C WITH (NOLOCK)
INNER JOIN sankhya.AD_PEDIDOVTEXSC AS P WITH (NOLOCK)
ON C.AD_PEDORIGINAL = P.PEDORIGINAL
WHERE C.CODTIPOPER = 550 
AND C.AD_IDMOD IN (10, 11)
AND NOT EXISTS (
	SELECT 1
	FROM sankhya.AD_CPENVIOS AS E WITH (NOLOCK)
	WHERE E.NUNOTA = C.NUNOTA
)

OPEN cPedidos;

FETCH NEXT FROM cPedidos INTO
@NUNOTA, @PEDORIGINAl, @ORDERID, @CODMODTRANSP;

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC sankhya.STP_GERAR_ETIQUETA_TRANSPORTADORA @NUNOTA, @PEDORIGINAL, @ORDERID, @CODMODTRANSP;
	FETCH NEXT FROM cPedidos INTO
	@NUNOTA, @PEDORIGINAl, @ORDERID, @CODMODTRANSP;
END
CLOSE cPedidos;
DEALLOCATE cPedidos;