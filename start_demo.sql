@restart_demo.sql

--- #####################################################################################################################################################
--- DEMO 1: RELATIONAL
--- #####################################################################################################################################################

-- drop tables if exist
DROP TABLE IF EXISTS TRANSACTIONS; 
DROP TABLE IF EXISTS ACCOUNTS;
DROP TABLE IF EXISTS BRANCHES; 





-- create tables
CREATE TABLE IF NOT EXISTS BRANCHES (
    ID              INTEGER         NOT NULL PRIMARY KEY,
    NAME            VARCHAR2(20)    NOT NULL    
); 

CREATE TABLE IF NOT EXISTS ACCOUNTS (
    ID              NUMBER       NOT NULL PRIMARY KEY,
    NAME            VARCHAR(400) NOT NULL,
    BALANCE         NUMBER(20,2) RESERVABLE CHECK (BALANCE >= 0) NOT NULL, -- lock-free
    BRANCH_ID       INTEGER      NOT NULL REFERENCES BRANCHES
); 

CREATE TABLE IF NOT EXISTS TRANSACTIONS (
    TXN_ID          NUMBER          NOT NULL PRIMARY KEY,
    SRC_ACCT_ID     NUMBER          NOT NULL REFERENCES ACCOUNTS, -- source account id
    DST_ACCT_ID     NUMBER          NOT NULL REFERENCES ACCOUNTS, -- target account id
    DESCRIPTION     VARCHAR(400)    NOT NULL,
    AMOUNT          NUMBER          NOT NULL
); 





-- load data
Load BRANCHES data\BRANCHES.csv 
Load ACCOUNTS data\ACCOUNTS.csv 
Load TRANSACTIONS data\TRANSACTIONS.csv





-- count
SELECT branches, accounts, transactions
FROM 
    ( SELECT count(*) AS branches     FROM BRANCHES ),
    ( SELECT count(*) AS accounts     FROM ACCOUNTS ),
    ( SELECT count(*) AS transactions FROM TRANSACTIONS );





-- top 3 branch per number of accounts
SELECT b.name   AS branch_name, 
       count(*) AS total_accounts
FROM ACCOUNTS a, BRANCHES b
WHERE a.branch_id = b.id
GROUP BY branch_name
ORDER BY total_accounts DESC
FETCH FIRST 3 ROWS ONLY;





-- top 3 accounts with more transactions
SELECT a.name        as customer_name,
       count(*)      as total_transactions       
FROM ACCOUNTS a, TRANSACTIONS t
WHERE a.id = t.src_acct_id
GROUP BY a.name
ORDER BY total_transactions DESC
FETCH FIRST 3 ROWS ONLY; 





-- largest amount per branch, top 5 branches
SELECT branch_name, customer_name, amount
FROM (
    SELECT  b.name AS branch_name, a.name AS customer_name, t.amount,
            MAX(t.amount) OVER (PARTITION BY b.id) as max_amount
    FROM ACCOUNTS a, 
         TRANSACTIONS t, 
         BRANCHES b
    WHERE a.id        = t.src_acct_id
      AND a.branch_id = b.id)
WHERE amount = max_amount
ORDER BY amount DESC FETCH FIRST 5 ROWS ONLY;





--- #####################################################################################################################################################
--- DEMO 2: SPATIAL
--- #####################################################################################################################################################

-- Add address location in the ACCOUNTS and BRANCHES tables
ALTER TABLE ACCOUNTS ADD (
    street  VARCHAR2(256),
    city    VARCHAR2(64),
    region  VARCHAR2(5),
    zip     VARCHAR2(15),
    country VARCHAR2(20),
    customer_location SDO_GEOMETRY
);

ALTER TABLE BRANCHES ADD (
    street  VARCHAR2(256),
    city    VARCHAR2(64),
    region  VARCHAR2(5),
    zip     VARCHAR2(15),
    country VARCHAR2(20),
    branch_location SDO_GEOMETRY
);





