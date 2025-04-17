declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists D5CutCountTableMerged
end
go

declare @columns nvarchar(max), @sql nvarchar(max);

-- Get the common columns between the two tables
select @columns = string_agg(column_name, ', ')
from (
  select c.column_name
  from information_schema.columns c
  where c.table_name = 'DiscriminantsTable'
  and c.column_name in (
    -- Select columns that are present in both DiscriminantsTable and DiscriminantsTableDR
    select column_name
    from information_schema.columns
    where table_name = 'DiscriminantsTableDR'
  )
  -- The rows naturally come in the correct order of the columns
) as ordered_common_columns;

-- Create the view using the common columns
set @sql = '
create or alter view DiscriminantsTableMerged as
select -2 as usedonuts, ' + @columns + ' from DiscriminantsTable where ptype_lung != 5
union all
select -1 as usedonuts, ' + @columns + ' from DiscriminantsTable where ptype_lung = 5
union all
select 0 as usedonuts, ' + @columns + ' from DiscriminantsTable
union all
select 1 as usedonuts, ' + @columns + ' from DiscriminantsTableDR;
';

-- Execute the dynamic SQL to create the view
exec sp_executesql @sql;
go

--20 minutes for CS2
--6 for CSBMS01
--3 for CS34
--now with melanoma training set
--18 for CS1
--17 for CS13
--11 for CSBMS01
--27 for CS2
--5 for CS34
if object_id('D5CutCountTableMerged') is null begin
	drop table if exists #cuts, #norm, #RankedDiscriminantsTable, #cutsbysample, #ncells, #ncells_tdistcut, #ncells_intumor
	
	-- Generate D5 cuts
	--few seconds
	create table #cuts (
	    usedonuts smallint not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		D5cut real not null,
		CONSTRAINT PK_cuts PRIMARY KEY (usedonuts, trainingsetid, distancebinselectionid, D5cut)
	)
	insert #cuts (usedonuts, trainingsetid, distancebinselectionid, D5cut)
	select distinct usedonuts, trainingsetid, distancebinselectionid, D5 D5cut
	from DiscriminantsTableMerged;

	create table #norm (
		sampleid int not null primary key,
		nrandomcells int not null,
		nrandomcells_tdistcut int not null,
		nrandomcells_intumor int not null,
		tdistcut_microns float not null
	);

	-- Count random cells
	--instantaneous
	insert #norm (sampleid, nrandomcells, nrandomcells_tdistcut, nrandomcells_intumor, tdistcut_microns)
	select r.sampleid,
		   count(r.sampleid) nrandomcells,
		   count(case when tdist / 2 < tdistcut_microns then 1 else null end) nrandomcells_tdistcut,
		   count(case when tdist < 0 then 1 else null end) nrandomcells_intumor,
		   tdistcut_microns
	from LocalRandomCell r
	inner join tdistcut t on r.sampleid = t.sampleid
	group by r.sampleid, tdistcut_microns;

	-- Rank discriminants with usedonuts included
	--8 minutes for CS2
	with d as (
	  select d.*,
			 case when tdist_microns < 0 then 1 else 0 end as intumor,
			 case when tdist_microns < tdistcut_microns then 1 else 0 end as intdistcut
	  from DiscriminantsTableMerged d
	  inner join tdistcut t on d.sampleid = t.sampleid
	)
	select usedonuts, trainingsetid, distancebinselectionid, d.sampleid, D5, tdist_microns, intumor, intdistcut,
		   row_number() over (partition by trainingsetid, distancebinselectionid, sampleid, usedonuts order by D5 desc) as D5_rank,
		   case when intumor = 1 then row_number() over (partition by trainingsetid, distancebinselectionid, sampleid, intumor, usedonuts order by D5 desc) else null end as D5_tumor_rank,
		   case when intdistcut = 1 then row_number() over (partition by trainingsetid, distancebinselectionid, sampleid, intdistcut, usedonuts order by D5 desc) else null end as D5_tdistcut_rank
	into #RankedDiscriminantsTable
	from d;

	--7 minutes for CS2
	create clustered index idx on #RankedDiscriminantsTable(usedonuts, sampleid, trainingsetid, distancebinselectionid, D5);

	-- Compute cuts per sample
	create table #CutsBySample (
		usedonuts smallint not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		sampleid int not null,
		D5cut real not null,
		MaxD5 real not null,
		MaxD5_tdistcut real not null,
		MaxD5_intumor real not null,
		CONSTRAINT PK_cutsbysample PRIMARY KEY (usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut)
	)

	--This is quick, given the index created just above
	insert #CutsBySample (usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut, MaxD5, MaxD5_tdistcut, MaxD5_intumor)
	select usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut, MaxD5, MaxD5_tdistcut, MaxD5_intumor
	from #cuts c
	cross join (select distinct sampleid from #RankedDiscriminantsTable) s
	cross apply (
	  select coalesce(min(D5), 1) MaxD5
	  from #RankedDiscriminantsTable
	  where trainingsetid = c.trainingsetid
	    and distancebinselectionid = c.distancebinselectionid
		and D5 >= D5cut
		and sampleid = s.sampleid
		and usedonuts = c.usedonuts
	) rdt
	cross apply (
	  select coalesce(min(D5), 1) MaxD5_tdistcut
	  from #RankedDiscriminantsTable
	  where trainingsetid = c.trainingsetid
	    and distancebinselectionid = c.distancebinselectionid
		and D5 >= D5cut
		and sampleid = s.sampleid
		and intdistcut = 1
		and usedonuts = c.usedonuts
	) rdt2
	cross apply (
	  select coalesce(min(D5), 1) MaxD5_intumor
	  from #RankedDiscriminantsTable
	  where trainingsetid = c.trainingsetid
	    and distancebinselectionid = c.distancebinselectionid
		and D5 >= D5cut
		and sampleid = s.sampleid
		and intumor = 1
		and usedonuts = c.usedonuts
	) rdt3;

	-- Calculate cell counts per training set, sample, and D5cut
	create table #ncells (
		usedonuts smallint not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		sampleid int not null,
		D5cut real not null,
		ncells int not null,
		CONSTRAINT PK_ncells PRIMARY KEY (usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut)
	)
	--this is quick
	insert #ncells (usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut, ncells)
	select c.usedonuts, c.trainingsetid, c.distancebinselectionid, c.sampleid, c.D5cut,
		   coalesce(max(r.D5_rank), 0) ncells
	from #CutsBySample c
	left join #RankedDiscriminantsTable r
	  on c.trainingsetid = r.trainingsetid
	  and c.distancebinselectionid = r.distancebinselectionid
	  and c.sampleid = r.sampleid
	  and r.D5 = MaxD5
	  and r.usedonuts = c.usedonuts
	group by c.trainingsetid, c.distancebinselectionid, c.sampleid, c.D5cut, MaxD5, c.usedonuts;

	-- Similarly for tdistcut and intumor ranks
	create table #ncells_tdistcut (
		usedonuts smallint not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		sampleid int not null,
		D5cut real not null,
		ncells_tdistcut int not null,
		CONSTRAINT PK_ncells_tdistcut PRIMARY KEY (usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut)
	)
	insert #ncells_tdistcut (usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut, ncells_tdistcut)
	select c.usedonuts, c.trainingsetid, c.distancebinselectionid, c.sampleid, c.D5cut,
		   coalesce(max(r.D5_tdistcut_rank), 0) ncells_tdistcut
	from #CutsBySample c
	left join #RankedDiscriminantsTable r
	  on c.trainingsetid = r.trainingsetid
	  and c.distancebinselectionid = r.distancebinselectionid
	  and c.sampleid = r.sampleid
	  and r.D5 = MaxD5_tdistcut
	  and r.usedonuts = c.usedonuts
	group by c.trainingsetid, c.distancebinselectionid, c.sampleid, D5cut, MaxD5, c.usedonuts;

	create table #ncells_intumor (
		usedonuts smallint not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		sampleid int not null,
		D5cut real not null,
		ncells_intumor int not null,
		CONSTRAINT PK_ncells_intumor PRIMARY KEY (usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut)
	)
	insert #ncells_intumor (usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut, ncells_intumor)
	select c.usedonuts, c.trainingsetid, c.distancebinselectionid, c.sampleid, c.D5cut,
		   coalesce(max(r.D5_tumor_rank), 0) ncells_intumor
	from #CutsBySample c
	left join #RankedDiscriminantsTable r
	  on c.trainingsetid = r.trainingsetid
	  and c.distancebinselectionid = r.distancebinselectionid
	  and c.sampleid = r.sampleid
	  and r.D5 = MaxD5_intumor
	  and r.usedonuts = c.usedonuts
	group by c.trainingsetid, c.distancebinselectionid, c.sampleid, D5cut, MaxD5, c.usedonuts;

	create table D5CutCountTableMerged (
		usedonuts smallint not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		sampleid int not null,
		D5cut real not null,
		ncells int not null,
		ncells_tdistcut int not null,
		ncells_intumor int not null,
		nrandomcells int not null,
		nrandomcells_tdistcut int not null,
		nrandomcells_intumor int not null,
		CONSTRAINT PK_D5CutCountTable PRIMARY KEY (usedonuts, trainingsetid, distancebinselectionid, D5cut, sampleid)
	);

	-- Final result query
	--this is quick
	insert D5CutCountTableMerged(usedonuts, trainingsetid, distancebinselectionid, sampleid, D5cut, ncells, ncells_tdistcut, ncells_intumor, nrandomcells, nrandomcells_tdistcut, nrandomcells_intumor)
	select c.usedonuts, c.trainingsetid, c.distancebinselectionid, c.sampleid, c.D5cut,
		   ncells, ncells_tdistcut, ncells_intumor,
		   nrandomcells, nrandomcells_tdistcut, nrandomcells_intumor
	from #CutsBySample c
	inner join #ncells n1 on c.trainingsetid = n1.trainingsetid and c.distancebinselectionid = n1.distancebinselectionid and c.sampleid = n1.sampleid and c.D5cut = n1.D5cut and c.usedonuts = n1.usedonuts
	inner join #ncells_tdistcut n2 on c.trainingsetid = n2.trainingsetid and c.distancebinselectionid = n2.distancebinselectionid and c.sampleid = n2.sampleid and c.D5cut = n2.D5cut and c.usedonuts = n2.usedonuts
	inner join #ncells_intumor n3 on c.trainingsetid = n3.trainingsetid and c.distancebinselectionid = n3.distancebinselectionid and c.sampleid = n3.sampleid and c.D5cut = n3.D5cut and c.usedonuts = n3.usedonuts
	inner join #norm n on c.sampleid = n.sampleid;

	-- Drop temp tables
	drop table if exists #cuts, #norm, #RankedDiscriminantsTable, #cutsbysample, #ncells, #ncells_tdistcut, #ncells_intumor;

	--these indices are quick
	create index i_trainingsetid_sampleid_usedonuts on D5CutCountTableMerged(usedonuts, trainingsetid, sampleid);
	create index i_trainingsetid_D5cut_sampleid_usedonuts on D5CutCountTableMerged(usedonuts, trainingsetid, D5cut, sampleid);
end
go

create or alter view D5CutCountTable as
select * from D5CutCountTableMerged
where usedonuts = 0
go

create or alter view D5CutCountTableDR as
select * from D5CutCountTableMerged
where usedonuts = 1
go