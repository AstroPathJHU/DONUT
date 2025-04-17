declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists AllNeighborsHist
end

if object_id('AllNeighborsHist') is null begin
--8 minutes for CSBMS01
--11 minutes for CS13
--25 minutes for CS2
--14 minutes for CS1
--5 minutes for CS34
--3 minutes for CS36
	create table AllNeighborsHist (
		sampleid int not null,
		cellid bigint not null,
		distancebin tinyint not null,
		ptype_lung tinyint not null,
		count tinyint not null,
		totalneighborPD1 real not null,
		totalneighborPDL1 real not null,
		countPD1posPDL1pos tinyint not null,
		countPD1posPDL1neg tinyint not null,
		countPD1negPDL1pos tinyint not null,
		countPD1negPDL1neg tinyint not null,
		CONSTRAINT PK_AllNeighborsHist PRIMARY KEY (ptype_lung, distancebin, cellid)
	)

	insert into allneighborshist (sampleid, cellid, distancebin, ptype_lung, count, totalneighborPD1, totalneighborPDL1, countPD1posPDL1pos, countPD1posPDL1neg, countPD1negPDL1pos, countPD1negPDL1neg)
    select
		n.sampleid,
		c1 cellid,
		distancebin,
		ptype_translation.ptype_lung,
		cast(count(ptype_translation.ptype_local) as tinyint) count,
		sum(ct2.PD1column) totalneighborPD1,
		sum(ct2.PDL1column) totalneighborPDL1,
		cast(count(case when ct2.PD1level > 0 and ct2.PDL1level > 0 then 1 else null end) as tinyint) countPD1posPDL1pos,
		cast(count(case when ct2.PD1level > 0 and ct2.PDL1level = 0 then 1 else null end) as tinyint) countPD1posPDL1neg,
		cast(count(case when ct2.PD1level = 0 and ct2.PDL1level > 0 then 1 else null end) as tinyint) countPD1negPDL1pos,
		cast(count(case when ct2.PD1level = 0 and ct2.PDL1level = 0 then 1 else null end) as tinyint) countPD1negPDL1neg
    from Neighbors n
    inner join celltable ct1 on n.c1 = ct1.cellid
    inner join celltable ct2 on n.c2 = ct2.cellid
	inner join ptype_translation on ptype2 = ptype_translation.ptype_local
    inner join DistanceBins on distancebinloweredge <= dist and dist < distancebinupperedge
    group by n.sampleid, c1, distancebin, ptype_translation.ptype_local, ptype_translation.ptype_lung
end