SELECT * FROM BRANCHES FETCH FIRST 5 ROWS ONLY; 

@02_add_location_to_accounts.sql

SELECT * FROM BRANCHES FETCH FIRST 5 ROWS ONLY;





-- spatial indexes
CREATE INDEX ix_accounts
ON accounts (customer_location)
INDEXTYPE IS MDSYS.SPATIAL_INDEX;

CREATE INDEX ix_branches
ON branches (branch_location)
INDEXTYPE IS MDSYS.SPATIAL_INDEX;





------------------------------
-- Proximity Query
------------------------------

-- Find closest branches to a customer
SELECT b.name as branch_name 
FROM 
      ACCOUNTS a,
      BRANCHES b
WHERE 
      a.name = 'VERNIE'
  AND SDO_WITHIN_DISTANCE(b.branch_location,                        
                          a.customer_location,
                          'distance=20 unit=KM') = 'TRUE'; 





-- Find closest branches to a customer, using nearest neighbor first
SELECT  b.name                       as branch_name, 
        ROUND(SDO_NN_DISTANCE(1), 2) as distance_km
FROM 
      ACCOUNTS a, BRANCHES b
WHERE 
      a.name = 'VERNIE' 
  AND SDO_NN(b.branch_location,
             a.customer_location,                           
             'sdo_num_res=3 unit=KM', 1) = 'TRUE'
ORDER BY distance_km;





-- Show the distance between customers within a transaction, filter by name
SELECT src.NAME      as src_name, 
       t.amount      as amount,
       dst.NAME      as dst_name,
       ROUND(SDO_GEOM.SDO_DISTANCE(src.customer_location, 
                                   dst.customer_location, 
                                   0.005, 'unit=KM')) AS km_distance
FROM
    ACCOUNTS src, ACCOUNTS dst, TRANSACTIONS t
WHERE src.id = t.src_acct_id
  and dst.id = t.dst_acct_id
  and src.id != dst.id  
  and src.name = 'VERNIE'
ORDER BY km_distance DESC; 





------------------------------
-- Containment Query
------------------------------

SELECT * FROM ZONES;





-- Find branches within a zone
SELECT  b.name as branch_name,
        a.name as zone_name, 
        b.STREET
FROM 
      ZONES a, BRANCHES b
WHERE SDO_INSIDE( b.branch_location, 
                  a.area ) = 'TRUE';
  




------------------------------
-- Utiliy Query
------------------------------

SELECT
      SDO_UTIL.TO_GEOJSON(b.branch_location) as geojson_format      
FROM BRANCHES b
FETCH FIRST 5 ROWS ONLY;





-- geojson.io zones (polygons)
SELECT 
    '{ "type": "FeatureCollection", "features": ' ||
      JSON_ARRAYAGG(
        '{"type": "Feature", "properties": {' ||
        '"branch_name": "' || name || '"}, ' ||
        '"geometry": ' || SDO_UTIL.TO_GEOJSON(area) ||                              
      '}' FORMAT JSON) ||
    ' }' AS geojson_format      
FROM ZONES;





-- geojson.io branches (points)
SELECT 
    '{ "type": "FeatureCollection", "features": ' ||
      JSON_ARRAYAGG(
        '{"type": "Feature", "properties": {' ||
        '"branch_name": "' || name || '"}, ' ||
        '"geometry": ' || SDO_UTIL.TO_GEOJSON(branch_location) ||                              
      '}' FORMAT JSON RETURNING CLOB) ||
    ' }' AS geojson_format      
FROM BRANCHES;





-- geojson.io branches (points and polygons)
SELECT  '{ "type": "FeatureCollection", "features": ' || 
         JSON_ARRAYAGG( gformat FORMAT JSON RETURNING CLOB) || ' }' AS geojson_format
