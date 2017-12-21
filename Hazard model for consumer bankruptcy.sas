*proc printto log = "P:\assignment 6\6.1\logfile";
*run;

options ls=70 nodate nocenter obs = 100000000 firstobs=1;

%let loanstat_1 = LoanStats_2016Q1 LoanStats_2016Q2 LoanStats_2016Q3 LoanStats_2016Q4;
%let loanstat_2 = LoanStats3a LoanStats3b LoanStats3c LoanStats3d;


*read csv files of loanstats_2016 and make the second row as the variable names;
*and drop the last four rows;
%macro read_loanstat_1(vlist);
    %local k next;
    %do k = 1 %to %sysfunc(countw(&vlist));
	    %let next = %scan(&vlist,&k);
        proc import datafile="Q:\Data-ReadOnly\LendingClub\&next..csv"
            out = &next dbms=csv replace;
			*namerow=2;
            datarow=2;
            *getnames=no;
        run;
		data names ;
        	set &next (obs=1) ;
  			array vars{*} $32. _CHARACTER_ ;
  			do nvar = 1 to dim(vars) ;
    			curr_varname = vname(vars{nvar}) ; /* get the current variable name, e.g. A B etc */
    			new_varname = vars{nvar} ;         /* variable value, e.g. VAR1 VAR2 etc */
    			output ;
  			end ;
		run ;
		proc sql noprint ;
            select catx('=',curr_varname,new_varname)
            into :rename separated by ' '
            from names
            ;
        quit;
		data &next ;
            set &next (firstobs=2 rename=(&rename));
        run;
		data &next;
		    set &next;
			if loan_amnt = "" then delete;
		run;

    %end;
%mend;
%read_loanstat_1(&loanstat_1);
run;

*read csv files of loanstats3;
%macro read_loanstat_2(vlist);
    %local k next;
    %do k = 1 %to %sysfunc(countw(&vlist));
	    %let next = %scan(&vlist,&k);
        proc import datafile="Q:\Data-ReadOnly\LendingClub\&next..csv"
            out = &next dbms=csv replace;
        getnames=yes;
        run;
    %end;
%mend;

%read_loanstat_2(&loanstat_2);
run;

*modify two variables in loanstats3a into numeric;
data Loanstats3a;
    set Loanstats3a;
    mths_1=input(mths_since_last_record,12.);
    mths_2=input(mths_since_last_major_derog,12.);
	drop mths_since_last_record mths_since_last_major_derog;
	rename mths_1=mths_since_last_record mths_2=mths_since_last_major_derog;
run;

*combine loanstats_2016 together;
data Loanstats_2016;
    set &loanstat_1;
run;

*combine loanstats3 together;
data Loanstats3;
    set &loanstat_2;
run;

*calculate variables for regression;
data Loanstats3;
    set Loanstats3;
	id_n = id;
	if Loan_Status = "Fully Paid" then LoanDefFlag = 0 ;
	else if Loan_Status = "Charged Off" then LoanDefFlag = 1 ;
	else if Loan_Status = "Default" then LoanDefFlag = 1 ;
	else delete;

	if length(issue_d)=6 then fyear = input(substr(issue_d,1,2),8.)+2000;
	else fyear = input(substr(issue_d,1,1),8.)+2000;

	if emp_length = "< 1 year" then employed = 0;
	else if emp_length = "1 year" then employed = 1;
	else if emp_length = "2 years" then employed = 2;
	else if emp_length = "3 years" then employed = 3;
	else if emp_length = "4 years" then employed = 4;
	else if emp_length = "5 years" then employed = 5;
	else if emp_length = "6 years" then employed = 6;
	else if emp_length = "7 years" then employed = 7;
	else if emp_length = "8 years" then employed = 8;
	else if emp_length = "9 years" then employed = 9;
	else if emp_length = "10 years" then employed = 10;
	else if emp_length = "10+ years" then employed = 10;
	else employed = 0;

	interest = input(int_rate,percent.);
	inc_loan_cover = annual_inc / loan_amnt;
	revol_bal_loan_cover = revol_bal / loan_amnt;
	late_fee_ratio = total_rec_late_fee / loan_amnt;
	out_prncp_ratio = out_prncp / loan_amnt;
	*total_rec_prncp_ratio = total_rec_prncp / loan_amnt;
    dti_n = dti/100;

	delinq_2yrs_n =delinq_2yrs;
    inq_last_6mths_n = inq_last_6mths;
    open_acc_n = open_acc;
	revol_util_n = input(revol_util,percent.);

	keep id_n interest LoanDefFlag fyear employed inc_loan_cover revol_bal_loan_cover late_fee_ratio out_prncp_ratio
	    /*total_rec_prncp_ratio*/ dti_n delinq_2yrs_n inq_last_6mths_n open_acc_n revol_util_n ;
