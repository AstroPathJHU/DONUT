declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists DiscriminantsTable_allcells
end

--about 30 minutes for CS2 (using only trainingsetid = 1)
--12 for CSBMS01
--6 for CS34
--below is with lung and melanoma training sets
--35 for CS2
--21 for CS13
--24 for CS1
--18 for CSBMS01
--8 for CS34
--5 for CS36

if object_id('DiscriminantsTable_allcells') is null begin
	create table DiscriminantsTable_allcells (
		sampleid int not null,
		cellid bigint not null,
		ptype_lung tinyint not null,
		tdist_microns real not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		n0 int not null,
		n1 int not null,
		n2 int not null,
		n3 int not null,
		n4 int not null,
		n5 int not null,
		anyneighbors bit not null,
		anytrainingcells bit not null,
		D0_raw real,
		D1_raw real,
		D2_raw real,
		D3_raw real,
		D4_raw real,
		D5_raw real,
		D5 real,
		CONSTRAINT PK_DiscriminantsTable PRIMARY KEY (trainingsetid, distancebinselectionid, cellid)
	);

   declare @divide float;
   select @divide = tdistbinning from donut_constants;

   with c as (
        select *, floor(tdist_microns / @divide) * @divide lower_edge from AllNeighborsSummary
    ),	t as (
		select distinct trainingsetid, distancebinselectionid from TrainedModels
	), ProbabilitiesTable as (
		select c.sampleid, c.cellid, t.trainingsetid, d.distancebinselectionid, c.ptype_lung, c.tdist_microns,
			   c.count0, c.count1, c.count2, c.count3, c.count4, c.count5,
			   c.count0PD1posPDL1pos, c.count1PD1posPDL1pos, c.count2PD1posPDL1pos, c.count3PD1posPDL1pos, c.count4PD1posPDL1pos, c.count5PD1posPDL1pos,
			   c.count0PD1posPDL1neg, c.count1PD1posPDL1neg, c.count2PD1posPDL1neg, c.count3PD1posPDL1neg, c.count4PD1posPDL1neg, c.count5PD1posPDL1neg,
			   c.count0PD1negPDL1pos, c.count1PD1negPDL1pos, c.count2PD1negPDL1pos, c.count3PD1negPDL1pos, c.count4PD1negPDL1pos, c.count5PD1negPDL1pos,
			   c.count0PD1negPDL1neg, c.count1PD1negPDL1neg, c.count2PD1negPDL1neg, c.count3PD1negPDL1neg, c.count4PD1negPDL1neg, c.count5PD1negPDL1neg,
			   c.totalPD10, c.totalPD11, c.totalPD12, c.totalPD13, c.totalPD14, c.totalPD15,
			   c.totalPDL10, c.totalPDL11, c.totalPDL12, c.totalPDL13, c.totalPDL14, c.totalPDL15,
			   coalesce(h0.count, 0) n0,
			   coalesce(h1.count, 0) n1,
			   coalesce(h2.count, 0) n2,
			   coalesce(h3.count, 0) n3,
			   coalesce(h4.count, 0) n4,
			   coalesce(h5.count, 0) n5,
			   case when c.count0+c.count1+c.count2+c.count3+c.count4+c.count5>0 then 1 else 0 end anyneighbors,
			   case when coalesce(h0.count, 0) + coalesce(h1.count, 0) + coalesce(h2.count, 0) + coalesce(h3.count, 0) + coalesce(h4.count, 0) + coalesce(h5.count, 0)>0 then 1 else 0 end anytrainingcells
		from c inner join t on c.distancebinselectionid = t.distancebinselectionid
		       inner join DistanceBinSelection d on c.distancebinselectionid = d.distancebinselectionid
		       left join TrainedModels h0 on c.count0=h0.count0 and c.count1=h0.count1 and c.count2=h0.count2 and c.count3=h0.count3 and c.count4=h0.count4 and c.count5=h0.count5 and h0.ptype_lung=0 and c.lower_edge=h0.lower_edge and h0.trainingsetid = t.trainingsetid and h0.distancebinselectionid = d.distancebinselectionid
			   left join TrainedModels h1 on c.count0=h1.count0 and c.count1=h1.count1 and c.count2=h1.count2 and c.count3=h1.count3 and c.count4=h1.count4 and c.count5=h1.count5 and h1.ptype_lung=1 and c.lower_edge=h1.lower_edge and h1.trainingsetid = t.trainingsetid and h1.distancebinselectionid = d.distancebinselectionid
			   left join TrainedModels h2 on c.count0=h2.count0 and c.count1=h2.count1 and c.count2=h2.count2 and c.count3=h2.count3 and c.count4=h2.count4 and c.count5=h2.count5 and h2.ptype_lung=2 and c.lower_edge=h2.lower_edge and h2.trainingsetid = t.trainingsetid and h2.distancebinselectionid = d.distancebinselectionid
			   left join TrainedModels h3 on c.count0=h3.count0 and c.count1=h3.count1 and c.count2=h3.count2 and c.count3=h3.count3 and c.count4=h3.count4 and c.count5=h3.count5 and h3.ptype_lung=3 and c.lower_edge=h3.lower_edge and h3.trainingsetid = t.trainingsetid and h3.distancebinselectionid = d.distancebinselectionid
			   left join TrainedModels h4 on c.count0=h4.count0 and c.count1=h4.count1 and c.count2=h4.count2 and c.count3=h4.count3 and c.count4=h4.count4 and c.count5=h4.count5 and h4.ptype_lung=4 and c.lower_edge=h4.lower_edge and h4.trainingsetid = t.trainingsetid and h4.distancebinselectionid = d.distancebinselectionid
			   left join TrainedModels h5 on c.count0=h5.count0 and c.count1=h5.count1 and c.count2=h5.count2 and c.count3=h5.count3 and c.count4=h5.count4 and c.count5=h5.count5 and h5.ptype_lung=5 and c.lower_edge=h5.lower_edge and h5.trainingsetid = t.trainingsetid and h5.distancebinselectionid = d.distancebinselectionid
	)
	insert DiscriminantsTable_allcells (sampleid, cellid, ptype_lung, tdist_microns, trainingsetid, distancebinselectionid, n0, n1, n2, n3, n4, n5, anyneighbors, anytrainingcells, D0_raw, D1_raw, D2_raw, D3_raw, D4_raw, D5_raw, D5)
	select sampleid, cellid, ptype_lung, tdist_microns, p.trainingsetid, distancebinselectionid, n0, n1, n2, n3, n4, n5, anyneighbors, anytrainingcells,
	       case when anyneighbors&anytrainingcells=1 then n0*1./(n0+n1+n2+n3+n4+n5) else null end D0_raw,
		   case when anyneighbors&anytrainingcells=1 then n1*1./(n0+n1+n2+n3+n4+n5) else null end D1_raw,
		   case when anyneighbors&anytrainingcells=1 then n2*1./(n0+n1+n2+n3+n4+n5) else null end D2_raw,
		   case when anyneighbors&anytrainingcells=1 then n3*1./(n0+n1+n2+n3+n4+n5) else null end D3_raw,
		   case when anyneighbors&anytrainingcells=1 then n4*1./(n0+n1+n2+n3+n4+n5) else null end D4_raw,
		   case when anyneighbors&anytrainingcells=1 then n5*1./(n0+n1+n2+n3+n4+n5) else null end D5_raw,
		   case when anyneighbors&anytrainingcells=1 then n5*1./((n0+n1+n2+n3+n4)*cconstant+n5) else null end D5
		   from ProbabilitiesTable p
		   inner join cconstants cc on p.trainingsetid = cc.trainingsetid
	create index i_trainingsetid_sampleid_D5 on DiscriminantsTable_allcells(trainingsetid, sampleid, D5)
	create index i_trainingsetid_ptype_sampleid on DiscriminantsTable_allcells(trainingsetid, ptype_lung, sampleid)
	create index i_sampleid_anyneighbors_anytrainingcells on DiscriminantsTable_allcells(sampleid, anyneighbors, anytrainingcells)
	create index i_ptype_anyneighbors_anytrainingcells on DiscriminantsTable_allcells(ptype_lung, anyneighbors, anytrainingcells) include (sampleid, D5)
	CREATE NONCLUSTERED INDEX i_trainingsetid_distancebinselectionid_anyneighbors_anytrainingcells_D5 ON [dbo].[DiscriminantsTable_allcells] ([trainingsetid],[anyneighbors],[anytrainingcells],[distancebinselectionid],[D5]) INCLUDE ([sampleid],[ptype_lung],[tdist_microns])
