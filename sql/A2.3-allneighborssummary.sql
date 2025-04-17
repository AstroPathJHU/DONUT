declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists AllNeighborsSummary_bare
end

--~10 minutes for CSBMS01
--~20 minutes for CS2
--3 minutes for CS36
--7 minutes for CS34
if object_id('AllNeighborsSummary_bare') is null begin
	drop table if exists #tmp;

	declare @zero tinyint;
	set @zero = 0;

	with DistanceBinsToUse as (
		select * from DistanceBins
		where exists(select * from distancebinselection where distancebins & power(2, distancebin) > 0)
	)
	select dbtu.distancebin, a.cellid,
        coalesce(ptype0.count, @zero) count0,
        coalesce(ptype1.count, @zero) count1,
        coalesce(ptype2.count, @zero) count2,
        coalesce(ptype3.count, @zero) count3,
        coalesce(ptype4.count, @zero) count4,
        coalesce(ptype5.count, @zero) count5,
        coalesce(ptype0.countPD1posPDL1pos, @zero) count0PD1posPDL1pos,
        coalesce(ptype1.countPD1posPDL1pos, @zero) count1PD1posPDL1pos,
        coalesce(ptype2.countPD1posPDL1pos, @zero) count2PD1posPDL1pos,
        coalesce(ptype3.countPD1posPDL1pos, @zero) count3PD1posPDL1pos,
        coalesce(ptype4.countPD1posPDL1pos, @zero) count4PD1posPDL1pos,
        coalesce(ptype5.countPD1posPDL1pos, @zero) count5PD1posPDL1pos,
        coalesce(ptype0.countPD1posPDL1neg, @zero) count0PD1posPDL1neg,
        coalesce(ptype1.countPD1posPDL1neg, @zero) count1PD1posPDL1neg,
        coalesce(ptype2.countPD1posPDL1neg, @zero) count2PD1posPDL1neg,
        coalesce(ptype3.countPD1posPDL1neg, @zero) count3PD1posPDL1neg,
        coalesce(ptype4.countPD1posPDL1neg, @zero) count4PD1posPDL1neg,
        coalesce(ptype5.countPD1posPDL1neg, @zero) count5PD1posPDL1neg,
        coalesce(ptype0.countPD1negPDL1pos, @zero) count0PD1negPDL1pos,
        coalesce(ptype1.countPD1negPDL1pos, @zero) count1PD1negPDL1pos,
        coalesce(ptype2.countPD1negPDL1pos, @zero) count2PD1negPDL1pos,
        coalesce(ptype3.countPD1negPDL1pos, @zero) count3PD1negPDL1pos,
        coalesce(ptype4.countPD1negPDL1pos, @zero) count4PD1negPDL1pos,
        coalesce(ptype5.countPD1negPDL1pos, @zero) count5PD1negPDL1pos,
        coalesce(ptype0.countPD1negPDL1neg, @zero) count0PD1negPDL1neg,
        coalesce(ptype1.countPD1negPDL1neg, @zero) count1PD1negPDL1neg,
        coalesce(ptype2.countPD1negPDL1neg, @zero) count2PD1negPDL1neg,
        coalesce(ptype3.countPD1negPDL1neg, @zero) count3PD1negPDL1neg,
        coalesce(ptype4.countPD1negPDL1neg, @zero) count4PD1negPDL1neg,
        coalesce(ptype5.countPD1negPDL1neg, @zero) count5PD1negPDL1neg,
        coalesce(ptype0.totalneighborPD1, 0) totalPD10,
        coalesce(ptype1.totalneighborPD1, 0) totalPD11,
        coalesce(ptype2.totalneighborPD1, 0) totalPD12,
        coalesce(ptype3.totalneighborPD1, 0) totalPD13,
        coalesce(ptype4.totalneighborPD1, 0) totalPD14,
        coalesce(ptype5.totalneighborPD1, 0) totalPD15,
        coalesce(ptype0.totalneighborPDL1, 0) totalPDL10,
        coalesce(ptype1.totalneighborPDL1, 0) totalPDL11,
        coalesce(ptype2.totalneighborPDL1, 0) totalPDL12,
        coalesce(ptype3.totalneighborPDL1, 0) totalPDL13,
        coalesce(ptype4.totalneighborPDL1, 0) totalPDL14,
        coalesce(ptype5.totalneighborPDL1, 0) totalPDL15
		into #tmp
		from celltable a cross join DistanceBinsToUse dbtu
		                left join AllNeighborsHist ptype0 on a.cellid = ptype0.cellid and ptype0.ptype_lung = 0 and dbtu.distancebin = ptype0.distancebin
                        left join AllNeighborsHist ptype1 on a.cellid = ptype1.cellid and ptype1.ptype_lung = 1 and dbtu.distancebin = ptype1.distancebin
                        left join AllNeighborsHist ptype2 on a.cellid = ptype2.cellid and ptype2.ptype_lung = 2 and dbtu.distancebin = ptype2.distancebin
                        left join AllNeighborsHist ptype3 on a.cellid = ptype3.cellid and ptype3.ptype_lung = 3 and dbtu.distancebin = ptype3.distancebin
                        left join AllNeighborsHist ptype4 on a.cellid = ptype4.cellid and ptype4.ptype_lung = 4 and dbtu.distancebin = ptype4.distancebin
                        left join AllNeighborsHist ptype5 on a.cellid = ptype5.cellid and ptype5.ptype_lung = 5 and dbtu.distancebin = ptype5.distancebin

	create table AllNeighborsSummary_bare (
		distancebinselectionid tinyint not null,
		cellid bigint not null,
		count0 tinyint not null,
		count1 tinyint not null,
		count2 tinyint not null,
		count3 tinyint not null,
		count4 tinyint not null,
		count5 tinyint not null,
		count0PD1posPDL1pos tinyint not null,
		count1PD1posPDL1pos tinyint not null,
		count2PD1posPDL1pos tinyint not null,
		count3PD1posPDL1pos tinyint not null,
		count4PD1posPDL1pos tinyint not null,
		count5PD1posPDL1pos tinyint not null,
		count0PD1posPDL1neg tinyint not null,
		count1PD1posPDL1neg tinyint not null,
		count2PD1posPDL1neg tinyint not null,
		count3PD1posPDL1neg tinyint not null,
		count4PD1posPDL1neg tinyint not null,
		count5PD1posPDL1neg tinyint not null,
		count0PD1negPDL1pos tinyint not null,
		count1PD1negPDL1pos tinyint not null,
		count2PD1negPDL1pos tinyint not null,
		count3PD1negPDL1pos tinyint not null,
		count4PD1negPDL1pos tinyint not null,
		count5PD1negPDL1pos tinyint not null,
		count0PD1negPDL1neg tinyint not null,
		count1PD1negPDL1neg tinyint not null,
		count2PD1negPDL1neg tinyint not null,
		count3PD1negPDL1neg tinyint not null,
		count4PD1negPDL1neg tinyint not null,
		count5PD1negPDL1neg tinyint not null,
		totalPD10 real not null,
		totalPD11 real not null,
		totalPD12 real not null,
		totalPD13 real not null,
		totalPD14 real not null,
		totalPD15 real not null,
		totalPDL10 real not null,
		totalPDL11 real not null,
		totalPDL12 real not null,
		totalPDL13 real not null,
		totalPDL14 real not null,
		totalPDL15 real not null,
		CONSTRAINT PK_AllNeighborsSummary PRIMARY KEY (distancebinselectionid, cellid)
	);

	insert into AllNeighborsSummary_bare (
		distancebinselectionid, cellid,
		count0, count1, count2, count3, count4, count5,
		count0PD1posPDL1pos, count1PD1posPDL1pos, count2PD1posPDL1pos, count3PD1posPDL1pos, count4PD1posPDL1pos, count5PD1posPDL1pos,
		count0PD1posPDL1neg, count1PD1posPDL1neg, count2PD1posPDL1neg, count3PD1posPDL1neg, count4PD1posPDL1neg, count5PD1posPDL1neg,
		count0PD1negPDL1pos, count1PD1negPDL1pos, count2PD1negPDL1pos, count3PD1negPDL1pos, count4PD1negPDL1pos, count5PD1negPDL1pos,
		count0PD1negPDL1neg, count1PD1negPDL1neg, count2PD1negPDL1neg, count3PD1negPDL1neg, count4PD1negPDL1neg, count5PD1negPDL1neg,
		totalPD10, totalPD11, totalPD12, totalPD13, totalPD14, totalPD15,
		totalPDL10, totalPDL11, totalPDL12, totalPDL13, totalPDL14, totalPDL15
	)
    select distancebinselectionid, cellid,
           sum(count0) count0,
           sum(count1) count1,
           sum(count2) count2,
           sum(count3) count3,
           sum(count4) count4,
           sum(count5) count5,
           sum(count0PD1posPDL1pos) count0PD1posPDL1pos,
           sum(count1PD1posPDL1pos) count1PD1posPDL1pos,
           sum(count2PD1posPDL1pos) count2PD1posPDL1pos,
           sum(count3PD1posPDL1pos) count3PD1posPDL1pos,
           sum(count4PD1posPDL1pos) count4PD1posPDL1pos,
           sum(count5PD1posPDL1pos) count5PD1posPDL1pos,
           sum(count0PD1posPDL1neg) count0PD1posPDL1neg,
           sum(count1PD1posPDL1neg) count1PD1posPDL1neg,
           sum(count2PD1posPDL1neg) count2PD1posPDL1neg,
           sum(count3PD1posPDL1neg) count3PD1posPDL1neg,
           sum(count4PD1posPDL1neg) count4PD1posPDL1neg,
           sum(count5PD1posPDL1neg) count5PD1posPDL1neg,
           sum(count0PD1negPDL1pos) count0PD1negPDL1pos,
           sum(count1PD1negPDL1pos) count1PD1negPDL1pos,
           sum(count2PD1negPDL1pos) count2PD1negPDL1pos,
           sum(count3PD1negPDL1pos) count3PD1negPDL1pos,
           sum(count4PD1negPDL1pos) count4PD1negPDL1pos,
           sum(count5PD1negPDL1pos) count5PD1negPDL1pos,
           sum(count0PD1negPDL1neg) count0PD1negPDL1neg,
           sum(count1PD1negPDL1neg) count1PD1negPDL1neg,
           sum(count2PD1negPDL1neg) count2PD1negPDL1neg,
           sum(count3PD1negPDL1neg) count3PD1negPDL1neg,
           sum(count4PD1negPDL1neg) count4PD1negPDL1neg,
           sum(count5PD1negPDL1neg) count5PD1negPDL1neg,
           sum(totalPD10) totalPD10,
           sum(totalPD11) totalPD11,
           sum(totalPD12) totalPD12,
           sum(totalPD13) totalPD13,
           sum(totalPD14) totalPD14,
           sum(totalPD15) totalPD15,
           sum(totalPDL10) totalPDL10,
           sum(totalPDL11) totalPDL11,
           sum(totalPDL12) totalPDL12,
           sum(totalPDL13) totalPDL13,
           sum(totalPDL14) totalPDL14,
           sum(totalPDL15) totalPDL15
    from #tmp cross join DistanceBinSelection
	where (distancebins & power(2, distancebin)) > 0
	group by distancebinselectionid, cellid
	
	drop table if exists #tmp
