set define off
set lines 150
set pages 200
col name          format a30
col customer_name format a30
col customer_city format a30
col branch_city   format a30
col street        format a30
col region        format a8
col zip           format a10
col country       format a8
col city          format a30
col src_name      format a20
col dst_name      format a20
col total_amount  format 99999
col address       format a70
col transfer_type format a6
col job_title     format a30
col message       format a40
col data          format a80
col fruit_name    format a15
col description   format a20


@01_setup.sql

--- #####################################################################################################################################################
--- DEMO 1:
--- RELATIONAL
--- #####################################################################################################################################################

-- drop tables if exist
DROP TABLE IF EXISTS TRANSACTIONS; 
DROP TABLE IF EXISTS ACCOUNTS;
DROP TABLE IF EXISTS BRANCHES; 


-- create BRANCHES table
CREATE TABLE IF NOT EXISTS BRANCHES (
    ID              INTEGER         NOT NULL PRIMARY KEY,
    NAME            VARCHAR2(20)    NOT NULL    
); 

-- create ACCOUNTS table
CREATE TABLE IF NOT EXISTS ACCOUNTS (
    ID              NUMBER       NOT NULL PRIMARY KEY,
    NAME            VARCHAR(400) NOT NULL,
    BALANCE         NUMBER(20,2) NOT NULL,
    BRANCH_ID       INTEGER      NOT NULL REFERENCES BRANCHES
); 