end
go

create or alter view DiscriminantsTable_ptype as
select sampleid, cellid, ptype_lung, tdist_microns, 0 trainingsetid, 0 distancebinselectionid,
	   case when ptype_lung=0 then 1 else 0 end n0,
	   case when ptype_lung=1 then 1 else 0 end n1,
	   case when ptype_lung=2 then 1 else 0 end n2,
	   case when ptype_lung=3 then 1 else 0 end n3,
	   case when ptype_lung=4 then 1 else 0 end n4,
	   case when ptype_lung=5 then 1 else 0 end n5,
	   1 anyneighbors, 1 anytrainingcells,
	   case when ptype_lung=0 then 1 else 0 end D0_raw,
	   case when ptype_lung=1 then 1 else 0 end D1_raw,
	   case when ptype_lung=2 then 1 else 0 end D2_raw,
	   case when ptype_lung=3 then 1 else 0 end D3_raw,
	   case when ptype_lung=4 then 1 else 0 end D4_raw,
	   case when ptype_lung=5 then 1 else 0 end D5_raw,
	   case when ptype_lung=5 and sampleid not in (547, 566) then 1 else 0 end D5
from celltable
go

create or alter view DiscriminantsTable as
select *
from DiscriminantsTable_allcells
where anyneighbors=1 and anytrainingcells=1
union all
select *
from DiscriminantsTable_ptype
where anyneighbors=1 and anytrainingcells=1
go

