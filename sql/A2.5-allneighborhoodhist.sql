declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists AllNeighborhoodHist
drop table if exists TrainedModels_local
drop table if exists TrainedModels
drop table if exists cconstants
end

--this takes about 15 seconds
declare @divide float;
select @divide = tdistbinning from donut_constants;
if object_id('AllNeighborhoodHist') is null begin
	create table AllNeighborhoodHist (
		sampleid int not null,
		distancebinselectionid tinyint not null,
		ptype_lung tinyint not null,
		lower_edge real not null,
		count0 tinyint not null,
		count1 tinyint not null,
		count2 tinyint not null,
		count3 tinyint not null,
		count4 tinyint not null,
		count5 tinyint not null,
		count int not null,
		CONSTRAINT PK_AllNeighborhoodHist PRIMARY KEY (sampleid, distancebinselectionid, lower_edge, count0, count1, count2, count3, count4, count5, ptype_lung)
	);
	insert into AllNeighborhoodHist (sampleid, distancebinselectionid, ptype_lung, lower_edge, count0, count1, count2, count3, count4, count5, count)
    select sampleid, distancebinselectionid, ptype_lung, floor(tdist_microns / @divide) * @divide lower_edge, count0, count1, count2, count3, count4, count5, count(cellid) count
    from AllNeighborsSummary
    group by sampleid, distancebinselectionid, ptype_lung, floor(tdist_microns / @divide) * @divide, count0, count1, count2, count3, count4, count5
end

--1 second
if object_id('TrainedModels_local') is null begin
	select trainingsetid, a.distancebinselectionid, ptype_lung, lower_edge, count0, count1, count2, count3, count4, count5, sum(count) count
	into TrainedModels_local
	from AllNeighborhoodHist a
	inner join trainingsets_local t
	on a.sampleid=t.sampleid and a.distancebinselectionid=t.distancebinselectionid
	group by trainingsetid, a.distancebinselectionid, ptype_lung, lower_edge, count0, count1, count2, count3, count4, count5
	order by trainingsetid, distancebinselectionid, ptype_lung, lower_edge, count0, count1, count2, count3, count4, count5
end

if object_id('TrainedModels') is null begin
	create table TrainedModels (
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		ptype_lung tinyint not null,
		lower_edge real not null,
		count0 tinyint not null,
		count1 tinyint not null,
		count2 tinyint not null,
		count3 tinyint not null,
		count4 tinyint not null,
		count5 tinyint not null,
		count int not null,
		CONSTRAINT PK_TrainedModels PRIMARY KEY (trainingsetid, lower_edge, count0, count1, count2, count3, count4, count5, ptype_lung)
	);

	INSERT INTO TrainedModels
	/*
		SELECT trainingsetid, distancebinselectionid, ptype_lung, lower_edge, count0, count1, count2, count3, count4, count5, count
		FROM donut_CS13.dbo.TrainedModels_local
	UNION ALL
	*/
		SELECT trainingsetid, distancebinselectionid, ptype_lung, lower_edge, count0, count1, count2, count3, count4, count5, count
		FROM donut_CS2.dbo.TrainedModels_local
	UNION ALL
		SELECT trainingsetid, distancebinselectionid, ptype_lung, lower_edge, count0, count1, count2, count3, count4, count5, count
		FROM donut_CS1.dbo.TrainedModels_local
end

if object_id('cconstants') is null begin
	create table cconstants (
		trainingsetid tinyint not null primary key,
		cconstant float not null
	);
	with signal as (
		select trainingsetid, sum(count) nCD8FoxP3
		from TrainedModels
		where ptype_lung=5
		and lower_edge<250
		group by trainingsetid
	), total as (
		select trainingsetid, sum(count) ntotal
		from TrainedModels
		where 1=1
		and lower_edge<250
		group by trainingsetid
	)
	insert into cconstants (trainingsetid, cconstant)
	select signal.trainingsetid, 1.0 * nCD8FoxP3 / ntotal cconstant
	from signal inner join total
	on signal.trainingsetid = total.trainingsetid
end