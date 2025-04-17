declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists response
end

declare @wsidbname nvarchar(max)
select @wsidbname = wsidbname from WsiDbName

if object_id('response') is null begin
	create table response (
		SampleID int not null,
		SlideID varchar(50) not null,
		testsetid tinyint not null,
		Response varchar(64) not null,
		CONSTRAINT PK_Response PRIMARY KEY (testsetid, SampleID)
	);

	DECLARE @ResponseFormula NVARCHAR(MAX);
	DECLARE @CompareSlideID NVARCHAR(MAX);
	DECLARE @SqlQuery NVARCHAR(MAX);

	-- Determine the response formula based on the database name
	IF (@wsidbname = 'wsi02') BEGIN
		SET @ResponseFormula = 'LOWER(c.tx1_response)';
	END ELSE IF (@wsidbname = 'wsi13' or @wsidbname = 'wsi01' or @wsidbname = 'wsi34') BEGIN
		SET @ResponseFormula = 'LOWER(c.response)';
	END ELSE IF (@wsidbname = 'wsi11') BEGIN
		SET @ResponseFormula = 'case
		    when (c.BORINV = ''PR'' and testsetname not like ''%OS'') or (c.OSCNSR = 1 and testsetname like ''%OS'')
			    then ''responder''
			when (c.BORINV = ''PD'' and testsetname not like ''%OS'') or (c.OSCNSR = 0 and testsetname like ''%OS'')
				then ''non-responder''
			else null
		end'
	END ELSE IF (@wsidbname = 'wsi36') BEGIN
		SET @ResponseFormula = 'case
			when ((c.BORINV = ''PR'' or c.BORINV = ''CR'') and testsetname not like ''%OS'') or (c.[OS.CNSR] = 1 and testsetname like ''%OS'')
			    then ''responder''
			when (c.BORINV = ''PD'' and testsetname not like ''%OS'') or (c.[OS.CNSR] = 0 and testsetname like ''%OS'')
				then ''non-responder''
			else null
		end'
	END ELSE BEGIN
		RAISERROR ('Unknown db name %s', 16, 1, @wsidbname);
		RETURN;
	END

	IF (@wsidbname = 'wsi11') BEGIN
		SET @CompareSlideID = 'INNER JOIN samplestouse s ON s.SlideID LIKE c.SlideID + ''_%'''
	END ELSE IF (@wsidbname = 'wsi36') BEGIN
		drop table if exists clinical_samples_translation
		CREATE TABLE clinical_samples_translation (
			SampleID INT PRIMARY KEY NOT NULL,
			SlideID VARCHAR(255) NOT NULL,
			vendor_block_id VARCHAR(255) NOT NULL
		);
		INSERT INTO clinical_samples_translation (SampleID, SlideID, vendor_block_id) 
		VALUES
		(1194, 'AP0360001', 'A008AX943-001'),
		(1195, 'AP0360002', 'ML1603480_0'),
		(1196, 'AP0360003', 'ML1610721_0'),
		(1197, 'AP0360004', 'ML1610731_0'),
		(1198, 'AP0360005', 'ML1610732_0'),
		(1199, 'AP0360006', 'ML1610737_0'),
		(1200, 'AP0360007', 'ML1610742_0'),
		(1201, 'AP0360008', 'ML1610744_0'),
		(1202, 'AP0360009', 'ML1610762_0'),
		(1203, 'AP0360010', 'ML1610765_0'),
		(1204, 'AP0360011', 'ML1610781_0'),
		(1205, 'AP0360012', 'ML1610788_0'),
		(1206, 'AP0360013', 'ML1716598_0');
		SET @CompareSlideID = 'INNER JOIN clinical_samples_translation t on c.vendor_block_id = t.vendor_block_id INNER JOIN samplestouse s ON t.SlideID = s.SlideID'
	END ELSE BEGIN
		SET @CompareSlideID = 'INNER JOIN samplestouse s ON c.SlideID = s.SlideID'
	END

	SET @SqlQuery = N'
		INSERT INTO response (SampleID, SlideID, testsetid, Response)
		SELECT s.sampleid, s.slideid, testsetid, ' + @ResponseFormula + ' AS response
		FROM clinical c
		' + @CompareSlideID + ';';

	-- Print the query for debugging (optional)
	PRINT @SqlQuery;

	-- Execute the dynamic SQL query
	EXEC sp_executesql @SqlQuery;
end