with RocMerged as (
select * from donut_CS2.dbo.Roc where abs(d5cut - 0.4499997) < 0.00001
union all
select * from donut_CSBMS01.dbo.Roc where abs(d5cut - 0.4499997) < 0.00001
union all
select * from donut_CS34.dbo.Roc
)
select * from RocMerged
where abs(d5cut - 0.4499997) < 0.00001
or (distancebinselectionid = 0 and d5cut = 1)
order by trainingsetid, testsetid, usedonuts, rownum