run;

*calculate variables for regression;
data Loanstats_2016;
    set Loanstats_2016;
	id_n = input(id,8.);
	if Loan_Status = "Fully Paid" then LoanDefFlag = 0 ;
	else if Loan_Status = "Charged Off" then LoanDefFlag = 1 ;
	else if Loan_Status = "Default" then LoanDefFlag = 1 ;
	else delete;

	fyear = input(substr(issue_d,5,8),8.);

	if emp_length = "< 1 year" then employed = 0;
	else if emp_length = "1 year" then employed = 1;
	else if emp_length = "2 years" then employed = 2;
	else if emp_length = "3 years" then employed = 3;
	else if emp_length = "4 years" then employed = 4;
	else if emp_length = "5 years" then employed = 5;
	else if emp_length = "6 years" then employed = 6;
	else if emp_length = "7 years" then employed = 7;
	else if emp_length = "8 years" then employed = 8;
	else if emp_length = "9 years" then employed = 9;
	else if emp_length = "10 years" then employed = 10;
	else if emp_length = "10+ years" then employed = 10;
	else employed = 0;

	interest = input(int_rate,percent.);
	inc_loan_cover = input(annual_inc,8.) / input(loan_amnt,8.);
	revol_bal_loan_cover = input(revol_bal,8.) / input(loan_amnt,8.);
	late_fee_ratio = input(total_rec_late_fee,8.) / input(loan_amnt,8.);
	out_prncp_ratio = input(out_prncp,8.) / input(loan_amnt,8.);
	*total_rec_prncp_ratio = input(total_rec_prncp,8.) / input(loan_amnt,8.);
    dti_n = input(dti,8.)/100;

    delinq_2yrs_n = input(delinq_2yrs,8.);
    inq_last_6mths_n = input(inq_last_6mths,8.);
    open_acc_n = input(open_acc,8.);
    revol_util_n = input(revol_util,percent.);

	keep id_n interest LoanDefFlag fyear employed inc_loan_cover revol_bal_loan_cover late_fee_ratio out_prncp_ratio
	    /*total_rec_prncp_ratio*/ dti_n delinq_2yrs_n inq_last_6mths_n open_acc_n revol_util_n ;
run;

*get the main dataset for regression;
data main;
    set Loanstats3 Loanstats_2016;
run;

proc sort data = main;
    by fyear id_n;
run;


*get the statistics of number and percentage by ranking groups;
%macro rank_statistics(vlist);
    %local k next next_rank;
    %do k = 1 %to %sysfunc(countw(&vlist));
	    %let next = %scan(&vlist,&k);
		%let next_rank = &next._rank;
		*rank to default probabilities into deciles;
		proc rank data = &next(where=(2015<=fyear<=2016 and P_1 ne .))
            groups = 10 out = &next_rank descending;
            var P_1;
            ranks &next_rank;
        run;
        *sort according to ranks;
		proc sort data = &next_rank;
            by &next_rank;
        run;
        *print the number and percentage of defaults by ranking group;
		proc tabulate data = &next_rank ;
            class &next_rank LoanDefFlag;
            table &next_rank*
                (n='Number'
                 pctn<LoanDefFlag>='Percentage'),
                LoanDefFlag / rts=50;
            title "Number and percentage of defaults according to rank of &next with descending predicted probability";
            title2 "(1 stands for default and 0 stands for normal)";
        run;
    %end;
%mend;

*output;
ods pdf file = "P:\assignment 6\6.2\Report for Assignment6.2-YuLin.pdf";
*insample estimation and prediction;
proc logistic data = main(where=(2007<=fyear<=2016)) descending
    outest = res_insample outmodel = model_insample;
    model LoanDefFlag (event='1')= employed interest inc_loan_cover revol_bal_loan_cover late_fee_ratio out_prncp_ratio
	    /*total_rec_prncp_ratio*/ dti_n delinq_2yrs_n inq_last_6mths_n open_acc_n revol_util_n;
	score data = main out = predicted_insample;
	title "Results for insample losigtic regression";
run;
quit;

*method 1 for outsample estimation and prediction;
proc logistic data = main(where=(2007<=fyear<=2014)) descending
    outest = res_outsample_1 outmodel = model_outsample_1 ;
    model LoanDefFlag (event='1')= employed interest inc_loan_cover revol_bal_loan_cover late_fee_ratio out_prncp_ratio
        /*total_rec_prncp_ratio*/ dti_n delinq_2yrs_n inq_last_6mths_n open_acc_n revol_util_n;
    title "Results for outsample losigtic regression";
run;
quit;

proc logistic inmodel = model_outsample_1;
    score data = main(where=(2015<=fyear<=2016)) out = predicted_outsample_1;
run;
quit;

%rank_statistics(predicted_outsample_1);
ods pdf close;
