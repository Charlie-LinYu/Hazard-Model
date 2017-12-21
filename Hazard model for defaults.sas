proc printto log = "P:\assignment 6\6.1\logfile";
run;

options ls=70 nodate nocenter;

libname CRSP "Q:\Data-ReadOnly\CRSP\";

libname COMP "Q:\Data-ReadOnly\COMP\";

/*
all variables are from the last year
*/
data comp_funda_data;
    set COMP.funda (where=(indfmt="INDL" and datafmt="STD" and popsrc="D"
        and fic="USA" and consol="C" and fyear>=1961 and fyear<=2015)
		keep = cusip fyear indfmt datafmt popsrc fic consol dlc dltt at lt act lct re oiadp sale ni pi dp);

    cusip = substr(cusip,1,8);

	year = fyear + 1;

	array change1 _numeric_;
    do over change1;
	    if change1 = . then change1 = 0;
	end;

    net_asset = at - lt;

    *negative_nt is a 0-1 variable to indicate whether the net asset is below zero;
	if net_asset <= 0 then negative_nt = 1;
	else negative_nt = 0;

    *wcta = Working Capital / Total Assets;
	wcta = (act-lct)/at;
    *reta = Retained Earnings / Total Assets;
	reta = re/at;
    *ebta = Earnings before interest and taxes / Total assets;
	ebta = oiadp/at;
    *slta = Sales / Total Assets;
    slta = sale/at;
    *cacl = Current Assets / Current Liabilities ;
	cacl = act/lct;
    *nita = Net Income / Total Assets;
	nita = ni/at;
    *tlta = Total Liabilities / Total Assets;
	tlta = lt/at;
    *funds_operation = Funds from operations/Total liabilities;
	funds_operation = (pi+dp)/lt;
	dlc = dlc * 1000000;
	dltt = dltt * 1000000;
	F = dlc + 0.5 * dltt;

	keep cusip year negative_nt wcta reta ebta lt slta cacl nita tlta funds_operation F;
run;

/*
the value of annret, sigmae and E is from the last year
*/
proc sql;
    create table stock_data as
	select permno, cusip, year(date)+1 as year, exp(sum(log(1+ret)))-1 as annret,
        std(ret)*sqrt(250) as sigmae, avg(abs(prc)*shrout*1000) as E
	from CRSP.dsf(where=(1961<=year(date)<=2015))
	group by cusip, permno, year;
quit;

data stock_data;
    set stock_data;
	if annret = . or sigmae = . or E = . then delete;
	*metl = E/lt;
run;

proc import datafile='Q:\Data-ReadOnly\SurvivalAnalysis\BR1964_2014.csv'
    out = BR1964_2014 dbms=csv replace;
run;

data BR1964_2014;
    set BR1964_2014;
	year = year(bankruptcy_dt);
	bankruptcy = 1;
	keep permno year bankruptcy;
run;

*Combine the stock data with companies' fundamental data;
proc sql;
    create table funda_stock as
	select *
	from stock_data, comp_funda_data
	where stock_data.cusip = comp_funda_data.cusip and
        stock_data.year = comp_funda_data.year
	order by stock_data.year, stock_data.permno;
quit;

proc sort data = BR1964_2014;
    by year permno;
run;

*merge the bankruptcy data into the main dataset;
data funda_stock_2;
    merge BR1964_2014(in = a) funda_stock(in = b) ;
    by year permno;
    if b;
	if bankruptcy = . then bankruptcy = 0;
    *melt = Market Equity / Total Liabilities;
    metl = E/lt;
	Naive_Sigma = E/(E+F)*sigmae + F/(E+F)*(0.05+0.25*sigmae);
	DD = (log((E+F)/F) + (annret - (Naive_Sigma**2) / 2)*1)/(Naive_Sigma * sqrt(1));
	PD = 1 - CDF('NORMAL',DD,0,1);
run;

*insample estimation and prediction;
proc logistic data = funda_stock_2(where=(1962<=year<=2014)) descending
    outest = res_insample outmodel = model_insample noprint;
    model bankruptcy (event='1')= annret sigmae negative_nt wcta reta ebta metl slta cacl nita tlta funds_operation PD;
	score data = funda_stock_2 out = predicted_insample;
run;
quit;

*method 1 for outsample estimation and prediction;
proc logistic data = funda_stock_2(where=(1962<=year<=1990)) descending
    outest = res_outsample_1 outmodel = model_outsample_1 noprint;
    model bankruptcy (event='1')= annret sigmae negative_nt wcta reta ebta metl slta cacl nita tlta funds_operation PD;
run;
quit;

proc logistic inmodel = model_outsample_1;
    score data = funda_stock_2(where=(1991<=year<=2014)) out = predicted_outsample_1;
run;
quit;

*method 2 for outsample estimation and prediction;
proc sql;
    create table predicted_outsample_2
	    like predicted_outsample_1;
quit;

%macro method2(y1,y2);
*loop through years;
%do yr = &y1 %to &y2;
    *logistic regress through data from 1962 to last year;
    proc logistic data = funda_stock_2(where=(1962<=year<=(&yr-1))) descending
        outest = res_outsample_2 outmodel = model_outsample_2 noprint;
        model bankruptcy (event='1')= annret sigmae negative_nt wcta reta ebta metl slta cacl nita tlta funds_operation PD;
    run;
    quit;
    *predict the probability according to the model above;
    proc logistic inmodel = model_outsample_2;
        score data = funda_stock_2(where=(year=&yr)) out = tmp_2;
    run;
    quit;
    *add new predicted results to the result dataset;
    proc sql;
        insert into predicted_outsample_2
	    select * from tmp_2;
    quit;

%end;
%mend;

%method2(1991,2014);
run;

*method 3 for outsample estimation and prediction;
proc sql;
    create table predicted_outsample_3
	    like predicted_outsample_1;
quit;

%macro method3(y1,y2);
%do yr = &y1 %to &y2;
    *logistic regress through data from a fixed period of 29 years;
    proc logistic data = funda_stock_2(where=((&yr-29)<=year<=(&yr-1))) descending
        outest = res_outsample_3 outmodel = model_outsample_3 noprint;
        model bankruptcy (event='1')= annret sigmae negative_nt wcta reta ebta metl slta cacl nita tlta funds_operation PD;
    run;
    quit;
    *predict the probability according to the model above;
    proc logistic inmodel = model_outsample_3;
        score data = funda_stock_2(where=(year=&yr)) out = tmp_3;
    run;
    quit;
    *add new predicted results to the result dataset;
    proc sql;
        insert into predicted_outsample_3
	    select * from tmp_3;
    quit;

%end;
%mend;

%method3(1991,2014);
run;

%macro rank_statistics(vlist);
    %local k next next_rank;
    %do k = 1 %to %sysfunc(countw(&vlist));
	    %let next = %scan(&vlist,&k);
		%let next_rank = &next._rank;
		*rank to default probabilities into deciles;
		proc rank data = &next(where=(1991<=year<=2014 and P_1 ne .))
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
            class &next_rank bankruptcy;
            table &next_rank*
                (n='Number'
                 pctn<bankruptcy>='Percentage'),
                bankruptcy / rts=50;
            title "Number and percentage of defaults according to rank of &next with descending predicted probability";
            title2 "(1 stands for default and 0 stands for normal)";
        run;
    %end;
%mend;

*output;
ods pdf file = "P:\assignment 6\6.1\Report for Assignment6.1-YuLin.pdf";
%rank_statistics(predicted_insample predicted_outsample_1 predicted_outsample_2 predicted_outsample_3);
ods pdf close;
