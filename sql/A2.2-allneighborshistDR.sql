declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists AllNeighborsHistDR
end

--~9 minutes for CS13
--~3 minutes for CSBMS01
--~10 minutes for CS1
--~17 minutes for CS2
--~2 minutes for CS34
--1 minute for CS36
if object_id('AllNeighborsHistDR') is null begin
	create table AllNeighborsHistDR (
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
		CONSTRAINT PK_AllNeighborsHistDR PRIMARY KEY (ptype_lung, distancebin, cellid)
	)

	insert into AllNeighborsHistDR (sampleid, cellid, distancebin, ptype_lung, count, totalneighborPD1, totalneighborPDL1, countPD1posPDL1pos, countPD1posPDL1neg, countPD1negPDL1pos, countPD1negPDL1neg)
    select
		n.sampleid,
		c2 cellid,
		distancebin,
		ptype_translation.ptype_lung,
		cast(count(ptype_translation.ptype_local) as tinyint) count,
		sum(PD1column) totalneighborPD1,
		sum(PDL1column) totalneighborPDL1,
		cast(count(case when ct.PD1level > 0 and ct.PDL1level > 0 then 1 else null end) as tinyint) countPD1posPDL1pos,
		cast(count(case when ct.PD1level > 0 and ct.PDL1level = 0 then 1 else null end) as tinyint) countPD1posPDL1neg,
		cast(count(case when ct.PD1level = 0 and ct.PDL1level > 0 then 1 else null end) as tinyint) countPD1negPDL1pos,
		cast(count(case when ct.PD1level = 0 and ct.PDL1level = 0 then 1 else null end) as tinyint) countPD1negPDL1neg
    from NeighborsDR n
    inner join celltable ct on n.c1 = ct.cellid
	inner join ptype_translation on ptype1 = ptype_translation.ptype_local
    cross join DistanceBins
    where distancebinloweredge <= dist and dist < distancebinupperedge
    group by n.sampleid, c2, distancebin, ptype_translation.ptype_local, ptype_translation.ptype_lung
end
