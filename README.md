# The DONUT sql code

This code takes a WSI database using the AstroPath schema and creates a new database for the DONUT analysis.  The SQL code contains three sections.  Part 1 sets up the DONUT database, creates views to the WSI database, and sets up some basic bookkeeping tables.  The second part calculates the number of neighbors for each cell of each type and creates the training set.  The third part runs the analysis on the test set and creates ROC curves.

**The database name for the DONUT analysis is hardcoded in A1.0 to correspond to a particular WSI database.**  This way, the code automatically determines which database to take the data from.

To create the trained models, run the SQL code in order up to `A2.5-allneighborhoodhist.sql` for each DONUT database that contains samples that you want to train or test on.  Edit `A2.5-allneighborhoodhist.sql` so that `TrainedModels` draws from all relevant DONUT databases, and run that script again.  Then, run the rest of the code for any cohort that you want to run as a test set.

## Section 1: Setup

### A1.0-createviews.sql

This code creates views in the DONUT database which directly refer to tables in the WSI database.  In this way, subsequent parts of the code can minimize their reliance on dynamic SQL and can just refer to the views.

### A1.1-functions.sql

This code creates some utility functions to be used in the rest of the code, mostly for getting marker expression values.

### A1.2-celltagmorecols.sql

This code creates the `CellTagMoreCols` view, which contains some additional columns.  If CellTag does not contain `rdist`, the distance from the cell to the regression boundary, CellTagMoreCols adds this column with a large dummy value.  It also adds the PD1column, PDL1column, and CD8column columns, which give the expression values for those markers (taken from other columns, with varying names by cohort due to varying wavelengths used to stain those markers).

The `RandomCellMoreCols` view is also created, also with the `rdist` column and also with `inlymphnode`, which is 1 if the cell is in a lymph node and 0 otherwise.

### A1.3-bookkeepingtables.sql

This code creates several tables with bookkeeping values:
 - `ptype_translation`: this table translates between the phenotype convention used in the current WSI database to the convention in WSI02.
 - `ptype20_lookup`: this table creates a lookup table for ptype20, which is a 20-phenotype classification system that includes the basic 6 phenotypes split by PD-1 and PD-L1 expression.
 - `tidstcut`: This table contains the sample-wise limits on distance from the tumor boundary.  By default we use the whole tumor area plus 250 microns of stroma; there are a couple of special cases.
 - `tdistcut_regression`: This table contains a different convention for `tdistcut`: for post-treatment samples with a regression region, we use the whole tumor and regression, while for all other samples we use the tumor area plus 250 microns, as in `tidstcut`.
 - `samplestouse`: This table defines the test sets used for analysis.
 - `trainingsets_local`: This table defines the training sets used for analysis.  This only includes the training sets in the current donut database.  Later, we will merge the trained models from this and other databases and can run them all on the local test sets defined in `samplestouse`.
 - `DistanceBins`: These are the bins in which we classify distances between neighbors.
 - `DistanceBinSelection`: These are distance bin selections for neighbor counts.  For example, distancebinselectionid = 2 includes distance bins 2, 3, and 4, i.e. 5-20 microns.
 - `donut_constants`: This contains constants used in the analysis - currently just the binning of the tumor distance, which is 25 microns.

### A1.4-localrandomcell.sql

This script copies the RandomCell view (from the corresponding WSI database) to a table in the DONUT database and creates some indices that we will use in the analysis.

### A1.5-response.sql

This script creates a Response table, which classifies patients as responders or non-responders based on the Clinical table.  Because the Clinical table is not always in the same format, we populate this table using dynamic sql to unify the format and make analysis easier.

## Section 2: Neighbors and training set

### A2.0-celltable.sql

This script creates the CellTable table from the WSI database, which contains the columns needed for the analysis.

### A2.1-allneighborshist.sql

Now we calculate the number of neighbors of each phenotype for each cell within each distance bin.  We also count the number of PD-1 and PD-L1 positive and negative neighbors of each phenotype, and the total PD-1 and PD-L1 expression of the neighbors of each phenotype.  This is not used in the actual analysis, but is used for plotting.

### A2.2-allneighborshistDR.sql

`AllNeighborsHistDR` is the same as `AllNeighborsHist`, but calculates the number of neighbors for the random cells.  (The naming convention comes from the `NeighborsDR` table in the WSI database, which is named because it calculates neighbors between data and random.)

### A2.3-allneighborssummary.sql

This table consolidates `AllNeighborsHist` into a table with a single row per cell and per distance bin.  It contains columns for the counts of each phenotype, and additional columns for PD-1 and PD-L1 information.

