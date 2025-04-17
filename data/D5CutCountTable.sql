with D5CutCountTableMerged as (
select * from donut_CS2.dbo.d5cutcounttablemerged
union all
select * from donut_CSBMS01.dbo.d5cutcounttablemerged
union all
select * from donut_CS34.dbo.d5cutcounttablemerged
), ResponseMerged as (
select * from donut_CS2.dbo.response
union all
select * from donut_CSBMS01.dbo.response
union all
select * from donut_CS34.dbo.response
)
select usedonuts, trainingsetid, testsetid, distancebinselectionid, d.sampleid, response, D5cut, ncells_tdistcut, nrandomcells_tdistcut,
1.0 * ncells_tdistcut / nrandomcells_tdistcut density
from D5CutCountTableMerged d
inner join ResponseMerged r on d.sampleid = r.sampleid
where abs(d5cut - 0.4499997) < 0.00001
or (distancebinselectionid = 0 and d5cut = 1)
order by trainingsetid, testsetid, usedonuts, distancebinselectionid, sampleid