FROM (
  SELECT  '{"type": "Feature", "properties": {' ||
          '"zone_name": "' || name || '"}, ' ||
          '"geometry": ' || SDO_UTIL.TO_GEOJSON(area) || '}' as gformat    
  FROM ZONES
  UNION ALL
  SELECT  '{"type": "Feature", "properties": {' ||
          '"branch_name": "' || name || '"}, ' ||
          '"geometry": ' || SDO_UTIL.TO_GEOJSON(branch_location) || '}' as gformat    
  FROM BRANCHES b  
);





--- #####################################################################################################################################################
--- DEMO 3: JSON
--- #####################################################################################################################################################

-- JSON Duality View
DROP VIEW IF EXISTS transfers; 

CREATE JSON RELATIONAL DUALITY VIEW TRANSFERS AS
    TRANSACTIONS @insert @update
    {
        _id     : txn_id,
        amount  : amount,
        message : description,
        source_account : ACCOUNTS @insert @update @link (from : ["SRC_ACCT_ID"]) {account_id : id, name : name},
        target_account : ACCOUNTS @insert @update @link (from : ["DST_ACCT_ID"]) {account_id : id, name : name}
    }; 





SELECT JSON_SERIALIZE(t.data pretty) as json_document
FROM TRANSFERS t
FETCH FIRST 1 ROWS ONLY; 





SELECT t.txn_id      as "_ID",
       src.id        as SRC_ACCOUNT_ID,
       src.NAME      as SRC_NAME, 
       t.dst_acct_id as DST_ACCOUNT_ID,
       dst.NAME      as DST_NAME,
       t.amount      as AMOUNT,
       t.description as MESSAGE
FROM
    ACCOUNTS src,
    ACCOUNTS dst,      
    TRANSACTIONS t
WHERE src.id = t.src_acct_id
  and dst.id = t.dst_acct_id  
  and t.txn_id = 247; 





INSERT INTO TRANSFERS t (data)
values ('
        {
            "_id" : 10000, 
            "amount" : 3,  
            "message" : "thanks for the money",  
            "source_account" :  { 
                                    "account_id" : 269, 
                                    "name" : "DANIKA" },  
            "target_account" :  { 
                                    "account_id" : 52,    
                                    "name" : "KIMBERLY"}
                                }'
); 

commit;





SELECT JSON_SERIALIZE(t.data pretty) as json_document
FROM TRANSFERS t
WHERE t.data."_id" = 10000;





SELECT t.txn_id      as "_ID",
       src.id        as SRC_ACCOUNT_ID,
       src.NAME      as SRC_NAME, 
       t.dst_acct_id as DST_ACCOUNT_ID,
       dst.NAME      as DST_NAME,
       t.amount      as AMOUNT,
       t.description as MESSAGE
FROM
    ACCOUNTS src,
    ACCOUNTS dst,      
    TRANSACTIONS t
WHERE src.id = t.src_acct_id
  and dst.id = t.dst_acct_id  
  and t.txn_id = 10000; 





INSERT INTO TRANSACTIONS (TXN_ID, SRC_ACCT_ID, DST_ACCT_ID, DESCRIPTION, AMOUNT)
VALUES (20000, 52, 269, 'giving your money back', 3); 

commit; 





SELECT t.txn_id      as "_ID",
       src.id        as SRC_ACCOUNT_ID,
       src.NAME      as SRC_NAME, 
       t.dst_acct_id as DST_ACCOUNT_ID,
       dst.NAME      as DST_NAME,
       t.amount      as AMOUNT,
       t.description as MESSAGE
FROM
    ACCOUNTS src,
    ACCOUNTS dst,      
    TRANSACTIONS t
WHERE src.id = t.src_acct_id
  and dst.id = t.dst_acct_id  
  and t.txn_id = 20000; 





SELECT JSON_SERIALIZE(t.data pretty) as json_document
FROM TRANSFERS t
WHERE t.data."_id" = 20000; 





-- Collection Tables
DROP TABLE IF EXISTS exchange_rate; 

CREATE JSON COLLECTION TABLE exchange_rate; 

