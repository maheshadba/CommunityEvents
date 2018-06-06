USE [sdbamsdapdev001]
GO
/****** Object:  StoredProcedure [metadata].[CreateUSQLExtractMergeTable]    Script Date: 06/06/2018 14:51:14 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [metadata].[CreateUSQLExtractMergeTable]
	(
	@DataFlowName VARCHAR(255),
	@CodeSnippet NVARCHAR(MAX) OUTPUT,
	@DebugMode BIT = 0
	)
AS

SET NOCOUNT ON;

BEGIN
	/*for development:
	DECLARE @DataFlowName VARCHAR(255) = 'PatientsRawToBase'
	DECLARE @CodeSnippet NVARCHAR(MAX) 
	DECLARE @DebugMode BIT = 1
	*/

	--defensive checks
	IF NOT EXISTS
		(
		SELECT * FROM [metadata].[DataFlows] WHERE [DataFlowName] = @DataFlowName
		)
		BEGIN
			RAISERROR('Data flow name does not exist.',16,1);
			RETURN;
		END

	---------------------------------------------------------------------------------------------
	--									extractor field list
	---------------------------------------------------------------------------------------------
	DECLARE @FieldList NVARCHAR(MAX) = ''

	SELECT
		@FieldList += '[' + [SourceAttribute] + '] ' + [SourceDataType] + ',' + CHAR(13) + CHAR(9) + CHAR(9)
	FROM
		[metadata].[CompleteMappings]
	WHERE
		[DataFlowName] = @DataFlowName

	SET @FieldList = [metadata].[RemoveLastComma](@FieldList)

	---------------------------------------------------------------------------------------------
	--									extractor type, path and additions
	---------------------------------------------------------------------------------------------
	DECLARE @SourceObjectType VARCHAR(128)
	DECLARE @SourceObjectAdditions VARCHAR(128)
	DECLARE @SourceObjectPath VARCHAR(128)

	SELECT
		@SourceObjectType = [metadata].[UpperCaseFirstChar]([SourceObjectType]),
		@SourceObjectAdditions = ISNULL([SourceObjectAdditions],''),
		@SourceObjectPath = '/' + [SourcePrefix] + '/' + [SourceObject] + '.' + [SourceObjectType]
	FROM
		[metadata].[SourceObjects]
	WHERE
		[DataFlowName] = @DataFlowName

	---------------------------------------------------------------------------------------------
	--									merge mappings
	---------------------------------------------------------------------------------------------
	DECLARE @SourceMergeMappings NVARCHAR(MAX) = ''
	DECLARE @TargetMergeMappings NVARCHAR(MAX) = ''
	DECLARE @SoureToTargetMerge NVARCHAR(MAX) = ''

	SELECT
		@SourceMergeMappings += 'source.[' + [SourceAttribute] + '] AS src' + [SourceAttribute] + ',' + CHAR(13) + CHAR(9) + CHAR(9) + CHAR(9)
	FROM
		[metadata].[CompleteMappings]
	WHERE
		[DataFlowName] = @DataFlowName

	SET @SourceMergeMappings = [metadata].[RemoveEndChar](@SourceMergeMappings)

	SELECT
		@TargetMergeMappings += 'Target.[' + [TargetAttribute] + '] AS tgt' + [TargetAttribute] + ',' + CHAR(13) + CHAR(9) + CHAR(9) + CHAR(9)
	FROM
		[metadata].[CompleteMappings]
	WHERE
		[DataFlowName] = @DataFlowName

	SET @TargetMergeMappings = [metadata].[RemoveLastComma](@TargetMergeMappings)

	SELECT
		@SoureToTargetMerge += '(' + [SourceDataType] + ')([checkFlag] ? [src' + [SourceAttribute] +'] : [tgt' + [TargetAttribute] + ']) AS ' + [TargetAttribute] + ',' + CHAR(13) + CHAR(9) + CHAR(9)
	FROM
		[metadata].[CompleteMappings]
	WHERE
		[DataFlowName] = @DataFlowName

	SET @SoureToTargetMerge = [metadata].[RemoveLastComma](@SoureToTargetMerge)

	---------------------------------------------------------------------------------------------
	--									primary keys
	---------------------------------------------------------------------------------------------
	DECLARE @SourceAttributePK NVARCHAR(MAX)
	DECLARE @TargetAttributePK NVARCHAR(MAX)

	SELECT
		@SourceAttributePK = [SourceAttribute]
	FROM
		[metadata].[CompleteMappings]
	WHERE
		[DataFlowName] = @DataFlowName
		AND [SourcePrimaryKey] IS NOT NULL

	SELECT
		@TargetAttributePK = [TargetAttribute]
	FROM
		[metadata].[CompleteMappings]
	WHERE
		[DataFlowName] = @DataFlowName
		AND [TargetPrimaryKey] IS NOT NULL

	---------------------------------------------------------------------------------------------
	--									target attributes
	---------------------------------------------------------------------------------------------
	DECLARE @TargetFieldList NVARCHAR(MAX) = ''

	SELECT
		@TargetFieldList += '[' + [TargetAttribute] + '],' + CHAR(13) + CHAR(9)
	FROM
		[metadata].[CompleteMappings]
	WHERE
		[DataFlowName] = @DataFlowName

	SET @TargetFieldList = [metadata].[RemoveLastComma](@TargetFieldList)

	---------------------------------------------------------------------------------------------
	--									output table
	---------------------------------------------------------------------------------------------
	DECLARE @TargetObjectPath VARCHAR(128)

	SELECT
		@TargetObjectPath = QUOTENAME([TargetPrefix]) + '.' + QUOTENAME([TargetObject])
	FROM
		[metadata].[TargetObjects]
	WHERE
		[DataFlowName] = @DataFlowName

	---------------------------------------------------------------------------------------------
	--								create final USQL script
	---------------------------------------------------------------------------------------------
	DECLARE @USQL NVARCHAR(MAX)

	SELECT
		@USQL = sp.[Script],
		@USQL = REPLACE(@USQL,'<##SourceObjectPath##>',@SourceObjectPath),
		@USQL = REPLACE(@USQL,'<##TargetObjectPath##>',@TargetObjectPath),


		@USQL = REPLACE(@USQL,'<##SourceAttributes##>',@FieldList),
		@USQL = REPLACE(@USQL,'<##SourceObjectType##>',@SourceObjectType),
		@USQL = REPLACE(@USQL,'<##SourceObjectAdditions##>',@SourceObjectAdditions),
		

		@USQL = REPLACE(@USQL,'<##SourceMergeMappings##>',@SourceMergeMappings),
		@USQL = REPLACE(@USQL,'<##TargetMergeMappings##>',@TargetMergeMappings),
		@USQL = REPLACE(@USQL,'<##SoureToTargetMerge##>',@SoureToTargetMerge),
		
		@USQL = REPLACE(@USQL,'<##SourceAttributePK##>',@SourceAttributePK),
		@USQL = REPLACE(@USQL,'<##TargetAttributePK##>',@TargetAttributePK),
		

		@USQL = REPLACE(@USQL,'<##TargetAttributes##>',@TargetFieldList),


		@CodeSnippet = @USQL
	FROM
		[metadata].[ScriptParts] sp
		INNER JOIN [metadata].[DataFlows] df
			ON sp.[ScriptId] = df.[ScriptId]
	WHERE
		df.[DataFlowName] = @DataFlowName

	IF @DebugMode = 1 EXEC [dbo].[usp_PrintBig] @USQL

END
GO
