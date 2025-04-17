declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists celltable_all
end

if object_id('celltable_all') is null begin
--12 minutes for CS13
--12 minutes for CS1
--20 minutes for CS2
--7 minutes for CSBMS01
--4 minutes for CS34
--2 minutes for CS36
    create table celltable_all (
		sampleid int not null,
		hpfid int not null,
		cellid bigint not null primary key,
		px float not null,
		py float not null,
		tdist_microns real not null,
		rdist_microns real not null,
		ExprPhenotype int not null,
		ptype_local tinyint not null,
		ptype_lung tinyint not null,
		PDL1column real not null,
		PD1column real not null,
		CD8column real not null,
		PD1level tinyint not null,
		PDL1level tinyint not null,
		inlymphnode bit not null,
		ptype20 tinyint not null
	);

	declare @PD1bit int, @PDL1bit int
    select @PD1bit = dbo.fGetExprBit('PD1'), @PDL1bit = dbo.fGetExprBit('PDL1');
    with tablewithquantiles as (
        select sampleid, hpfid, cellid, tdist / 2 tdist_microns, rdist / 2 rdist_microns, ExprPhenotype, ptype_local, ptype_lung, px, py, PDL1column, PD1column, CD8column,
        ntile(3) over (partition by ExprPhenotype & @PD1bit order by PD1column asc) PD1quantile,
        ntile(3) over (partition by ExprPhenotype & @PDL1bit order by PDL1column asc) PDL1quantile
        from CellTagMoreCols
		inner join ptype_translation on ptype = ptype_local
    ), tablewithlevels as (
		select tq.sampleid, tq.hpfid, tq.cellid, tq.px, tq.py, tq.tdist_microns, tq.rdist_microns, ExprPhenotype, ptype_local, ptype_lung, PDL1column, PD1column, CD8column,
		(case when ExprPhenotype & @PD1bit = 0 then 0 else PD1quantile end) as PD1level,
		(case when ExprPhenotype & @PDL1bit = 0 then 0 else PDL1quantile end) as PDL1level,
		coalesce(ganno.STContains(pos), 0) inlymphnode
		from tablewithquantiles tq
		inner join CellPos pos on tq.cellid = pos.cellid
		left join Annotations a on tq.sampleid=a.sampleid and a.lname='lymph node'
	)
	insert into celltable_all (sampleid, hpfid, cellid, px, py, tdist_microns, rdist_microns, ExprPhenotype, ptype_local, ptype_lung, PDL1column, PD1column, CD8column, PD1level, PDL1level, inlymphnode, ptype20)
	select tl.sampleid, tl.hpfid, tl.cellid, tl.px, tl.py, tl.tdist_microns, tl.rdist_microns, tl.exprPhenotype,
	       tl.ptype_local, tl.ptype_lung, tl.PDL1column, tl.PD1column, tl.CD8column, tl.PD1level, tl.PDL1level, tl.inlymphnode,
	       pl.ptype20
	from tablewithlevels tl
	left join ptype20_lookup pl on ptype_lung = pl.ptype and tl.PD1level = pl.PD1level and tl.PDL1level = pl.PDL1level

	create index i_sampleid on celltable_all(sampleid)
	create index i_ptype on celltable_all(ptype_lung) include (sampleid)
end
go

create or alter view celltable as
select * from celltable_all
where PDL1column is not null and PD1column is not null and CD8column is not null
go

create or alter view celltable_buggy as
select * from celltable_all
where not (PDL1column is not null and PD1column is not null and CD8column is not null)
