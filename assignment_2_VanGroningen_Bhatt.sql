CREATE or Replace function FUNC_PERMISSIONS_OKAY
return VARCHAR2
is 
	response VARCHAR2 (35);
	parm_user_id VARCHAR2(35);
	tab_name varchar2(35);
	permission varchar2(35);
begin 
	parm_user_id := USER;
	select TABLE_NAME into tab_name from user_tab_privs where grantee = parm_user_id;
	select PRIVILEGE into permission from user_tab_privs where grantee = parm_user_id;
	if permission = 'EXECUTE' and tab_name = 'UTL_FILE'
	then response := 'Y';
	else response := 'N';
	end if;
	return response;
end;

CREATE or REPLACE TRIGGER my_trig
BEFORE INSERT
ON PAYROLL_LOAD
FOR EACH ROW
DECLARE
val number := WKIS_SEQ.NEXTVAL;

BEGIN 
INSERT INTO new_transactions
VALUES (val, :new.payroll_date, 'Accounts Payable'   , 2050 , 'C', :new.amount); 

INSERT INTO new_transactions
VALUES (val, :new.payroll_date, 'Payroll Expense'  , 4045 , 'D', :new.amount); 

:new.status := 'G';
EXCEPTION
when OTHERS then 
:new.status := 'B';
END;

CREATE OR REPLACE PROCEDURE proc_month_end
is 
CURSOR trans_cur IS SELECT * FROM account where account_type_code = 'RE';
CURSOR trans_cur_2 IS SELECT * FROM account where account_type_code = 'EX';
balance_amount account%ROWTYPE;
credit_amount account%ROWTYPE;
val number := WKIS_SEQ.NEXTVAL;


begin 
open trans_cur ;
fetch trans_cur into balance_amount;
if (balance_amount.account_balance > 0) then 
insert into new_transactions
VALUES (val, SYSDATE, 'Accounts Payable' , balance_amount.account_no , 'D', balance_amount.account_balance); 
insert into new_transactions
VALUES (val, SYSDATE, 'Payroll Expense' , 5555 , 'C', balance_amount.account_balance); 
end if;
close trans_cur;

open trans_cur_2 ;
fetch trans_cur_2 into credit_amount;
if (credit_amount.account_balance > 0 ) then 
insert into new_transactions
VALUES (val, SYSDATE, 'Payroll Expense' , credit_amount.account_no , 'C', credit_amount.account_balance);
insert into new_transactions
VALUES (val, SYSDATE, 'Accounts Payable' , 5555 , 'D', credit_amount.account_balance);  
end if;
close trans_cur_2;


end;

CREATE OR REPLACE PROCEDURE proc_export_csv
(dirAlias IN varchar2, fileName in varchar2) 
is 
current_row new_transactions%ROWTYPE;
CURSOR trans_cur IS SELECT * FROM new_transactions;
v_filehandle utl_file.file_type;
begin
v_filehandle := utl_file.fopen(dirAlias, fileName, 'w');
utl_file.put (v_filehandle, 'Transaction Report');
open trans_cur;
LOOP 
FETCH trans_cur into current_row; 
EXIT WHEN trans_cur%NOTFOUND;
utl_file.put(v_filehandle,current_row);
end loop;

utl_file.Fclose(v_filehandle);



end;
11 



	