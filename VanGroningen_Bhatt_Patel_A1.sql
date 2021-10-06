SET SERVEROUTPUT ON;

DECLARE 
CURSOR trans_cur IS SELECT DISTINCT transaction_no, transaction_date, description FROM new_transactions ORDER BY transaction_no;
CURSOR trans_cur_2 is select * from new_transactions for update;
trans_no number;
trans_date date;
descrip varchar2(100);
account_num number;
trans_type char(1);
trans_amt number;
trans_credit CONSTANT char(1) := 'C';
trans_debit CONSTANT char(1) := 'D';
account_bal number;
trans_default char(1);
credit_temp number := 0;
debit_temp number := 0;
missing_trans_num EXCEPTION;
neg_transaction_num EXCEPTION;
invalid_type EXCEPTION;
cred_debit_not_equal EXCEPTION;
invalid_account_error EXCEPTION;
my_errm varchar2(32000);

BEGIN 

-- loop through the first cursor and populate the transaction_history table
FOR rec_cur IN trans_cur LOOP
trans_no := rec_cur.transaction_no;
trans_date := rec_cur.transaction_date;
descrip := rec_cur.description;

-- catch null exception
	begin 
	if trans_no is null then 
	raise missing_trans_num;
	end if;
	exception
	WHEN missing_trans_num then insert into WKIS_ERROR_LOG(transaction_no, transaction_date, description, error_msg)
	values (trans_no, trans_date, descrip, 'Transaction number is null');
	
	continue;
	end;
	
	
INSERT INTO TRANSACTION_HISTORY (transaction_no, transaction_date, description)
values (trans_no, trans_date, descrip); 

	
end loop;

-- loop through the second cursor and populate the transaction_detail table as well as update the account table 
for rec_cur_second in trans_cur_2 LOOP
trans_no := rec_cur_second.transaction_no;
trans_date := rec_cur_second.transaction_date;
descrip := rec_cur_second.description;
account_num := rec_cur_second.account_no;
trans_no := rec_cur_second.transaction_no;
trans_type := rec_cur_second.transaction_type;
trans_amt := rec_cur_second.transaction_amount;
	
	
	-- catch the missing num again but dont print to error log
	begin 
	if trans_no is null then 
	raise missing_trans_num;
	end if;
	exception
	WHEN missing_trans_num then 
	continue;
	end;
	
	-- catch negative value exception for trans_amt
	begin 
	if trans_amt < 0 then 
	raise neg_transaction_num;
	end if;
	exception
	WHEN neg_transaction_num then insert into WKIS_ERROR_LOG(transaction_no, transaction_date, description, error_msg)
	values (trans_no, trans_date, descrip, 'Transaction ammount is less than 0');
	
	continue;
	end;
	-- catch the trans_type not being 'c' or 'd'
	begin 
		if trans_type != trans_debit and trans_type != trans_credit then 
		raise invalid_type;
		end if;
		exception
		WHEN invalid_type then insert into WKIS_ERROR_LOG(transaction_no, transaction_date, description, error_msg)
		values (trans_no, trans_date, descrip, 'Transaction type is neither credit (C) or debit (D)');
		
		continue;
	end;
	-- catch invalid account number 
	begin 
		if account_num < 1000 or account_num > 5000 and account_num != 5555 then 
		raise invalid_account_error;
		end if;
		exception
		when invalid_account_error then insert into WKIS_ERROR_LOG(transaction_no, transaction_date, description, error_msg)
		values (trans_no, trans_date, descrip, 'the account number is invalid');
		
		continue;
	end;
	
insert into TRANSACTION_DETAIL (account_no, transaction_no, transaction_type, transaction_amount)
values (account_num, trans_no, trans_type, trans_amt);

	
	
	-- updating the account table
	select default_trans_type
	into trans_default
	from account_type JOIN account ON (account_type.account_type_code = account.account_type_code)
	where account_no = rec_cur_second.account_no;
	if trans_type = trans_default then update account set account.account_balance = account.account_balance + trans_amt where account_no = rec_cur_second.account_no;
	else update account set account.account_balance = account.account_balance - trans_amt where account_no = rec_cur_second.account_no;
	
	end if;
	
	--catch if credit is not equal to debit
	
	if trans_type = trans_credit then credit_temp := credit_temp + trans_amt;
	elsif trans_type = trans_debit then debit_temp := debit_temp + trans_amt;
	end if;
	delete from new_transactions 
	where current of trans_cur_2;
	
	end loop;
	
	if credit_temp != debit_temp then 
	raise cred_debit_not_equal;
	end if;
	
	commit;
	
	EXCEPTION
		when cred_debit_not_equal then insert into WKIS_ERROR_LOG(error_msg)
		values ('Credit and debit are not equal');
	when others then 
	my_errm := SQLERRM;
	insert into WKIS_ERROR_LOG (error_msg)
	values (my_errm);
	

	

END;
/
