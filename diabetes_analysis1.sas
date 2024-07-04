/**************** Data Read-in ****************/

/* Defining the file path */
filename reffile '/home/u63906681/Daibetes Health Indicators/diabetes_health_indicators.csv';

/* Data import */
proc import datafile=reffile
	out = diab_data
	dbms=csv;
run;

/**************** Initial data checks ****************/

/* Printing the schema of the data */
proc contents data=diab_data;
run;

/* Sample observations */
proc print data=diab_data (obs=10);
	title "original data";
run;

/* Row count - printed in the LOG file */
data _null_;
	if 0 then set diab_data nobs=n;
	put "Number of records: " n;     /* 253680 */
stop;
run;


/**************** Checking for missing data, outliers and other inconsistencies ****************/

/* Missing value count */
proc means data=diab_data nmiss;
run;

/* Univariate Stats */
proc univariate data=diab_data;
	var Diabetes_012 HighBP HighChol CholCheck Smoker 
	Stroke HeartDiseaseorAttack PhysActivity Fruits Veggies 
	HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth 
	MentHlth BMI PhysHlth DiffWalk Sex Age Education Income;
run;

/**************** Data imbalance ****************/

/* Target frequencies */
proc freq data=diab_data;
	tables Diabetes_012/list missing;
run;

/* Bar plot of the target */
proc sgplot data=diab_data;
	vbar Diabetes_012;
run;

/**************** Correlation analysis ****************/

/* Correlation between variables */
proc corr data=diab_data out=corr_results;
run;

proc transpose data=corr_results out=corr_results_tr;
run;

/* Macro to find highly correlated variables given a threshold and a variable */
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

/* Macro to iterate the correlation macro through the list of variables */
%macro loop_vars(var_list);
   %local i var;
   %do i = 1 %to %sysfunc(countw(&var_list));
      %let var = %scan(&var_list, &i);
      %chk_high_corr(0.2, &var);
   %end;
%mend loop_vars;

/* List of variables to check for correlation */
%let vars = Diabetes_012 HighBP HighChol CholCheck Smoker Stroke HeartDiseaseorAttack PhysActivity Fruits Veggies HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth MentHlth BMI PhysHlth DiffWalk Sex Age Education Income;

/* Calling the macro on the above listed variables */
%loop_vars(&vars);


/**************** Exploring variable relationships ****************/
proc freq data=diab_data;
	tables Diabetes_012*HighBP 
	Diabetes_012*HighChol 
	Diabetes_012*Smoker 
	Diabetes_012*PhysActivity / chisq;
run;

/**************** Data Analysis & Transformations ****************/

/* Merge minority groups in target */
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

* Note. The target is still not balanced.;

/* Analysing age groups */
/* Age current binning: 
	1: 18-24
	2: 25-29
	3: 30-34
	4: 35-39
	5: 40-44
	6: 45-49
	7: 50-54
	8: 55-59
	9: 60-64
	10: 65-69
	11: 70-74
	12: 75-79
	13: 80 & above
*/

proc freq data=diab_data;
	tables age/list missing;
run;

proc sgplot data=diab_data;
	vbar age;
run;

/* Merge age groups */
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

/* Checking the distribution of BMI */
proc univariate data=diab_data;
	var BMI;
	histogram BMI / normal;
	probplot BMI / normal(mu=est sigma=est);
run;

proc sgplot data=diab_data;
	vbox BMI / category=Diabetes_01;
run;

/* Analysis of variance of BMI across AgeGroup */
proc anova data=diab_data;
	class AgeGroup;
	model BMI = AgeGroup;
	means AgeGroup / tukey;
run;

/* Checking for natural clusters in the data - using 3 clusters*/
proc fastclus data=diab_data maxclusters=3 out=clus_result;
	var HighBP HighChol CholCheck Smoker Stroke 
	HeartDiseaseorAttack PhysActivity Fruits Veggies 
	HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth 
	MentHlth BMI PhysHlth DiffWalk Age Education Income;
run;

/* Cross checking the assinged clusters across the target column */
proc freq data=clus_result;
	tables Diabetes_012*cluster /list missing;
run;

/* Checking for natural clusters in the data - using 2 clusters*/
proc fastclus data=diab_data maxclusters=2 out=clus_result2;
	var HighBP HighChol CholCheck Smoker Stroke 
	HeartDiseaseorAttack PhysActivity Fruits Veggies 
	HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth 
	MentHlth BMI PhysHlth DiffWalk Age Education Income;
run;

/* Cross checking the assinged clusters across the target column */
proc freq data=clus_result2;
	tables Diabetes_01*cluster /list missing;
run;


/**************** Diabetes Prediction ****************/

/* Logistic regression to predict diabetes */

* Model ROC;
proc logistic data=diab_data plots(only)=roc;
	model Diabetes_01(event='1') = HighBP HighChol CholCheck Smoker Stroke HeartDiseaseorAttack PhysActivity Fruits Veggies HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth MentHlth BMI PhysHlth DiffWalk Sex Age Education Income;
run;

* Residual analysis;
proc reg data=diab_data;
	model BMI = HighBP HighChol CholCheck Smoker Stroke HeartDiseaseorAttack PhysActivity Fruits Veggies HvyAlcoholConsump AnyHealthcare NoDocbcCost GenHlth MentHlth PhysHlth DiffWalk Sex Age Education Income;
	output out=residuals r=resid;
run;

proc univariate data=residuals;
	var resid;
	histogram resid / normal;
	probplot resid / normal(mu=est sigma=est);
run;

/* Interaction terms */
proc logistic data=diab_data;
	model Diabetes_01(event='1') = HighBP|HighChol|CholCheck|Smoker|Stroke|HeartDiseaseorAttack|PhysActivity|Fruits|Veggies|HvyAlcoholConsump|AnyHealthcare|NoDocbcCost|GenHlth|MentHlth|BMI|PhysHlth|DiffWalk|Sex|Age|Education|Income @2;
run;

