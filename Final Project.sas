/* ================================================
   161.762 Multivariate Analysis for Big Data
   Final Project
   Group Number: 2
   Group Data: 2-ecommerce_sales_analytics_5000.csv
   ================================================ */

/* Import the dataset */
proc import datafile="~/Project/2-ecommerce_sales_analytics_5000.csv"
    out=work.ecommerce
    dbms=csv
    replace;
    getnames=yes;
run;

/* Check variable types and dataset structure
   List variables in their original order */
proc contents data=work.ecommerce varnum;
    title "Dataset Structure and Variable Types";
run;

/* Check for missing values across all variables
   nmiss counts the number of missing values per variable */
proc means data=work.ecommerce nmiss;
    title "Missing Value Check";
run;

/* Descriptive statistics for numeric variables
   Helps identify implausible values and scale differences
   All values are examined to confirm plausible ranges */
proc means data=work.ecommerce n mean std min median max;
    var quantity unit_price discount
        delivery_days customer_rating revenue;
    title "Descriptive Statistics for Numeric Variables";
run;

/* Frequency tables for categorical variables
   Confirms category labels and checks for rare levels */
proc freq data=work.ecommerce;
    tables product_category region payment_method;
    title "Frequency Tables for Categorical Variables";
run;

/* Create the main analytical dataset
   order_id and customer_id are identifier variables 
   and are not used in any multivariate analysis
   order_date is a time variable not used in analysis
   These three variables are dropped from the dataset
   ------------------------------------------------ */
data work.ecommerce_clean;
    set work.ecommerce;
    drop order_id customer_id order_date;
run;

/* Confirm the final analytical dataset */
proc contents data=work.ecommerce_clean varnum;
    title "Final Analytical Dataset: Variable List";
run;

proc means data=work.ecommerce_clean n nmiss;
    title "Final Dataset: Observation and Missing Value Check";
run;

/* Standardise numeric variables Required for dimension reduction (PCA) 
   and clustering Standardisation sets mean = 0 and std = 1 for all numeric variables */
proc stdize data=work.ecommerce_clean
    out=work.ecommerce_scaled
    method=std;
    var quantity unit_price discount
        delivery_days customer_rating revenue;
run;

/* Confirm the standardised dataset
   Mean should be approximately 0
   Std Dev should be approximately 1
   for all numeric variables */
proc means data=work.ecommerce_scaled n mean std min max;
    var quantity unit_price discount
        delivery_days customer_rating revenue;
    title "Standardised Numeric Variables: Confirmation";
run;

/* ================================================
   Q1:  Customer Segmentation                  
   Research Question: Can we identify distinct customer purchasing profiles and do 
   they align with product category or region?
   Methods: Hierarchical Clustering + K-means       
   ================================================ */
  
/* ================================================== */
/* EXPLORATORY BOXPLOTS                       */
/* Done before clustering to understand raw data      */
/* structure — motivates the research question        */
/* ================================================== */

/* Revenue by product category */
proc sgplot data=work.ecommerce;
    vbox revenue / category=product_category
                   fillattrs=(transparency=0.3)
                   lineattrs=(color=black);
    xaxis label="Product Category";
    yaxis label="Revenue ($)";
    title "Q1: Revenue by Product Category (Pre-Clustering)";
run;

proc sgscatter data=work.ecommerce;
    matrix quantity unit_price discount
           delivery_days customer_rating revenue
           / group=product_category;
    title "Q1: Variable Relationships by Product Category";
run;

proc sgscatter data=work.ecommerce;
    matrix quantity unit_price discount
           delivery_days customer_rating revenue
           / group=region;
    title "Q1: Variable Relationships by Region";
run;

/* Revenue by region */
proc sgplot data=work.ecommerce;
    vbox revenue / category=region
                   fillattrs=(transparency=0.3)
                   lineattrs=(color=black);
    xaxis label="Region";
    yaxis label="Revenue ($)";
    title "Q1: Revenue by Region (Pre-Clustering)";