-- create TRANSACTIONS table
CREATE TABLE IF NOT EXISTS TRANSACTIONS (
    TXN_ID          NUMBER          NOT NULL PRIMARY KEY,
    SRC_ACCT_ID     NUMBER          NOT NULL REFERENCES ACCOUNTS,
    DST_ACCT_ID     NUMBER          NOT NULL REFERENCES ACCOUNTS,
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

-- largest transaction amount per branch
-- top 5 branches
SELECT branch_name, customer_name, amount
FROM (
    SELECT  b.name AS branch_name,
            a.name AS customer_name,
            t.amount,
            MAX(t.amount) OVER (PARTITION BY b.id) as max_amount
    FROM ACCOUNTS a, 
         TRANSACTIONS t, 
         BRANCHES b
    WHERE a.id        = t.src_acct_id
      AND a.branch_id = b.id)
WHERE amount = max_amount
ORDER BY amount DESC
FETCH FIRST 5 ROWS ONLY;



--- #####################################################################################################################################################
--- DEMO 2:
--- RELATIONAL + SPATIAL
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

SELECT * FROM ACCOUNTS FETCH FIRST 5 ROWS ONLY; 
SELECT * FROM BRANCHES FETCH FIRST 5 ROWS ONLY; 

@02_add_location_to_accounts.sql

SELECT * FROM ACCOUNTS FETCH FIRST 5 ROWS ONLY; 
SELECT * FROM BRANCHES FETCH FIRST 5 ROWS ONLY; 


-- SDO_DISTANCE calculates euclidean distance, straight line
-- Show the distance between customers within a transaction
-- Filter by name
SELECT src.NAME      as src_name, 
       t.amount      as amount,
       dst.NAME      as dst_name,
       ROUND(
        SDO_GEOM.SDO_DISTANCE(src.customer_location, 
                              dst.customer_location, 
                              0.005, 
                              'unit=KM')) AS km_distance
FROM
    ACCOUNTS src,
    ACCOUNTS dst,      
    TRANSACTIONS t
WHERE src.id = t.src_acct_id
  and dst.id = t.dst_acct_id
  and src.id != dst.id  
  and src.name = 'TWYLA POSTEL'
ORDER BY km_distance DESC; 


-- Who are the customers living close to its branch?
-- Filter by branch
SELECT a.NAME,               
       ROUND(
        SDO_GEOM.SDO_DISTANCE(a.customer_location, 
                              b.branch_location, 
                              0.005, 
                              'unit=KM')) AS km_distance
FROM
    ACCOUNTS a,
    BRANCHES b
WHERE a.branch_id = b.id  
  and SDO_WITHIN_DISTANCE(a.customer_location, 
                          b.branch_location, 
                          'distance=100 unit=KM') = 'TRUE'
  and b.name = 'Branch 13'
ORDER BY km_distance DESC; 


--- #####################################################################################################################################################
--- DEMO 3:
--- RELATIONAL + SPATIAL + JSON
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
  and t.txn_id = 1; 


INSERT INTO TRANSFERS t (data)
values ('
        {
            "_id" : 10000, 
            "amount" : 3,  
            "message" : "thanks for the money",  
            "source_account" :  { 
                                    "account_id" : 269, 
                                    "name" : "DANIKA KERANS" },  
            "target_account" :  { 
                                    "account_id" : 52,    
                                    "name" : "KIMBERLY MCGRAIL"}
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
VALUES (20000, 269, 52, 'giving your money back', 3); 

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
drop table if exists exchange_rate; 

create json collection table exchange_rate; 

insert into exchange_rate (data)
values ('{
          "source":"USD",
          "target":"BRL",
          "rate":5.43
        }'); 

commit; 

select json_serialize(data pretty) as data from exchange_rate; 

---
-- run python soda.py
---

select json_serialize(data pretty) as data from exchange_rate; 

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

SELECT * FROM TRANSACTIONS FETCH FIRST 10 ROWS ONLY; 

ALTER TABLE TRANSACTIONS DROP COLUMN DESCRIPTION;  
ALTER TABLE TRANSACTIONS ADD DESCRIPTION JSON; 

-- add json descriptions to transfers in the following format:  { 'type', 'timestamp', 'geojson', 'comment' }
@03_add_transaction_description.sql

-- visualize
SELECT * FROM TRANSACTIONS FETCH FIRST 10 ROWS ONLY; 

SELECT json_serialize(t.DESCRIPTION pretty) as json_document
FROM TRANSACTIONS t
WHERE txn_id = 1;

-- total transfers per transfer type (dot notation)
SELECT t.description.type.string() as transfer_type, COUNT(*) AS CNT
FROM TRANSACTIONS t
GROUP BY t.description.type.string()
ORDER BY 2 DESC; 

-- total transfers per transfer type (json function)
SELECT json_value(t.description, '$.type') as transfer_type, COUNT(*) AS CNT
FROM TRANSACTIONS t
GROUP BY json_value(t.description, '$.type')
ORDER BY 2 DESC; 

-- create index and filter
DROP INDEX IF EXISTS IX_TRANSFER_TYPE; 

CREATE INDEX ix_transfer_type on TRANSACTIONS t (t.description.type.string()); 

EXPLAIN PLAN FOR
SELECT COUNT(*) AS CNT
FROM TRANSACTIONS t 
WHERE t.description.type.string() = 'SPEI'; 

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY); 

-- JSON with spatial (GeoJSON)

-- Query transfers which:
-- a) happened too far from the customer home:
-- b) Transfer type
-- c) amount > 100
SELECT src.id as SRC_ACCOUNT_ID,
       src.NAME as src_name, 
       t.amount,  
       t.description.type.string() as transfer_type,          
       ROUND(SDO_GEOM.SDO_DISTANCE(src.customer_location, 
                                   SDO_UTIL.FROM_GEOJSON(t.description.location), 
                                                         0.005, 
                                                         'unit=KM')) AS dist_km_between_home_and_transfer_loc
FROM
    ACCOUNTS src,        
    TRANSACTIONS t
WHERE src.id = t.src_acct_id
 AND t.description.type.string() = 'LGEC'
 AND t.amount > 100
 and src.NAME = 'ZULMA OLDS'
ORDER BY dist_km_between_home_and_transfer_loc DESC
FETCH FIRST 5 ROWS ONLY; 


-- Query transfers which:
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
--- DEMO 4:
--- RELATIONAL + SPATIAL + JSON + TEXT
--- #####################################################################################################################################################

-- FULL TEXT SEARCH

ALTER TABLE ACCOUNTS ADD JOB_TITLE VARCHAR2(30); 

SELECT ID, NAME, JOB_TITLE FROM ACCOUNTS FETCH FIRST 10 ROWS ONLY; 

SELECT * FROM JOBS; 

@04_add_jobs.sql

SELECT ID, NAME, JOB_TITLE FROM ACCOUNTS FETCH FIRST 10 ROWS ONLY; 

