-- Update customer job title
DECLARE
 v_job VARCHAR2(30); 
BEGIN
    FOR i IN (SELECT id FROM accounts)
    LOOP
        SELECT name INTO v_job
        FROM jobs
        WHERE id = round(dbms_random.value(1,50)); 

        UPDATE accounts
        SET job_title = v_job
        WHERE id = i.id; 
    END LOOP; 

    COMMIT; 
END; 
/
