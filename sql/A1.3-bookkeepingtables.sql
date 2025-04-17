declare @cleanup int
select @cleanup = 1
if (@cleanup = 1) begin
drop table if exists ptype_translation
drop table if exists ptype20_lookup
drop table if exists tdistcut
drop table if exists tdistcut_regression
drop table if exists trainingsets_local
drop table if exists samplestouse
drop table if exists DistanceBins
drop table if exists DistanceBinSelection
drop table if exists donut_constants
end

if object_id('ptype_translation') is null begin
	CREATE TABLE ptype_translation (
		ptype_lung TINYINT NOT NULL UNIQUE,
		ptype_local TINYINT NOT NULL PRIMARY KEY,
		Phenotype VARCHAR(50)
	);

	INSERT INTO ptype_translation (ptype_lung, ptype_local, Phenotype)
	select plung.ptype ptype_lung, plocal.ptype ptype_local, plung.Phenotype
	from wsi02.dbo.phenotype plung
	full join dbo.Phenotype plocal
	on plung.phenotype = plocal.phenotype
	or exists(select 1 from WsiDbName where lower(WsiDbName) in ('wsi11', 'wsi34', 'wsi36')) and plung.Phenotype = 'CD163' and plocal.Phenotype = 'CD68'
end

if object_id('ptype20_lookup') is null begin
	CREATE TABLE ptype20_lookup (
		ptype TINYINT,
		PD1level TINYINT,
		PDL1level TINYINT,
		ptype20 TINYINT,
		PRIMARY KEY (ptype, PD1level, PDL1level)
	);

	DROP TABLE IF EXISTS #ptype, #PD1level, #PDL1level;
	CREATE TABLE #ptype (ptype TINYINT);
	CREATE TABLE #PD1level (PD1level TINYINT);
	CREATE TABLE #PDL1level (PDL1level TINYINT);

	INSERT INTO #ptype VALUES (0), (1), (2), (3), (4), (5);
	INSERT INTO #PD1level VALUES (0), (1), (2), (3);
	INSERT INTO #PDL1level VALUES (0), (1), (2), (3);

	INSERT INTO ptype20_lookup (ptype, PD1level, PDL1level, ptype20)
	SELECT 
		p.ptype,
		pd1.PD1level,
		pdl.PDL1level,
		dbo.ptype20(p.ptype, pd1.PD1level, pdl.PDL1level) AS ptype20
	FROM #ptype p
	CROSS JOIN #PD1level pd1
	CROSS JOIN #PDL1level pdl;

	DROP TABLE #ptype, #PD1level, #PDL1level;
end

if object_id('tdistcut') is null begin
	--this table is used to determine the distance cutoffs for cells from the tumor boundary
	CREATE TABLE tdistcut (
		sampleid int NOT NULL PRIMARY KEY,
		tdistcut_microns float not null
	);

	insert into tdistcut (sampleid, tdistcut_microns)
	select sampleid, case
		when slideid = 'L12_1' then 0       --this sample is a lymph node, and the area outside the tumor looks different from other tissue
		when slideid = 'L10_1' then 1.7E308 --small sample with a couple of cuts, we use the whole thing
		else 250
	end tdistcut_microns
	from Samples
end

if object_id('tdistcut_regression') is null begin
	--different convention for distance cutoffs: the distance has to be within
	--tdistcut from the tumor boundary OR within rdistcut from the regression
	--boundary.  Where there is regression, set tdistcut = rdistcut = 0, meaning
	--that we use everything inside either the tumor or the regression.
	--Otherwise it's the same as tdistcut.
	CREATE TABLE tdistcut_regression (
		sampleid int NOT NULL PRIMARY KEY,
		tdistcut_microns float not null,
		rdistcut_microns float not null
	);

	insert into tdistcut_regression (sampleid, tdistcut_microns, rdistcut_microns)
	select s.sampleid,
	case
		when lname is not null then 0       --where there is regression, tdistcut = 0
		when slideid = 'L12_1' then 0       --this sample is a lymph node, and the area outside the tumor looks different from other tissue
		when slideid = 'L10_1' then 1.7E308 --small sample with a couple of cuts, use the whole thing
		else 250
	end tdistcut_microns,
	case
		when lname is not null then 0       --where there is regression, rdistcut = 0
		else -1.7E308                       --otherwise, rdistcut = -1.7E308, meaning that no cells are included by rdist < rdistcut and we only use tdistcut
	end rdistcut_microns
	from Samples s
	left join Annotations a on s.sampleid=a.sampleid and a.lname = 'regression'