end

go

create or alter view AllNeighborsSummary as
select distancebinselectionid, sampleid, a.cellid, ptype_lung, tdist_microns, rdist_microns, inlymphnode, PD1column PD1, PDL1column PDL1, PD1level, PDL1level, ptype20,
	    count0, count1, count2, count3, count4, count5,
	    count0PD1posPDL1pos, count1PD1posPDL1pos, count2PD1posPDL1pos, count3PD1posPDL1pos, count4PD1posPDL1pos, count5PD1posPDL1pos,
	    count0PD1posPDL1neg, count1PD1posPDL1neg, count2PD1posPDL1neg, count3PD1posPDL1neg, count4PD1posPDL1neg, count5PD1posPDL1neg,
	    count0PD1negPDL1pos, count1PD1negPDL1pos, count2PD1negPDL1pos, count3PD1negPDL1pos, count4PD1negPDL1pos, count5PD1negPDL1pos,
	    count0PD1negPDL1neg, count1PD1negPDL1neg, count2PD1negPDL1neg, count3PD1negPDL1neg, count4PD1negPDL1neg, count5PD1negPDL1neg,
	    totalPD10, totalPD11, totalPD12, totalPD13, totalPD14, totalPD15,
	    totalPDL10, totalPDL11, totalPDL12, totalPDL13, totalPDL14, totalPDL15
from AllNeighborsSummary_bare a
inner join celltable c on a.cellid=c.cellid

go