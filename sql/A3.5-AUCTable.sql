declare @cleanup int, @blind int, @blindconstant float
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists AUCTable
end

--@blind = 1: add a random constant to every AUC in the table, so you can find the best D5cut without looking at the actual AUC
select @blind = 1
if (@blind = 1) begin
select @blindconstant = RAND() * 1000
end else begin
select @blindconstant = 0
end;

if object_id('AUCTable') is null begin
	with pairtable as (
		select a.usedonuts, a.trainingsetid, a.distancebinselectionid, a.testsetid, a.D5cut, a.fselectedresponders y1, b.fselectedresponders y2, a.fselectednonresponders x1, b.fselectednonresponders x2 from roc a
		inner join roc b
		on a.usedonuts = b.usedonuts
		and a.trainingsetid = b.trainingsetid
		and a.distancebinselectionid = b.distancebinselectionid
		and a.testsetid = b.testsetid
		and a.d5cut = b.d5cut
		and a.rownum = b.rownum - 1
	)
	select usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut, sum(0.5 * (x2-x1) * (y1+y2)) + @blindconstant AUC
	into AUCTable
	from pairtable
	group by usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut
	order by usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut
end;