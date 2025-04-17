declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists RocInputs
end

--few seconds
if object_id('RocInputs') is null begin
	create table RocInputs (
		usedonuts smallint not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		testsetid tinyint not null,
		D5cut real,
		celldensitycut float,
		Response varchar(64) not null,
		npass smallint not null,
		nsamples smallint not null,
		CONSTRAINT PK_RocInputs PRIMARY KEY (usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut, celldensitycut, Response)
	);

    with cuts as (
    select distinct usedonuts, trainingsetid, distancebinselectionid, D5cut, cast(ncells_tdistcut as float)/nrandomcells_tdistcut celldensitycut from D5CutCountTableMerged where nrandomcells_tdistcut!=0
    )
	insert RocInputs (usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut, celldensitycut, Response, npass, nsamples)
    select c.usedonuts, c.trainingsetid, c.distancebinselectionid, testsetid, c.D5cut, celldensitycut, Response, count(case when cast(ncells_tdistcut as float)/nrandomcells_tdistcut >= celldensitycut then 1 else null end) npass, count(c.sampleid) nsamples
    from D5CutCountTableMerged c
    right join response r on c.sampleid = r.sampleid
    inner join cuts on c.trainingsetid = cuts.trainingsetid and c.distancebinselectionid = cuts.distancebinselectionid and c.D5cut = cuts.D5cut and c.usedonuts = cuts.usedonuts
	where nrandomcells_tdistcut!=0
    group by c.usedonuts, c.trainingsetid, c.distancebinselectionid, testsetid, Response, c.D5cut, celldensitycut
end