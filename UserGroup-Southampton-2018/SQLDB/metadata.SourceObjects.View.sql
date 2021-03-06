USE [sdbamsdapdev001]
GO
/****** Object:  View [metadata].[SourceObjects]    Script Date: 06/06/2018 14:51:14 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [metadata].[SourceObjects]
AS

SELECT DISTINCT
	df.[DataFlowName],
	sot.[ObjectTypeName] AS 'SourceObjectType',
	so.[ObjectPrefix] AS 'SourcePrefix',
	so.[ObjectName] AS 'SourceObject',
	so.[ObjectAdditions] AS 'SourceObjectAdditions'
FROM
	[metadata].[Mappings] m
	INNER JOIN [metadata].[DataFlows] df
		ON m.[DataFlowId] = df.[DataFlowId]
	INNER JOIN [metadata].[Objects] so
		ON m.[SourceObjectId] = so.[ObjectId]
	INNER JOIN [metadata].[ObjectTypes] sot
		ON so.[ObjectTypeId] = sot.[ObjectTypeId]
GO
