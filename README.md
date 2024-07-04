# Analysis of Diabetes Health Indicators Using SAS

## Overview
This project analyses a comprehensive diabetes health indicator dataset from a CDC survey using SAS. The dataset includes various health-related variables such as blood pressure, cholesterol levels, smoking status, and more.

## Script Description

### Data Read-in
Reads the diabetes health indicator dataset from a CSV file and performs initial data checks.

```
filename reffile '/home/u63906681/Daibetes Health Indicators/diabetes_health_indicators.csv';

proc import datafile=reffile
	out=diab_data
	dbms=csv;
run;
```
### Initial Data Checks
- Prints the schema of the data
- Displays sample observations
- Prints row count in the log file

```
proc contents data=diab_data;
run;

proc print data=diab_data (obs=10);
	title "original data";
run;

data _null_;
	if 0 then set diab_data nobs=n;
	put "Number of records: " n;     /* 253680 */
	stop;
run;
```
### Missing Data, Outliers, and Inconsistencies
- Checks for missing values
- Computes univariate statistics

```
proc means data=diab_data nmiss;
run;

proc univariate data=diab_data;
	var Diabetes_012 HighBP HighChol CholCheck Smoker 
		Stroke HeartDiseaseorAttack PhysActivity Fruits Veggies 
		HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth 
		MentHlth BMI PhysHlth DiffWalk Sex Age Education Income;
run;
```
### Data Imbalance
- Computes frequencies of the target variable
- Displays bar plot of the target variable
```
proc freq data=diab_data;
	tables Diabetes_012/list missing;
run;

proc sgplot data=diab_data;
	vbar Diabetes_012;
run;
```

### Correlation Analysis
- Computes correlation between variables
- Macro to find highly correlated variables
```
proc corr data=diab_data out=corr_results;
run;

proc transpose data=corr_results out=corr_results_tr;
run;

%macro chk_high_corr(corr_thres, chk_var);
	data chk;
		length corr $4;
		set corr_results_tr;
		if abs(&chk_var.) gt &corr_thres.
			then corr='high';
		else corr='low';
		where vname(&chk_var) NE _NAME_;
	run;
	
	proc print data=chk (obs=50);
		title "&chk_var is highly correlated (&corr_thres.) with:";
		where corr='high';
		var _NAME_ &chk_var;
	run;		
%mend chk_high_corr;

%macro loop_vars(var_list);
   %local i var;
   %do i = 1 %to %sysfunc(countw(&var_list));
      %let var = %scan(&var_list, &i);
      %chk_high_corr(0.5, &var);
   %end;
%mend loop_vars;

%let vars = Diabetes_012 HighBP HighChol CholCheck Smoker Stroke HeartDiseaseorAttack PhysActivity Fruits Veggies HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth MentHlth BMI PhysHlth DiffWalk Sex Age Education Income;

%loop_vars(&vars);
```

### Exploring Variable Relationships
- Analyzes relationships between variables using chi-square tests

```
proc freq data=diab_data;
	tables Diabetes_012*HighBP 
	Diabetes_012*HighChol 
	Diabetes_012*Smoker 
	Diabetes_012*PhysActivity / chisq;
run;
```
### Data Analysis & Transformations
- Merges minority groups in the target variable
- Analyzes and bins age groups
- Checks the distribution of BMI
- Analyzes variance of BMI across age groups
- Performs cluster analysis
```
data diab_data;
	set diab_data;
	if Diabetes_012 in (1, 2) then Diabetes_01 = 1;
	else Diabetes_01 = 0;
run;

proc freq data=diab_data;
	tables Diabetes_01/list missing;
run;

proc sgplot data=diab_data;
	vbar Diabetes_01;
run;

proc freq data=diab_data;
	tables age/list missing;
run;

proc sgplot data=diab_data;
	vbar age;
run;

data diab_data;
	set diab_data;
	if Age < 6 then AgeGroup = 'Under 40';
	else if Age < 9 then AgeGroup = '40-59';
	else AgeGroup = '60+';
run;

proc freq data=diab_data;
	tables age*AgeGroup AgeGroup/list missing;
run;

proc sgplot data=diab_data;
	vbar AgeGroup;
run;

proc univariate data=diab_data;
	var BMI;
	histogram BMI / normal;
	probplot BMI / normal(mu=est sigma=est);
run;

proc sgplot data=diab_data;
	vbox BMI / category=Diabetes_01;
run;

proc anova data=diab_data;
	class AgeGroup;
	model BMI = AgeGroup;
	means AgeGroup / tukey;
run;

proc fastclus data=diab_data maxclusters=3 out=clus_result;
	var HighBP HighChol CholCheck Smoker Stroke 
	HeartDiseaseorAttack PhysActivity Fruits Veggies 
	HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth 
	MentHlth BMI PhysHlth DiffWalk Age Education Income;
run;

proc freq data=clus_result;
	tables Diabetes_012*cluster /list missing;
run;

proc fastclus data=diab_data maxclusters=2 out=clus_result2;
	var HighBP HighChol CholCheck Smoker Stroke 
	HeartDiseaseorAttack PhysActivity Fruits Veggies 
	HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth 
	MentHlth BMI PhysHlth DiffWalk Age Education Income;
run;

proc freq data=clus_result2;
	tables Diabetes_01*cluster /list missing;
run;
```
### Diabetes Prediction
- Performs logistic regression to predict diabetes
- Analyzes residuals
- Includes interaction terms in the model
```
proc logistic data=diab_data plots(only)=roc;
	model Diabetes_01(event='1') = HighBP HighChol CholCheck Smoker Stroke HeartDiseaseorAttack PhysActivity Fruits Veggies HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth MentHlth BMI PhysHlth DiffWalk Sex Age Education Income;
run;

proc reg data=diab_data;
	model BMI = HighBP HighChol CholCheck Smoker Stroke HeartDiseaseorAttack PhysActivity Fruits Veggies HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth MentHlth PhysHlth DiffWalk Sex Age Education Income;
	output out=residuals r=resid;
run;

proc univariate data=residuals;
	var resid;
	histogram resid / normal;
	probplot resid / normal(mu=est sigma=est);
run;

proc logistic data=diab_data;
	model Diabetes_01(event='1') = HighBP|HighChol|CholCheck|Smoker|Stroke|HeartDiseaseorAttack|PhysActivity|Fruits|Veggies|HvyAlcoholConsump|AnyHealthcare|NoDocbcCost|GenHlth|MentHlth|BMI|PhysHlth|DiffWalk|Sex|Age|Education|Income @2;
run;

```

## Acknowledgments
- SAS documentation for providing comprehensive guides on SAS programming.
- The open-source community for fostering collaboration and knowledge sharing.

## References
- [Building Risk Prediction Models for Type 2 Diabetes Using Machine Learning Techniques](https://www.cdc.gov/pcd/issues/2019/19_0109.htm)
- [Behavioral Risk Factor Surveillance System - Data](https://www.kaggle.com/datasets/cdc/behavioral-risk-factor-surveillance-system)