CREATE SEARCH INDEX IX_ACCOUNT_JOB ON ACCOUNTS (job_title)
  PARAMETERS ('SYNC (ON COMMIT)'); 

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

-- AND
SELECT id, name, job_title
FROM ACCOUNTS
WHERE CONTAINS(job_title, 'fuzzy(Cyvil) AND Engineer') > 0; 

-- NOT
SELECT id, name, job_title
FROM ACCOUNTS
WHERE CONTAINS(job_title, 'Engineer NOT Civil') > 0; 

--------------------------------------------------------------------------------------------------
-- FULL TEXT SEARCH WITH JSON
DROP INDEX IF EXISTS IX_TRANSFER_COMMENT; 

CREATE SEARCH INDEX IX_TRANSFER_COMMENT ON TRANSACTIONS (description)
  FOR JSON PARAMETERS ('SYNC (ON COMMIT)'); 

SELECT * FROM TRANSFER_MESSAGES; 

SELECT txn_id, src_acct_id, dst_acct_id, amount, t.description.message.string() as message
FROM TRANSACTIONS t
WHERE JSON_TEXTCONTAINS(t.description, '$.message', 'Netflix%'); 

-- Query transfers which:
-- a) happened too far from the customer home:
-- b) Transfer type
-- c) amount > 100
SELECT src.id as SRC_ACCOUNT_ID,
       src.NAME as src_name, 
       t.amount,  
       t.description.type.string()    as transfer_type,
       t.description.message.string() as message,          
       ROUND(SDO_GEOM.SDO_DISTANCE(src.customer_location, 
                                   SDO_UTIL.FROM_GEOJSON(t.description.location), 
                                                         0.005, 
                                                         'unit=KM')) AS dist_km_between_home_and_transfer_loc
FROM
    ACCOUNTS src,        
    TRANSACTIONS t
WHERE src.id = t.src_acct_id
 AND t.description.type.string() = 'LGEC'
 AND t.amount > 100
 AND JSON_TEXTCONTAINS(t.description, '$.message', 'Bill') 
ORDER BY 5 DESC
FETCH FIRST 5 ROWS ONLY; 

--- #####################################################################################################################################################
--- DEMO 5:
--- RELATIONAL + SPATIAL + JSON + TEXT + VECTOR
--- #####################################################################################################################################################

ALTER TABLE ACCOUNTS     ADD job_vector     VECTOR;
ALTER TABLE TRANSACTIONS ADD message_vector VECTOR;

-- Check Embedding Model
select model_name from user_mining_models;

-- Generating embeddings
select vector_embedding(all_MiniLM_L12_V2 using 'the book is on the table' as data) as embedding;

-- Sample Data

UPDATE accounts
SET job_vector = VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                  USING job_title AS DATA);
commit;

UPDATE transactions t
SET message_vector = VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                      USING t.description.message.string() AS DATA);

commit;

-- jobs vector search
SELECT * FROM jobs;

