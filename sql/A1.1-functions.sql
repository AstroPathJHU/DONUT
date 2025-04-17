create or alter function dbo.fPhenotypeId(@name varchar(32)) returns int as begin
  declare @result int;
  with tmptable as (
  select distinct ptype, phenotype from cell where phenotype = @name
  )
  select @result=ptype from tmptable
  return @result
end
go


----------
--from Ben
----------
CREATE or Alter FUNCTION dbo.fGetExpr(@eptype varchar(max))

--------------------------------------------------------------------
-- dbo.fGetExpr(@eptype)
-- 
-- get the decimal value of the expression marker bit integer
-- (can use & to compare as bits). To use with celltag, add 
-- (exprPhenotype & val ) = val to where clause for all + combinations. 
-- For expression marker pairs, add a dash 
-- in the name (pd1-lag3). To get only that pair use 
-- exprPhenotype = val in the where clause. 
--------------------------------------------------------------------
-- INPUT:
-- @eptype[varchar]: the expression marker phenotype string to be 
-- deciphered( ie. 'pd1')
--------------------------------------------------------------------
 Returns @mask table(
	val smallint, -- decimal value (ex. 64)
	b smallint, -- int value (ex. 2)
	Opal varchar(100), -- opal of interest (ex. Opal540)
	t varchar(100) -- target (ex. pd1)
	)
	AS BEGIN
	------------------------------------------------
	-- if input is * return 0
	------------------------------------------------
	if @eptype = '*'
		insert into @mask
		select 0 as val, 0 as b, 'OPAL', 'all' t
	ELSE
		BEGIN
			------------------------------------------------
			-- first get the Opal value from the MergeConfig
			-- table, then get the bit\ decimal values from the 
			-- exprphenotype table
			------------------------------------------------
			insert into @mask
			select val, [bit] b, b.Opal, t
			from ExprPhenotype, (
				select Opal as Opal, [Target] as t
					from MergeConfig
					--where [Target] in (select * from string_split(@eptype, '-'))
					group by Opal, [Target]
				) b
			where Expr = 'Opal'+b.Opal
		END
	--
	RETURN
END
go

create or alter function dbo.fGetExprBit(@eptype varchar(max)) returns int as begin
	declare @val int
    select @val=val from dbo.fGetExpr(@eptype) where t=@eptype
	return @val
end
go

create or alter function dbo.fGetExprColumn(@eptype varchar(max)) returns varchar(max) as begin
	declare @opal varchar(max)
	select @opal=opal from dbo.fGetExpr(@eptype) where t=@eptype
	return 'CMembrane'+@opal
end
go

DECLARE @DbName NVARCHAR(MAX);
SELECT @DbName = WsiDbName FROM WsiDbName;
go

create or alter function dbo.ptype20(@ptype int, @PD1level int, @PDL1level int) returns int as begin
  return case
  when @ptype = 1 and @PD1level > 0 and @PDL1level > 0 then 1
  when @ptype = 1 and @PD1level > 0 and @PDL1level = 0 then 2
  when @ptype = 1 and @PD1level = 0 and @PDL1level > 0 then 3
  when @ptype = 1 and @PD1level = 0 and @PDL1level = 0 then 4
  when @ptype = 5 and @PD1level > 0 and @PDL1level > 0 then 5
  when @ptype = 5 and @PD1level > 0 and @PDL1level = 0 then 6
  when @ptype = 5 and @PD1level = 0 and @PDL1level > 0 then 7
  when @ptype = 5 and @PD1level = 0 and @PDL1level = 0 then 8
  when @ptype = 2 and @PD1level > 0 and @PDL1level > 0 then 9
  when @ptype = 2 and @PD1level > 0 and @PDL1level = 0 then 10
  when @ptype = 2 and @PD1level = 0 and @PDL1level > 0 then 11
  when @ptype = 2 and @PD1level = 0 and @PDL1level = 0 then 12
  when @ptype = 0 and @PD1level > 0 and @PDL1level > 0 then 13
  when @ptype = 0 and @PD1level > 0 and @PDL1level = 0 then 14
  when @ptype = 0 and @PD1level = 0 and @PDL1level > 0 then 15
  when @ptype = 0 and @PD1level = 0 and @PDL1level = 0 then 16
  when @ptype = 3 and @PDL1level > 0 then 17
  when @ptype = 3 and @PDL1level = 0 then 18
  when @ptype = 4 and @PDL1level > 0 then 19
  when @ptype = 4 and @PDL1level = 0 then 20
  else -1
  end
end
go