run;

/*PCA to see whether there is a patterns and variables are 
correlated */

proc princomp data=work.ecommerce_scaled
    out=pca_scores
    plots=scree;

    var quantity unit_price discount
        delivery_days customer_rating revenue;

    title "Q1: PCA of Customer Purchasing Behaviour";
run;

/* Scatter plot of first two principal components */

proc sgplot data=pca_scores;
    scatter x=Prin1 y=Prin2 / group=product_category;
    
    title "Q1: PCA Plot by Product Category";
run;
/* ================================================== */
/* METHOD 1: HIERARCHICAL CLUSTERING - WARD'S METHOD  */
/* Purpose: Determine optimal number of clusters      */
/* using CCC and RSQ — no need to specify k first     */
/* ================================================== */

proc cluster data=work.ecommerce_scaled
    method=ward
    pseudo
    plots=all
    ccc
    outtree=tree
    print=25;
    
    var quantity unit_price discount
        delivery_days customer_rating revenue;
    title "Q1: Hierarchical Cluster Analysis";
run;
title;

/* Dendrogram to identify optimal clusters */

proc tree data=tree
    horizontal;
    title "Q1: Dendrogram for Customer Segmentation";
run;

/*---------------------------------------------------
K-Means Clustering
Final customer segmentation
---------------------------------------------------*/
title "Q1: K-Means Clustering for Customer Segmentation";
proc fastclus data=work.ecommerce_scaled
    maxclusters=3
    out=clustered_customers;
    var quantity unit_price discount
        delivery_days customer_rating revenue;
run;
title;

/* Cluster characteristics */
title "Q1: Cluster Profiles and Characteristics";
proc means data=clustered_customers mean std;
    class cluster;
    var quantity unit_price discount
        delivery_days customer_rating revenue;  
run;
title;

/* Relationship between clusters and product category */
title "Q1: Association Between Customer Clusters and Product Category";
proc freq data=clustered_customers;
    tables cluster*product_category / chisq;
run;

/* Relationship between clusters and region */
title "Q1: Association Between Customer Clusters and Region";
proc freq data=clustered_customers;
    tables cluster*region / chisq;
run;
  
  /* ================================================
   Q2: Factor Analysis (FA) and Canonical Correlation Analysis (CCA / RDA)
   Research Question: Are there any latent dimensions underlying the numeric
   transaction variables, and what do they reveal about how price, discount, 
   and delivery drive revenue?
   Dataset: work.ecommerce_scaled 
   ================================================ */

/* ================================================== */
/* Method One: Factor Analysis 						  */
/* ================================================== */

/* 
	Initial Factor Analysis to find number of factors 
	plots: prints scree plot to see how many latent dimensions might exist  
	method: this is the principal factor method that identifies the common variance patterns accross the transaction variables
	priors: estimates how much each ecommerce variable is explained by the others
	flag.3: see which transaction variables stongly define each emerging factor at 0.3 
	fuzz.2: .2 to make the factor loading table cleaner and easy to interpret
*/
  
ods graphics on;
proc factor data=work.ecommerce_scaled
				plots=(scree initloadings)
				rotate=none
				method=PRINCIPAL
				priors=smc
				flag=.3 fuzz=.2; /*filtering parameters*/
	title 'Q2: Initial Factor Analysis for all Numeric Analysis';
run;

/* Final Factor Analysis using varimax
	n=3: retention of three factors 
	r=varimax: produce a clean, easy to interpret factor structure
*/

ods select orthrotfactpat patternplot;
proc factor data=work.ecommerce_scaled 
				plots=loadings
				method=principal
 				priors=smc n=3 r=varimax flag=.3 fuzz=.2;
 	title1 'Q2: Final Factor Analysis using varimax rotation';
run;

/* ================================================== */
/* Method Two: CCA / RDA    						  */
/* ================================================== */
/* 
	RED: requests RDA to assess the extent of variance in revenue related results is clarified by cost, discount and delivery.
    NCAN=2: derives the leading two multivariate patterns connecting predictors to sales outcomes
    VPREFIX/WPREFIX: enerates new canonical score variables for analysis
*/

