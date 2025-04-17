declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists Roc
end

--instantaneous
if object_id('Roc') is null begin
	create table Roc (
		usedonuts smallint not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		testsetid tinyint not null,
		D5cut real not null,
		fselectedresponders real not null,
		fselectednonresponders real not null,
		rownum smallint not null,
		CONSTRAINT PK_Roc PRIMARY KEY (usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut, rownum)
	);

    with roctmp as (
    select distinct r.usedonuts, r.trainingsetid, r.distancebinselectionid, r.testsetid, r.D5cut, r.npass nselectedresponders, r.nsamples nresponders, nr.npass nselectednonresponders, nr.nsamples nnonresponders
    from RocInputs r
    inner join RocInputs nr
    on r.Response = 'responder' and nr.Response = 'non-responder' and r.D5cut = nr.D5cut and r.celldensitycut = nr.celldensitycut and r.usedonuts = nr.usedonuts and r.trainingsetid = nr.trainingsetid and r.distancebinselectionid = nr.distancebinselectionid and r.testsetid = nr.testsetid
    )
	insert Roc (usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut, fselectedresponders, fselectednonresponders, rownum)
    select usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut, 1.0*nselectedresponders / nresponders fselectedresponders, 1.0*nselectednonresponders / nnonresponders fselectednonresponders, ROW_NUMBER() over (partition by usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut order by nselectedresponders, nselectednonresponders) rownum
    from (
    select distinct usedonuts, trainingsetid, distancebinselectionid, testsetid, D5cut, 0 nselectedresponders, nresponders, 0 nselectednonresponders, nnonresponders from roctmp
    union
    select * from roctmp
    ) x;
end