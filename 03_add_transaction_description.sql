DECLARE
 v_location        SDO_GEOMETRY; 
 v_comment         VARCHAR2(30); 
 v_type            VARCHAR2(10); 
 v_timestamp       DATE;
 v_json            JSON; 
 transfer_document JSON_OBJECT_T := new JSON_OBJECT_T;

 v_account         NUMBER := -1;

 function add_time(p_date in date) return date as
    v_time int := 0;
 begin
    v_time := dbms_random.value(1,3); -- 1 = minutes, 2 = hours, 3 = days

    if     v_time = 1 then return p_date + dbms_random.value(1,30)/24/60; -- return minutes
     elsif v_time = 2 then return p_date + dbms_random.value(1,24)/24;    -- return hours
     else                  return p_date + dbms_random.value(1,5);        -- return days
    end if;
 end;

BEGIN
    -- for each account
    FOR i IN (SELECT src_acct_id, txn_id FROM transactions order by src_acct_id, txn_id)
    LOOP
        -- get a random location
        SELECT location INTO v_location
        FROM sample_addresses
        ORDER BY round(dbms_random.value(1,4000))
        FETCH FIRST 1 ROWS ONLY;

        -- get a random comment
        SELECT message INTO v_comment
        FROM transfer_messages
        WHERE id = round(dbms_random.value(1,100)); 

        -- get a random transfer type
        SELECT name INTO v_type
        FROM transfer_types
        WHERE id = round(dbms_random.value(1,3)); 
        
        -- timestamp transaction order
        if (i.src_acct_id != v_account)
        then
            v_timestamp := add_time(TO_DATE('2025-07-01 00:00:00', 'YYYY-MM-DD HH24:MI:ss'));
        else
            v_timestamp := add_time(v_timestamp);
        end if;

        v_account := i.src_acct_id;

/*
        SELECT TO_CHAR(
                    TO_DATE('2025-07-01 00:00:00', 'YYYY-MM-DDHH24:MI:ss') +
                            DBMS_RANDOM.VALUE(0,
                                              TO_DATE('2025-07-01 00:00:00', 'YYYY-MM-DD HH24:MI:ss') - 
                                              TO_DATE('2025-07-01 02:00:00', 'YYYY-MM-DD HH24:MI:ss')), 
                    'YYYY-MM-DD"T"HH24:MI:SS')
        into v_timestamp; */

        -- create a json description for the transfer
        transfer_document.put('type', v_type);
        transfer_document.put('timestamp', to_char(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS'));   -- ISO 8601 date format
        transfer_document.put('location', JSON(SDO_UTIL.TO_GEOJSON(v_location))); 
        transfer_document.put('message', v_comment); 

        -- update bank tranfers with json description
        v_json := transfer_document.to_json; 
        
        UPDATE transactions
        SET description = v_json
        WHERE txn_id = i.txn_id; 
        
    END LOOP; 

    COMMIT; 
END; 
/