create or alter view DiscriminantsTable_morecols as
select d.*, a.rdist_microns, a.count0, a.count1, a.count2, a.count3, a.count4, a.count5, a.count0PD1negPDL1neg, a.count0PD1negPDL1pos, a.count0PD1posPDL1neg, a.count0PD1posPDL1pos, a.count1PD1negPDL1neg, a.count1PD1negPDL1pos, a.count1PD1posPDL1neg, a.count1PD1posPDL1pos, a.count2PD1negPDL1neg, a.count2PD1negPDL1pos, a.count2PD1posPDL1neg, a.count2PD1posPDL1pos, a.count3PD1negPDL1neg, a.count3PD1negPDL1pos, a.count3PD1posPDL1neg, a.count3PD1posPDL1pos, a.count4PD1negPDL1neg, a.count4PD1negPDL1pos, a.count4PD1posPDL1neg, a.count4PD1posPDL1pos, a.count5PD1negPDL1neg, a.count5PD1negPDL1pos, a.count5PD1posPDL1neg, a.count5PD1posPDL1pos
from DiscriminantsTable d
left join AllNeighborsSummary a on d.cellid = a.cellid and d.distancebinselectionid = a.distancebinselectionid
go

create or alter view DiscriminantsTable_allcells_morecols as
select d.*, a.rdist_microns, a.count0, a.count1, a.count2, a.count3, a.count4, a.count5, a.count0PD1negPDL1neg, a.count0PD1negPDL1pos, a.count0PD1posPDL1neg, a.count0PD1posPDL1pos, a.count1PD1negPDL1neg, a.count1PD1negPDL1pos, a.count1PD1posPDL1neg, a.count1PD1posPDL1pos, a.count2PD1negPDL1neg, a.count2PD1negPDL1pos, a.count2PD1posPDL1neg, a.count2PD1posPDL1pos, a.count3PD1negPDL1neg, a.count3PD1negPDL1pos, a.count3PD1posPDL1neg, a.count3PD1posPDL1pos, a.count4PD1negPDL1neg, a.count4PD1negPDL1pos, a.count4PD1posPDL1neg, a.count4PD1posPDL1pos, a.count5PD1negPDL1neg, a.count5PD1negPDL1pos, a.count5PD1posPDL1neg, a.count5PD1posPDL1pos
from DiscriminantsTable_allcells d
left join AllNeighborsSummary a on d.cellid = a.cellid and d.distancebinselectionid = a.distancebinselectionid
go