end

if object_id('samplestouse') is null begin
	create table samplestouse (
		SlideID varchar(64) not null,
		SampleID int not null,
		testsetname varchar(64) not null,
		testsetid tinyint not null,
		CONSTRAINT PK_samplestouse PRIMARY KEY (testsetid, SampleID)
	);
	with tmp as (
		select SlideID, SampleID,
		abs(sin(sampleid * 48373 + 2842) * 48975) sine, --will use sine % 1 as a random number
		case
			when slideid in ('L10_1', 'L12_1', 'AP0150001', 'AP0150024', 'AP0150046', 'L1_1', 'L2_2', 'L3_1', 'L4_1', 'L7_1', 'L8_1', 'L9_1', 'L11_1', 'L13_2', 'L14_2', 'L17_1', 'L19_1', 'L20_3', 'L34_3', 'L35_3', 'L37_2', 'L51_1', 'L53_1', 'L18_4', 'AP0150027')
				then 'lung axis pre-treatment'
			when slideid in ('ML1610913_BMS167_5_21', 'ML1610859_BMS_128_5_20', 'ML1610825_BMS209_5_21', 'ML1610962_BMS_189_5_20', 'ML1610932_BMS152_5_28', 'ML1610905_BMS106_5_28', 'A939AW500_BMS219_5_28', 'ML1716644_BMS138_5_22', 'ML1716677_BMS149_5_21', 'ML1610931_BMS_155_5_20', 'A938AW145_BMS221_5_28', 'ML1716639_BMS142_5_23', 'ML1610907_BMS112_5_21', 'ML1603654_BMS212_5_25')
				then 'lung validation'
			when SampleID in (901, 902, 903, 904, 905, 906, 907, 908, 909, 910, 911, 912, 913, 914, 915, 916, 917, 918, 919, 920)
				then 'lung akoya'
			when sampleid in (630, 638, 643, 644, 580, 582, 583, 626, 627, 629, 631, 632, 635, 640, 642, 653, 655, 668, 669, 673, 675, 676) 
			    --and ((select BORINV from clinical where samples.slideid like clinical.slideid +'_%') != 'SD')
				and sampleid in (580, 583, 626, 627, 629, 630, 631, 635, 642, 643, 644, 653, 669, 673, 675, 676)
				then 'lung BMS chemo'
			when slideid in ('L1_2', 'L2_4', 'L3_2', 'L4_3', 'L5_1', 'L6_1', 'L7_2', 'L8_2', 'L9_3', 'L10_3', 'L11_3', 'L12_2', 'L13_3', 'L14_1', 'L15_2', 'L16_1', 'L17_2', 'L18_3', 'L19_4', 'L20_2', 'L34_1', 'L35_2', 'L37_1', 'L49_2', 'L50_1', 'L51_2', 'L52_4', 'L53_2', 'L54_1', 'L57_2', 'AP0150003', 'AP0150025', 'AP0150026', 'AP0150028', 'AP0150041')
				then 'lung axis post-treatment'
			when sampleid in (select sampleid from wsi01.dbo.ExtendedClinical where reduced_tumor_area >= 5)
				then 'melanoma axis'
			when sampleid in (338,295,359,304,333,291,318,314,296,343,350,289,327,361,345,286,298,325,302,328,290,362,329,358,285,334,310,301,344,357,352,284,341,294,332,300,292,303,347,365,355,312,311,
				366, --this might be supposed to be 306 instead
				305  --this might be supposed to be 335 instead
			)
				then 'melanoma validation'
			when sampleid in (1194, 1195, 1196, 1197, 1198, 1199, 1200, 1201, 1202, 1203, 1204, 1205, 1206)
				then 'lung BMS squames'
		end testsetname
		from samples
	), tmp2 as (
		select SlideID, SampleID, 'melanoma axis subset' testsetname
		from tmp
		where testsetname = 'melanoma axis' and abs(sine - cast(sine as integer)) > 0.5
		union all
		select SlideID, SampleID, 'lung validation OS' testsetname
		from tmp
		where testsetname = 'lung validation'
		union all
		select SlideID, SampleID, 'lung BMS squames OS' testsetname
		from tmp
		where testsetname = 'lung BMS squames'
	)
	insert into samplestouse (SlideID, SampleID, testsetname, testsetid)
	select slideid, sampleid, testsetname,
	case
		when testsetname = 'lung axis pre-treatment' then 1
		when testsetname = 'lung validation' then 2
		when testsetname = 'lung akoya' then 3
		when testsetname = 'lung BMS chemo' then 4
		when testsetname = 'lung axis post-treatment' then 5
		when testsetname = 'melanoma axis' then 6
		when testsetname = 'melanoma validation' then 7
		when testsetname = 'melanoma axis subset' then 8
		when testsetname = 'lung validation OS' then 9
		when testsetname = 'lung BMS squames OS' then 10
		when testsetname = 'lung BMS squames' then 11
	end testsetid
	from (
		select SlideID, SampleID, testsetname from tmp
		union all
		select SlideID, SampleID, testsetname from tmp2
	) combined
	where testsetname is not null