SELECT name, job_title
FROM accounts
ORDER BY VECTOR_DISTANCE(job_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                      USING 'job is related to planets' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;

SELECT name, job_title
FROM accounts
ORDER BY VECTOR_DISTANCE(job_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                      USING 'he or she works with animals' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;

SELECT name, job_title
FROM accounts
ORDER BY VECTOR_DISTANCE(job_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                      USING 'he or she works with money' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;

-- messages vector search
SELECT * FROM transfer_messages;

SELECT txn_id, t.description.message.string() as message
FROM transactions t
ORDER BY VECTOR_DISTANCE(message_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                      USING 'message about cinema' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;

SELECT txn_id, t.description.message.string() as message
FROM transactions t
ORDER BY VECTOR_DISTANCE(message_vector, 
                         VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                      USING 'message about sports' AS DATA),
                         COSINE)
FETCH FIRST 3 ROWS ONLY;

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
                         VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                      USING 'message about meals' AS DATA),
                         COSINE)
FETCH FIRST 1 ROWS ONLY;




--- #####################################################################################################################################################
--- DEMO 6:
--- RELATIONAL + SPATIAL + JSON + TEXT + VECTOR + GRAPH
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
SELECT txn_id, src_name, txn_amount, dst_name
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


-- finds out who person Letisha transferred money to, either directly or indirectly in N-hops
SELECT *
FROM GRAPH_TABLE( transactions_graph 
    MATCH (src) -[t]->{1,2} (dst)
    WHERE src.name = 'LETISHA CACCIA'     
    COLUMNS (dst.name                as dst_name,
             count(t.txn_id)         as path_length,
             json_arrayagg(t.amount) as amounts)
) WHERE path_length = 2
ORDER BY path_length, amounts;

-- finds out who person Letisha transferred money to, either directly or indirectly via an intermediary
SELECT 'LETISHA CACCIA -> ' || dst_names as path, hops, amounts
FROM GRAPH_TABLE( transactions_graph 
    MATCH (src is account) (-[t IS transfer]-> (dst is account)){1,3} (final_dst)
    WHERE src.name = 'LETISHA CACCIA' and final_dst.name = 'DAREN BRAVARD'   
    COLUMNS (LISTAGG(dst.name, ' -> ')  as dst_names,
             count(t.txn_id)         as hops,
             json_arrayagg(t.amount) as amounts)
) 
ORDER BY hops, amounts;

-- Check if there are any N-hop transfers that start and end at the same account
SELECT customer_account, COUNT(1) AS hop_cycle
FROM GRAPH_TABLE( transactions_graph
    MATCH (src) -[]->{3} (src)
    COLUMNS (src.id AS customer_account)
) GROUP BY customer_account 
ORDER BY hop_cycle DESC
FETCH FIRST 5 ROWS ONLY;


-- Check if there are any N-hop transfers that start and end at the same account
-- Show transaction ids
SELECT *
FROM GRAPH_TABLE( transactions_graph
    MATCH (src) -[t]->{3} (src)
    WHERE src.id = 918
    COLUMNS (LISTAGG(t.txn_id, ' -> ') as transaction_ids)
);


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
) ORDER BY  VECTOR_DISTANCE(src_job_vector, 
                            VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                            USING 'he or she works with money' AS DATA),
                            COSINE),
            VECTOR_DISTANCE(message_vector, 
                            VECTOR_EMBEDDING(all_MiniLM_L12_V2 
                                            USING 'message about meals' AS DATA),
                            COSINE)
FETCH FIRST 5 ROWS ONLY;



--- #####################################################################################################################################################
--- DEMO 7:
--- TABLE DECORATIONS
--- #####################################################################################################################################################

-- IMMUTABLE

-- INMEMORY

-- FAST INGEST



/*

NOT COMMENTED:

 DATATYPES: XMLTYPE, BLOB, OBJECT-RELATIONAL, PURE AND HYBRID COLUMNAR FORMAT
 FEATURES: FAST INGEST, MACHINE LEARNING (regression, classification, clustering, etc), GRAPH ANALYTICS (PageRank, Community Detection, DeepWalk, GraphSage, etc), EXTERNAL TABLES
 ARQUITECTURES: MESSAGE BROKER (QUEUES), APPLICATION CACHE (TRUE CACHE), MICROSERVICES PATTERNS (SAGA, OUTBOX, EVENT SOURCING)
 PROGRAMMING LANGUAGES: JAVA, JAVASCRIPT 
 AI: SQL WITH NATURAL LANGUAGE (Autonomous Database Service)

*/

CREATE PROPERTY GRAPH transactions_graph
  VERTEX TABLES (
    ACCOUNTS KEY ( ID ) LABEL account PROPERTIES (ID, NAME),
    BRANCHES KEY ( ID ) LABEL branch  PROPERTIES (ID, NAME)
  )
  EDGE TABLES (
    TRANSACTIONS
      SOURCE      KEY ( src_acct_id ) REFERENCES ACCOUNTS (ID)
      DESTINATION KEY ( dst_acct_id ) REFERENCES ACCOUNTS (ID)
      LABEL transfer PROPERTIES ARE ALL COLUMNS,
    ACCOUNTS as BranchAccounts
      SOURCE      KEY ( id )   REFERENCES ACCOUNTS (ID)
      DESTINATION BRANCHES
      LABEL belongs_to NO PROPERTIES
  ); 