INSERT INTO exchange_rate (data)
VALUES ('{
          "source":"USD",
          "target":"BRL",
          "rate":5.43
        }'); 

commit; 





SELECT JSON_SERIALIZE(data pretty) AS data FROM exchange_rate; 






---
-- run python soda.py
---






SELECT JSON_SERIALIZE(data pretty) AS data FROM exchange_rate; 






-- dot notation
select t.data.source.string() as source_name,
       t.data.target.string() as target_name,
       t.data.rate.number()   as rate
from exchange_rate t; 





-- filter
select t.data.source.string() as source_name,
       t.data.target.string() as target_name,
       t.data.rate.number()   as rate
from exchange_rate t
where t.data.target.string() = 'MXN';





-- SQL/JSON

SELECT * FROM TRANSACTIONS FETCH FIRST 5 ROWS ONLY; 

ALTER TABLE TRANSACTIONS DROP COLUMN DESCRIPTION;  
ALTER TABLE TRANSACTIONS ADD DESCRIPTION JSON; 

-- add json descriptions to transfers in the following format:  { 'type', 'timestamp', 'geojson', 'comment' }
@03_add_transaction_description.sql

-- visualize
SELECT * FROM TRANSACTIONS FETCH FIRST 5 ROWS ONLY; 





SELECT json_serialize(t.DESCRIPTION pretty) as json_document
FROM TRANSACTIONS t
WHERE txn_id = 1;






-- total transfers per transfer type (dot notation)
SELECT t.description.type.string() as transfer_type, 
       COUNT(*) AS CNT
FROM TRANSACTIONS t
GROUP BY t.description.type.string()
ORDER BY 2 DESC; 






-- total transfers per transfer type (json function)
SELECT json_value(t.description, '$.type') as transfer_type, 
       COUNT(*) AS CNT
FROM TRANSACTIONS t
GROUP BY json_value(t.description, '$.type')
ORDER BY 2 DESC; 





-- create index and filter
DROP INDEX IF EXISTS ix_transfer_type;

CREATE INDEX ix_transfer_type 
on TRANSACTIONS t (t.description.type.string()); 





