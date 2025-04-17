CREATE OR ALTER PROCEDURE CreateViewsFromDatabase
    @dbname NVARCHAR(128)
AS
BEGIN
    truncate table WsiDbName
	insert into WsiDbName (WsiDbName)
	values (@dbname)

    -- Declare necessary variables
    DECLARE @tablename NVARCHAR(128);
    DECLARE @viewname NVARCHAR(128);
    DECLARE @sql NVARCHAR(MAX);

    -- Table names to process (you can adjust or extend this list as needed)
    DECLARE @tableList TABLE (TableName NVARCHAR(128));

    -- Insert the known table names into the table variable
    INSERT INTO @tableList (TableName)
    VALUES ('Annotations'), ('Cell'), ('CellPos'), ('CellTag'), ('Clinical'), ('ExprPhenotype'), ('MergeConfig'), ('Neighbors'), ('NeighborsDR'), ('Phenotype'), ('RandomCell'), ('Samples');

    -- Use a cursor to loop through the table names
    DECLARE table_cursor CURSOR FOR
    SELECT TableName
    FROM @tableList;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @tablename;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Construct the CREATE VIEW SQL statement dynamically
        SET @viewname = @tablename;
        SET @sql = N'
            CREATE OR ALTER VIEW ' + QUOTENAME(@viewname) + ' AS 
            SELECT * 
            FROM ' + QUOTENAME(@dbname) + '.dbo.' + QUOTENAME(@tablename);

        -- Execute the dynamic SQL in the current database context
        EXEC sp_executesql @sql;

        FETCH NEXT FROM table_cursor INTO @tablename;
    END;

    CLOSE table_cursor;
    DEALLOCATE table_cursor;
RETURN;
END;
go

declare @wsidbname nvarchar(max)
if (DB_NAME() = 'donut_CS13') begin
	SET @wsidbname = 'wsi13'
end
else if (DB_NAME() = 'donut_CS2') begin
	SET @wsidbname = 'wsi02'
end
else if (DB_NAME() = 'donut_CS1') begin
	SET @wsidbname = 'wsi01'
end
else if (DB_NAME() = 'donut_CSBMS01') begin
	SET @wsidbname = 'wsi11'
end
else if (DB_NAME() = 'donut_CS34') begin
	SET @wsidbname = 'wsi34'
end
else if (DB_NAME() = 'donut_CS36') begin
	SET @wsidbname = 'wsi36'
end
drop table if exists WsiDbName
create table WsiDbName (
  WsiDbName nvarchar(max)
);
exec CreateViewsFromDatabase @wsidbname

go