### A2.4-allneighborssummaryDR.sql

This is the same as `AllNeighborsSummary`, but for the random cells.

### A2.5-allneighborhoodhist.sql

This script creates the trained model for analysis.  The `AllNeighborhoodHist` table, build from `AllNeighborsSummary`, contains the number of cells of each phenotype, with each neighbor configuration, and in each tumor distance bin, in each sample.

We then create the `TrainedModels_local` table, which sums over the samples in each training set.

The `TrainedModels` table is derived simply by combining the `TrainedModels_local` table from the current database with the ones from other relevant DONUT databases.

Given observables $\vec{\Omega}$, We define the *discriminant* used to determine CD8+FoxP3+-like niches as $$D_\text{CD8+FoxP3+}(\vec{\Omega}) = \frac{P_\text{CD8+FoxP3+}(\vec{\Omega})}{\sum_p{P_p}(\vec{\Omega})},$$ where $P_p(\vec\Omega)$ is the probability of observing $\vec\Omega$ given that the cell is of the phenotype $p$.  By the Neyman-Pearson lemma, this is the optimal observable to distinguish between CD8+FoxP3+ and other phenotypes.

We estimate $P_p(\vec\Omega)$ by simply counting the number of cells of each phenotype with the configuration $\vec\Omega$ in the training set.  The probability is proportional to this number.

We then create the `cconstants` table, which contains constants used to normalize the probabilities so that the discriminant has a balanced distribution between 0 and 1.  (See, for example, Eq. (18) of [arXiv:1411.3441 [hep-ex]](https://arxiv.org/abs/1411.3441).)  This normalization is done for aesthetic purposes, but does not affect the optimality of the discriminant.

## Section 3: Analysis

### A3.0-DiscriminantsTable.sql

This script creates the `Discriminants` table, which contains the discriminants for each cell.  The discriminant $D_5=D_\text{CD8+FoxP3+}$ quantifies how similar the cell's niche is to a CD8+FoxP3+ niche.

(The notation $D_5$ is used because CD8+FoxP3+ is the 5th phenotype in the WSI02 convention.)

### A3.1-DiscriminantsTableDR.sql

Similar to `DiscriminantsTable`, but for the random cells.

### A3.2-D5CutCountTable.sql

The `D5CutCountTableMerged` counts the number of cells with $D_\text{CD8+FoxP3+}>\text{cutoff}$ in each sample, for varying values of the cutoff.  The table contains a column `usedonuts`, which can take the following values:
- 1: use the random cells
- 0: use all actual cells
- -1: use only the CD8+FoxP3+ cells
- -2: use only the non-CD8+FoxP3+ cells

Two views on this table are also created: `D5CutCountTable` and `D5CutCountTableDR`, which select for `usedonuts=0` and `usedonuts=1`, respectively.

In addition to using the trained models given by `trainingsetid` and defined in `A1.2-bookkeepingtables.sql`, there are also rows with `trainingsetid=0` and `distancebinselectionid=0`.  These rows give the numbers of actual CD8+FoxP3+ cells in the sample.

### A3.3-RocInputs.sql

This script creates the `RocInputs` table, which contains the inputs for the ROC curve derived from `D5CutCountTableMerged`.  Each ROC curve is defined by:
- `usedonuts`: as above
- `trainingsetid`: the training set used to define the discriminants
- `distancebinselectionid`: the distance bin selection used to define the neighbors for the discriminants
- `testsetid`: the test set used
- `D5cut`: the cutoff used to define the CD8+FoxP3+-like niches

For each point on the ROC curve, we define the following:
- `celldensitycut`: the density of CD8+FoxP3+-like niches (as defined by `D5cut`)
- `Response`: either "responder" or "non-responder"
- `npass`: the number of samples, with the given response, that pass the cutoff
- `nsamples`: the total number of responders or non-responders

### A3.4-Roc.sql

This script contains the actual ROC curves.  For each ROC curve, we define the following:
- `fselectedresponders`: the fraction of responders that pass the cutoff
- `fselectednonresponders`: the fraction of non-responders that pass the cutoff
- `rownum`: the row number of the row within the ROC curve

To plot the ROC curve, we can use the `fselectedresponders` and `fselectednonresponders` columns.

### A3.5-AUCtable.sql

This script, which runs essentially instantaneously, creates the `AUCtable` table, which contains the area under each ROC curve.  The AUC is calculated using the trapezoidal rule.

# Data

The data folder contains sql scripts to extract the most relevant data from the DONUT database.