-- Query with the following conditions:
-- a) ZULMA`s account
-- a) Transfer type = LGEC
-- b) amount > 100
-- c) top 3 distance from the customer home
SELECT 
      t.txn_id,
      t.amount,  
      t.description.type.string() as transfer_type,          
      ROUND(
        SDO_GEOM.SDO_DISTANCE(
                              src.customer_location, 
                              SDO_UTIL.FROM_GEOJSON(t.description.location), 
                              0.005, 
                              'unit=KM')
      ) AS dist_km_between_home_and_transfer_location
FROM
    ACCOUNTS src,        
    TRANSACTIONS t
WHERE src.id = t.src_acct_id
 AND t.description.type.string() = 'LGEC'
 AND t.amount > 100
 and src.NAME = 'ZULMA'
ORDER BY dist_km_between_home_and_transfer_location DESC
FETCH FIRST 3 ROWS ONLY; 





-- Relational + Spatial + JSON
-- Different transactions for the same customer, in larger distances, within a specified timestamp
WITH bank_transactions AS (
    SELECT  t1.SRC_ACCT_ID AS account_id,
            t1.description.timestamp.dateWithTime() as t1_timestamp,
            t2.description.timestamp.dateWithTime() as t2_timestamp,
            ROUND(SDO_GEOM.SDO_DISTANCE(SDO_UTIL.FROM_GEOJSON(t1.description.location), 
                                        SDO_UTIL.FROM_GEOJSON(t2.description.location), 
                                        0.005, 
                                        'unit=KM')) AS distance_km
    FROM TRANSACTIONS t1,
         TRANSACTIONS t2
    WHERE t1.SRC_ACCT_ID = t2.SRC_ACCT_ID
      AND t1.TXN_ID     != t2.TXN_ID
      AND t2.description.timestamp.dateWithTime() > t1.description.timestamp.dateWithTime()
) SELECT account_id,
         to_char(t1_timestamp, 'DD-MON-YYYY HH24:MI:SS')  AS t1_timestamp,
         to_char(t2_timestamp, 'DD-MON-YYYY HH24:MI:SS')  AS t2_timestamp,
         ROUND((t2_timestamp - t1_timestamp) * 24 * 60,2) AS diff_minutes,
         distance_km
  FROM bank_transactions
  WHERE (t2_timestamp - t1_timestamp) <= 10/24/60 -- 10 minutes
    AND distance_km > 100                         -- 100 km
  ORDER BY distance_km DESC
  FETCH FIRST 5 ROWS ONLY;





--- #####################################################################################################################################################
--- DEMO 4: TEXT
--- #####################################################################################################################################################

-- FULL TEXT SEARCH

ALTER TABLE ACCOUNTS ADD JOB_TITLE VARCHAR2(30); 

SELECT ID, NAME, JOB_TITLE FROM ACCOUNTS FETCH FIRST 10 ROWS ONLY; 

SELECT * FROM JOBS; 

@04_add_jobs.sql

SELECT ID, NAME, JOB_TITLE FROM ACCOUNTS FETCH FIRST 10 ROWS ONLY; 

CREATE SEARCH INDEX IX_ACCOUNT_JOB ON ACCOUNTS (job_title);






-- Keyword
SELECT id, name, job_title
FROM ACCOUNTS
WHERE CONTAINS(job_title, 'Veterinarian') > 0; 






-- Fuzzy
SELECT id, name, job_title
FROM ACCOUNTS
WHERE CONTAINS(job_title, 'fuzzy(Vetrynaryan)') > 0; 





-- Wildcard
SELECT id, name, job_title
FROM ACCOUNTS
WHERE CONTAINS(job_title, '%Engineer') > 0; 






-- Fuzzy and AND
SELECT id, name, job_title
FROM ACCOUNTS
WHERE CONTAINS(job_title, 'fuzzy(Cyvil) AND Engineer') > 0; 






-- NOT
SELECT id, name, job_title
FROM ACCOUNTS
WHERE CONTAINS(job_title, 'Engineer NOT Civil') > 0; 






-- FULL TEXT SEARCH WITH JSON
DROP INDEX IF EXISTS IX_TRANSFER_COMMENT; 

CREATE SEARCH INDEX IX_TRANSFER_COMMENT 
ON TRANSACTIONS (description) FOR JSON;




SELECT txn_id, src_acct_id, dst_acct_id, amount, t.description.message.string() as message
FROM TRANSACTIONS t
WHERE JSON_TEXTCONTAINS(t.description, '$.message', 'Netflix%'); 





-- Relational + Spatial + JSON + Text
SELECT src.id as SRC_ACCOUNT_ID,
       src.NAME as src_name, 
       t.amount,  
       t.description.type.string()    as transfer_type,
       t.description.message.string() as message,          
       ROUND(SDO_GEOM.SDO_DISTANCE(src.customer_location, 
                                   SDO_UTIL.FROM_GEOJSON(t.description.location), 
                                                         0.005, 
                                                         'unit=KM')) AS dist_km_between_home_and_transfer_loc
FROM ACCOUNTS src, TRANSACTIONS t
WHERE src.id = t.src_acct_id
 AND t.description.type.string() = 'LGEC' AND t.amount > 100
 AND JSON_TEXTCONTAINS(t.description, '$.message', 'Bill') 
ORDER BY amount DESC
FETCH FIRST 5 ROWS ONLY; 





--- #####################################################################################################################################################
--- DEMO 5: VECTOR
--- #####################################################################################################################################################

ALTER TABLE ACCOUNTS     ADD job_vector     VECTOR;
ALTER TABLE TRANSACTIONS ADD message_vector VECTOR;

-- Check Embedding Model
select model_name from user_mining_models;





-- Generating embeddings
SELECT VECTOR_EMBEDDING(
                        all_MiniLM_L12                           -- embedding model
                        USING 'the book is on the table' AS DATA -- text to be embedded
                      ) AS embedding;





-- Update accounts and transactions with vector embeddings
UPDATE accounts
SET job_vector = VECTOR_EMBEDDING(all_MiniLM_L12 
                                  USING job_title AS DATA);
commit;

UPDATE transactions t
SET message_vector = VECTOR_EMBEDDING(all_MiniLM_L12 
                                      USING t.description.message.string() AS DATA);

commit;

SELECT job_vector FROM accounts WHERE name = 'VERNIE';



-- In-Memory Neighbor Graph Vector Index (HNSW)
DROP INDEX IF EXISTS idx_account_vector_hnsw;

CREATE VECTOR INDEX idx_account_vector_hnsw 
ON accounts (job_vector)
ORGANIZATION INMEMORY NEIGHBOR GRAPH
DISTANCE COSINE WITH TARGET ACCURACY 95;





-- Neighbor Partition Vector Index (IVF)
DROP INDEX IF EXISTS idx_account_vector_ivf;
DROP INDEX IF EXISTS idx_transaction_vector_ivf;

CREATE VECTOR INDEX idx_account_vector_ivf
ON accounts (job_vector) 
ORGANIZATION NEIGHBOR PARTITIONS
DISTANCE COSINE WITH TARGET ACCURACY 95;

CREATE VECTOR INDEX idx_transaction_vector_ivf 
ON transactions (message_vector) 
ORGANIZATION NEIGHBOR PARTITIONS
DISTANCE COSINE WITH TARGET ACCURACY 95;





-- jobs vector search
SELECT * FROM jobs;





SELECT name, job_title
FROM accounts 
ORDER BY VECTOR_DISTANCE(job_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12 
                                      USING 'someone related to planets' AS DATA)
                         , COSINE)
FETCH FIRST 3 ROWS ONLY;





SELECT name, job_title
FROM accounts
ORDER BY VECTOR_DISTANCE(job_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12 
                                      USING 'he or she works with animals' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;





SELECT name, job_title
FROM accounts 
ORDER BY VECTOR_DISTANCE(job_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12 
                                      USING 'he or she works with money' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;





-- messages vector search
SELECT * FROM transfer_messages;





SELECT txn_id, t.description.message.string() as message
FROM transactions t
ORDER BY VECTOR_DISTANCE(message_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12 
                                      USING 'message about cinema' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;





SELECT txn_id, t.description.message.string() as message
FROM transactions t 
ORDER BY VECTOR_DISTANCE(message_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12 
                                      USING 'message about sports' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;





-- Relational + Spatial + JSON + Text + Vector
SELECT txn_id, 
       a.name as customer_name,
       a.job_title,
       t.description.message.string() as message,
       ROUND(SDO_GEOM.SDO_DISTANCE(a.customer_location,  
                                   SDO_UTIL.FROM_GEOJSON(t.description.location),  
                                   0.005, 
                                   'unit=KM')) AS dist_between_home_and_transaction
FROM accounts a, transactions t
WHERE a.id = t.src_acct_id
  and t.description.type.string() = 'LGEC'
  and a.region = 'SP'  
  and CONTAINS(a.job_title, 'fuzzy(Engynier) NOT Civil') > 0
ORDER BY VECTOR_DISTANCE(message_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12 
                                      USING 'message about meals' AS DATA),
                         COSINE)
FETCH FIRST 1 ROWS ONLY;





--- #####################################################################################################################################################
--- DEMO 6: GRAPH
--- #####################################################################################################################################################


DROP PROPERTY GRAPH IF EXISTS transactions_graph; 

CREATE PROPERTY GRAPH transactions_graph
  VERTEX TABLES (
    ACCOUNTS KEY ( ID ) LABEL account PROPERTIES (ID, NAME, JOB_TITLE, JOB_VECTOR),
    BRANCHES KEY ( ID ) LABEL branch  PROPERTIES (ID, NAME)
  )
  EDGE TABLES (
    TRANSACTIONS
      SOURCE      KEY ( src_acct_id ) REFERENCES ACCOUNTS (ID)
      DESTINATION KEY ( dst_acct_id ) REFERENCES ACCOUNTS (ID)
      LABEL transfer PROPERTIES ARE ALL COLUMNS
  ); 





-- Return 5 transactions 
SELECT *
FROM GRAPH_TABLE( transactions_graph 
    MATCH (src IS account) -[t IS transfer]-> (dst IS account)           
    COLUMNS (t.txn_id    as txn_id,
             t.amount    as txn_amount, 
             src.name    as src_name,            
             dst.name    as dst_name)
) ORDER BY txn_id
FETCH FIRST 5 ROWS ONLY;





-- Find the top 5 accounts in the middle of a 2-hop chain of transfers
SELECT customer_name, count(*) as Num_In_Middle
FROM GRAPH_TABLE( transactions_graph 
    MATCH (src) -> (middle) -> (dest)           
    COLUMNS (middle.name as customer_name)
) GROUP BY customer_name
ORDER BY Num_In_Middle desc
FETCH FIRST 5 ROWS ONLY;





-- finds out who person Letisha transferred money to, either directly or indirectly via an intermediary
SELECT 'LETISHA -> ' || dst_names as path, hops, amounts
FROM GRAPH_TABLE( transactions_graph 
    MATCH (src is account) (-[t IS transfer]-> (dst is account)){1,2} (final_dst)
    WHERE src.name = 'LETISHA' 
    COLUMNS (LISTAGG(dst.name, ' -> ')  as dst_names,
             COUNT(t.txn_id)         as hops,
             JSON_ARRAYAGG(t.amount) as amounts)
) 
ORDER BY hops, amounts;





-- Check if there are any N-hop transfers that start and end at the same account
SELECT customer_account, COUNT(1) AS number_of_cycle_transfers
FROM GRAPH_TABLE( transactions_graph
    MATCH (src) -[]->{1,5} (src)
    COLUMNS (src.id AS customer_account)
) GROUP BY customer_account 
ORDER BY number_of_cycle_transfers DESC
FETCH FIRST 5 ROWS ONLY;





-- Check if there are any N-hop transfers that start and end at the same account
-- Show transaction ids
SELECT id || ' -> ' || transaction_ids as path, amounts, total_amount
FROM GRAPH_TABLE( transactions_graph
    MATCH (src) -[t]->{1,5} (src)
    WHERE src.id = 135
    COLUMNS (src.id, 
             LISTAGG(t.dst_acct_id, ' -> ') as transaction_ids,
             JSON_ARRAYAGG(t.amount) as amounts,
             SUM(t.amount) as total_amount)
) ORDER BY total_amount DESC;





-- Phone contact
ALTER TABLE accounts ADD IS_SUSPECT BOOLEAN DEFAULT FALSE;

UPDATE accounts
SET IS_SUSPECT = TRUE
WHERE name = 'LETISHA'; 

commit;





DROP TABLE IF EXISTS PHONE_CONTACTS;

CREATE TABLE PHONE_CONTACTS (
    ID                 INTEGER NOT NULL PRIMARY KEY,
    ACCT_ID_OWNER   NOT NULL REFERENCES ACCOUNTS,
    ACCT_ID_CONTACT NOT NULL REFERENCES ACCOUNTS
);

INSERT INTO PHONE_CONTACTS
VALUES (1, 135, 663),
       (2, 100, 663),
       (3, 57, 100),
       (4, 12, 135),
       (5, 42, 12),
       (6, 88, 42);

commit;





DROP PROPERTY GRAPH IF EXISTS phone_graph; 

CREATE PROPERTY GRAPH phone_graph
  VERTEX TABLES (
    ACCOUNTS KEY ( ID ) LABEL account PROPERTIES (ID, NAME, IS_SUSPECT)    
  )
  EDGE TABLES (
    PHONE_CONTACTS
      SOURCE      KEY ( acct_id_owner )   REFERENCES ACCOUNTS (ID)
      DESTINATION KEY ( acct_id_contact ) REFERENCES ACCOUNTS (ID)
      LABEL has_contact PROPERTIES (acct_id_owner, acct_id_contact)
  ); 




-- list all contacts of a suspect account
SELECT src_name || ' -> ' || contact_names as path, hops
FROM GRAPH_TABLE( phone_graph 
    MATCH (src IS account) (-[c IS has_contact]-> (dst IS account)){1,4} (dst_final)   
    WHERE dst_final.is_suspect         
    COLUMNS (src.name as src_name, 
             COUNT(c.acct_id_owner) as hops,           
             LISTAGG(dst.name, ' -> ') as contact_names)
) ORDER BY hops;





-- Relational + JSON + Vector + Graph
SELECT
        txn_id, 
        src_name, 
        src_job_title, 
        txn_amount, 
        dst_name,
        txn_message
FROM GRAPH_TABLE( transactions_graph 
    MATCH (src IS account) -[t IS transfer]-> (dst IS account) 
    WHERE t.description.type.string() = 'LGEC'     
    COLUMNS (
                t.txn_id         as txn_id,
                t.amount         as txn_amount, 
                src.name         as src_name,            
                dst.name         as dst_name,
                src.job_title    as src_job_title,
                src.job_vector   as src_job_vector,
                t.message_vector as message_vector,
                t.description.message.string() as txn_message                
            )
) ORDER BY VECTOR_DISTANCE(src_job_vector, 
                           VECTOR_EMBEDDING(all_MiniLM_L12 
                                           USING 'he or she works with money' AS DATA),
                           COSINE)
FETCH FIRST 5 ROWS ONLY;





--- #####################################################################################################################################################
--- DEMO 7: SELECT AI
--- #####################################################################################################################################################

EXEC DBMS_CLOUD_AI.DROP_PROFILE('OPENAI')

BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
  profile_name   => 'OPENAI',
  attributes     =>'{"provider": "openai",
			               "credential_name": "OPENAI_CRED",
			               "object_list": [{"owner": "FMELO", "name": "BRANCHES"},
					                           {"owner": "FMELO", "name": "ACCOUNTS"},
					                           {"owner": "FMELO", "name": "TRANSACTIONS"}]
       }');
END;
/

EXEC DBMS_CLOUD_AI.set_profile('OPENAI')

SELECT AI "Cuántas cuentas hay en la base de datos";

SELECT AI "Cuál de las transacciones de LETISHA tiene mayor valor";

--SELECT AI showsql "Cuál de las transacciones de LETISHA tiene mayor valor";

--SELECT AI narrate "Cuál de las transacciones de LETISHA tiene mayor valor";


--- #####################################################################################################################################################
--- DEMO 8: FGAC (VPD)
--- #####################################################################################################################################################


-- Relational
SELECT * FROM ACCOUNTS WHERE name = 'LETISHA';





-- Graph
SELECT 'LETISHA -> ' || dst_names as path, hops, amounts
FROM GRAPH_TABLE( transactions_graph 
    MATCH (src is account) (-[t IS transfer]-> (dst is account)){1,2} (final_dst)
    WHERE src.name = 'LETISHA' 
    COLUMNS (LISTAGG(dst.name, ' -> ')  as dst_names,
             COUNT(t.txn_id)         as hops,
             JSON_ARRAYAGG(t.amount) as amounts)
) 
ORDER BY hops, amounts;





-- Vector
SELECT name, job_title
FROM accounts where name = 'LETISHA'
ORDER BY VECTOR_DISTANCE(job_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12 
                                      USING 'he or she works with money' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;