end

if object_id('trainingsets_local') is null begin
	create table trainingsets_local (
		SlideID varchar(64) not null,
		SampleID int not null,
		trainingsetname varchar(64) not null,
		trainingsetid tinyint not null,
		distancebinselectionid tinyint not null,
		CONSTRAINT PK_trainingsets_local PRIMARY KEY (trainingsetid, SampleID)
	);
	with tmp as (
		select SlideID, SampleID,
		case
			--lung training set
			when slideid in ('L1_2', 'L34_1', 'L52_4', 'L49_2', 'L18_3', 'AP0150025')
				then 'lung'
			--melanoma training set: excluded samples from CS13
			--when slideid in ('M187', 'M209', 'M214', 'M115', 'M200', 'M231', 'M198', 'M152', 'M168', 'M218')
			--	then 'melanoma'
			--melanoma training set 2: subset of the samples from CS1
			when sampleid in (select sampleid from samplestouse where testsetname = 'melanoma axis') and sampleid not in (select sampleid from samplestouse where testsetname = 'melanoma axis subset')
				then 'melanoma axis subset'
			else null
		end trainingsetname
		from samples
	)
	insert into trainingsets_local (SlideID, SampleID, trainingsetname, trainingsetid, distancebinselectionid)
	select slideid, sampleid, trainingsetname,
	case
		when trainingsetname = 'lung' then 1
		when trainingsetname = 'melanoma' then 2
		when trainingsetname = 'melanoma axis subset' then 3
	end trainingsetid,
	case
		when trainingsetname = 'lung' then 1
		when trainingsetname = 'melanoma' then 1
		when trainingsetname = 'melanoma axis subset' then 1
	end distancebinselectionid
	from tmp
	where trainingsetname is not null
end

if object_id('DistanceBins') is null begin
    create table DistanceBins (
        distancebin tinyint not null primary key,
        distancebinloweredge float not null,
        distancebinupperedge float not null
    )
    insert into DistanceBins (distancebin, distancebinloweredge, distancebinupperedge) values
    (1, 3, 10),
    (2, 10, 20),
    (3, 20, 30),
    (4, 30, 40),
    (5, 40, 50);
end

if object_id('DistanceBinSelection') is null begin
	create table DistanceBinSelection (
		distancebinselectionid tinyint not null primary key,
		distancebins int not null,
		[description] varchar(max) not null
	)
	insert into DistanceBinSelection (distancebinselectionid, distancebins, [description]) values
	(1, 4, 'only distance bin 2, i.e. 5-10 microns'),
	(2, 4+8+16, 'distance bins 2, 3, and 4, i.e. 5-20 microns'),
	(3, 4+8+16+32, 'distance bins 2, 3, 4, and 5, i.e. 5-25 microns')
end

if object_id('donut_constants') is null begin
	select 25 tdistbinning
	into donut_constants
end