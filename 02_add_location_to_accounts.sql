-- Update customer account and branches locations using sample_addresses table as reference
DECLARE
 v_street   VARCHAR2(256);
 v_city     VARCHAR2(64);
 v_region   VARCHAR2(5);
 v_zip      VARCHAR2(15);
 v_country  VARCHAR2(20);
 v_location SDO_GEOMETRY; 
BEGIN

    FOR i IN (SELECT id FROM branches)
    LOOP
        SELECT street, city, region, zip, country, location
        INTO v_street, v_city, v_region, v_zip, v_country, v_location
        FROM sample_addresses
        WHERE region in ('SP', 'RJ', 'MG', 'PR')
        ORDER BY ROUND(dbms_random.value(1,4403))
        FETCH FIRST 1 ROWS ONLY;

        UPDATE branches
        SET street          = v_street,
            city            = v_city,
            region          = v_region,
            zip             = v_zip,
            country         = v_country,
            branch_location = v_location
        WHERE id = i.id; 
    END LOOP;

    FOR i IN (SELECT id FROM accounts)
    LOOP
        SELECT street, city, region, zip, country, location
        INTO v_street, v_city, v_region, v_zip, v_country, v_location
        FROM sample_addresses
        WHERE region in ('SP', 'RJ', 'MG', 'PR')
        ORDER BY ROUND(dbms_random.value(1,4403))
        FETCH FIRST 1 ROWS ONLY;

        UPDATE accounts
        SET street          = v_street,
            city            = v_city,
            region          = v_region,
            zip             = v_zip,
            country         = v_country,
            customer_location = v_location
        WHERE id = i.id; 
    END LOOP; 
    
    COMMIT; 
END; 
/

