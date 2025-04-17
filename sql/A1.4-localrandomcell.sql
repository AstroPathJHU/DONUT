declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists LocalRandomCell
end

--6 minutes for CS2
--1 minute for CSBMS01
--1 minute for CS34
--4 minutes for CS13
--30 seconds for CS36
if object_id('LocalRandomCell') is null begin
	create table LocalRandomCell (
		sampleid int not null,
		cellid bigint not null primary key,
		hpfid int not null,
		px float not null,
		py float not null,
		pos geometry not null,
		tdist real not null,
		rdist real not null
	);
	insert into LocalRandomCell (sampleid, cellid, hpfid, px, py, pos, tdist, rdist)
	select sampleid, cellid, hpfid, px, py, pos, tdist, rdist
	from RandomCellMoreCols
	create index i_LocalRandomCell_sampleid on LocalRandomCell(sampleid) include (tdist)
end
