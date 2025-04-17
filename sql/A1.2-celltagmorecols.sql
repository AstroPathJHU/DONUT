declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists RandomCellInLymphNode
end

declare @celltagquery nvarchar(max)
select @celltagquery=N'
create or alter view CellTagMoreCols as
select *, '+dbo.fGetExprColumn('PDL1')+' as PDL1column, '+dbo.fGetExprColumn('PD1')+' as PD1column, '+dbo.fGetExprColumn('CD8')+' as CD8column'
if NOT EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'CellTag'
      AND COLUMN_NAME = 'rdist'
) begin
select @celltagquery = @celltagquery + ', 999999999999999.0 rdist'
end
select @celltagquery = @celltagquery + ' from CellTag';
exec sp_executesql @celltagquery

--1 minute for CS2
--instantaneous for anything with no lymph nodes
if object_id('RandomCellInLymphNode') is null begin
	create table RandomCellInLymphNode (
		cellid bigint not null primary key,
		inlymphnode bit not null
	)
	insert into RandomCellInLymphNode (cellid, inlymphnode)
	select cellid, ganno.STContains(pos) inlymphnode
	from RandomCell r
		 inner join Annotations a on a.sampleid=r.sampleid and lname='lymph node'
end

select @celltagquery=N'
create or alter view RandomCellMoreCols as
select r.*'
if NOT EXISTS (
    SELECT 1 
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'RandomCell'
      AND COLUMN_NAME = 'rdist'
) begin
select @celltagquery = @celltagquery + ', 999999999999999.0 rdist'
end
select @celltagquery = @celltagquery + ', coalesce(inlymphnode, 0) inlymphnode
from RandomCell r left join RandomCellInLymphNode rciln on r.cellid=rciln.cellid';
exec sp_executesql @celltagquery