/*run the main CCA/RDA code*/
ods output Redundancy=work.redundancy
SqMultCorr=work.sqmult;

proc cancorr data=work.ecommerce_scaled
			corr red out=work.ecommerce_cca_scores ncan=2
			vprefix=Result wprefix=Driver
			vname="Sales Results"
			wname="Factors Influencing Transactions";
var revenue quantity;
with unit_price discount delivery_days;
title 'Q2: CCA and RDA Analysis';
run;  
  
/* ================================================
Q3: Linear and Quadratic Discriminant Analysis
Research Question:
Can transaction-level variables reliably distinguish
product categories in ecommerce orders, and which
variables contribute most strongly to category separation?
Dataset: work.ecommerce_clean
================================================ */

/* Linear Discriminant Analysis (LDA) */

/*LDA is used because product_category is a known
grouping variable. The aim is to determine whether
transaction-level variables can distinguish the
four product categories.

Numeric predictor variables:

* quantity
* unit_price
* discount
* delivery_days
* customer_rating
* revenue

product_category is the response/grouping variable. */

/* Run Linear Discriminant Analysis */

proc discrim data=work.ecommerce_scaled
pool=yes
crossvalidate
pcov
wcov
anova;

class product_category;

var quantity
    unit_price
    discount
    delivery_days
    customer_rating
    revenue;

title "Q3: Linear Discriminant Analysis (LDA)";

run;

/* Canonical Discriminant Analysis */

/* Canonical discriminant analysis provides canonical
variables used to visualise separation between
product categories. */

proc candisc data=work.ecommerce_scaled
out=work.q3_can;
class product_category;

var quantity
    unit_price
    discount
    delivery_days
    customer_rating
    revenue;

title "Q3: Canonical Discriminant Analysis";

run;

/* Canonical Discriminant Plot */

/* Visualise separation between product categories.
Overlap between groups indicates weak separation. */

proc sgplot data=work.q3_can;

scatter x=Can1 y=Can2 /
    group=product_category
    markerattrs=(symbol=circlefilled);

xaxis label="Canonical Variable 1";
yaxis label="Canonical Variable 2";

title "Q3: Canonical Discriminant Plot";

run;

/* Quadratic Discriminant Analysis (QDA) */

/* QDA relaxes the equal covariance assumption
required by LDA. QDA is included as a comparison
method to determine whether classification
performance improves when covariance structures
are allowed to differ between groups. */

proc discrim data=work.ecommerce_scaled
pool=no
crossvalidate;

class product_category;

var quantity
    unit_price
    discount
    delivery_days
    customer_rating
    revenue;

title "Q3: Quadratic Discriminant Analysis (QDA)";

run;
  
/* ================================================
   Q4: Correspondence Analysis
   How do payment method preferences differ by product category and by region in e-commerce orders?
   Dataset: work.ecommerce_clean
   ================================================ */

/* Chi-square test
   Product category vs Payment method
   Test whether association exists before
   running correspondence analysis */
proc freq data=work.ecommerce_clean;
    tables product_category*payment_method / chisq;
    title "Q4: Chi-Square Test: Product Category vs Payment Method";
run;

/* Correspondence Analysis
   Product category vs Payment method
   observed: prints the observed contingency table*/
proc corresp data=work.ecommerce_clean observed rp short;
    tables product_category, payment_method;
    title "Q4: Correspondence Analysis: Product Category vs Payment Method";
run;

/* Chi-square test: Region vs Payment Method */
proc freq data=work.ecommerce_clean;
    tables region*payment_method / chisq;
    title "Q4: Chi-Square Test: Region vs Payment Method";
run;

/* Correspondence Analysis: Region vs Payment Method */
proc corresp data=work.ecommerce_clean observed rp short;
    tables region, payment_method;
    title "Q4: Correspondence Analysis: Region vs Payment Method";
run;
