
set define off
set lines 150
set pages 200
set long 1000000

col path          format a50
col name          format a30
col customer_name format a30
col customer_city format a30
col branch_city   format a30
col street        format a35
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


DROP PROPERTY GRAPH IF EXISTS phone_graph;
DROP PROPERTY GRAPH IF EXISTS transactions_graph;  
DROP TABLE IF EXISTS PHONE_CONTACTS;
DROP TABLE IF EXISTS TRANSACTIONS; 
DROP TABLE IF EXISTS ACCOUNTS;
DROP TABLE IF EXISTS BRANCHES; 


--- ##########################################################################################################################
--- TABLE: SAMPLE_ADDRESSES
--- ##########################################################################################################################

-- Reference table for storing Mexico City main COLONIAS (neighborhood)
DROP TABLE IF EXISTS SAMPLE_ADDRESSES; 

CREATE TABLE SAMPLE_ADDRESSES (
    street          VARCHAR2(255),
    city            VARCHAR2(64),
    region          VARCHAR2(64),
    zip             VARCHAR2(64),
    country         VARCHAR2(64),
    longitude       NUMBER,
    latitude        NUMBER
); 

Load SAMPLE_ADDRESSES data\SAMPLE_ADDRESSES.csv 

COMMIT;

ALTER TABLE SAMPLE_ADDRESSES ADD location SDO_GEOMETRY;

UPDATE SAMPLE_ADDRESSES
SET location = SDO_GEOMETRY(2001, -- Tipo de geometria: 2D Point
                            4326, -- SRID (WGS84)
                            SDO_POINT_TYPE(longitude, latitude, NULL),
                            NULL,NULL);

COMMIT;


--- ##########################################################################################################################
--- TABLE: ZONES
--- ##########################################################################################################################

DROP TABLE IF EXISTS ZONES;

CREATE TABLE IF NOT EXISTS ZONES (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(50),
  area SDO_GEOMETRY
);

-- CENTRO
INSERT INTO ZONES VALUES (
  1, 'CENTER',
  SDO_GEOMETRY(
    2003, 4326, NULL,
    SDO_ELEM_INFO_ARRAY(1,1003,1),
    SDO_ORDINATE_ARRAY(
      -46.68, -23.56,  -- X,Y
      -46.60, -23.56,
      -46.60, -23.50,
      -46.68, -23.50,
      -46.68, -23.56   -- Fecha o polígono
    )
  )
);

-- ZONA North
INSERT INTO ZONES VALUES (
  2, 'NORTH',
  SDO_GEOMETRY(
    2003, 4326, NULL,
    SDO_ELEM_INFO_ARRAY(1,1003,1),
    SDO_ORDINATE_ARRAY(
      -46.75, -23.50,
      -46.60, -23.50,
      -46.60, -23.40,
      -46.75, -23.40,
      -46.75, -23.50
    )
  )
);

-- ZONA South
INSERT INTO ZONES VALUES (
  3, 'SOUTH',
  SDO_GEOMETRY(
    2003, 4326, NULL,
    SDO_ELEM_INFO_ARRAY(1,1003,1),
    SDO_ORDINATE_ARRAY(
      -46.75, -23.62,
      -46.60, -23.62,
      -46.60, -23.56,
      -46.75, -23.56,
      -46.75, -23.62
    )
  )
);

-- ZONA East
INSERT INTO ZONES VALUES (
  4, 'EAST',
  SDO_GEOMETRY(
    2003, 4326, NULL,
    SDO_ELEM_INFO_ARRAY(1,1003,1),
    SDO_ORDINATE_ARRAY(
      -46.60, -23.56,
      -46.45, -23.56,
      -46.45, -23.50,
      -46.60, -23.50,
      -46.60, -23.56
    )
  )
);

-- ZONA West
INSERT INTO ZONES VALUES (
  5, 'WEST',
  SDO_GEOMETRY(
    2003, 4326, NULL,
    SDO_ELEM_INFO_ARRAY(1,1003,1),
    SDO_ORDINATE_ARRAY(
      -46.80, -23.56,
      -46.68, -23.56,
      -46.68, -23.50,
      -46.80, -23.50,
      -46.80, -23.56
    )
  )
);

COMMIT;

--- ##########################################################################################################################
--- TABLE: TRANSFER_MESSAGES
--- ##########################################################################################################################

DROP TABLE IF EXISTS TRANSFER_MESSAGES;

CREATE TABLE TRANSFER_MESSAGES (
    id INT PRIMARY KEY,
    message varchar2(30)
);

INSERT INTO TRANSFER_MESSAGES (id, message) VALUES
(1, 'Payment for rent June'),
(2, 'Lunch reimbursement'),
(3, 'Loan repayment - thanks!'),
(4, 'Gift for your birthday!'),
(5, 'Freelance project fee'),
(6, 'Congrats on the baby!'),
(7, 'Dinner split'),
(8, 'Thanks for the help'),
(9, 'Car maintenance refund'),
(10, 'Utilities payment May'),
(11, 'Monthly allowance'),
(12, 'Thanks again for the ride'),
(13, 'Coffee fund'),
(14, 'Holiday trip costs'),
(15, 'Shared groceries'),
(16, 'Fixing my laptop'),
(17, 'Tuition support'),
(18, 'Weekend getaway split'),
(19, 'Vet bill share'),
(20, 'Dog sitting payment'),
(21, 'Movie tickets reimbursement'),
(22, 'Babysitting payment'),
(23, 'Final settlement'),
(24, 'Used furniture payment'),
(25, 'Happy holidays!'),
(26, 'Anniversary gift'),
(27, 'Great working with you'),
(28, 'Pizza night money'),
(29, 'For the concert tickets'),
(30, 'Housewarming gift'),
(31, 'Thank you - much appreciated'),
(32, 'Office lunch split'),
(33, 'Joint birthday party'),
(34, 'Hotel booking share'),
(35, 'New year’s gift'),
(36, 'Flight ticket share'),
(37, 'Internet bill share'),
(38, 'For the groceries yesterday'),
(39, 'March electricity bill'),
(40, 'Gym membership share'),
(41, 'TV subscription share'),
(42, 'Streaming service refund'),
(43, 'Health insurance split'),
(44, 'Support for tuition fees'),
(45, 'Thanks for your support'),
(46, 'For your amazing help'),
(47, 'Dinner at the steakhouse'),
(48, 'Deposit for our trip'),
(49, 'Lunch at the beach'),
(50, 'For your coffee addiction'),
(51, 'House rent - April'),
(52, 'Birthday dinner payment'),
(53, 'Loan for new phone'),
(54, 'Electric bill March'),
(55, 'Uber last Friday'),
(56, 'Thanks for hosting us'),
(57, 'Sharing the new couch'),
(58, 'Flat repair cost'),
(59, 'Garden maintenance fee'),
(60, 'Cleaning service split'),
(61, 'Hair salon refund'),
(62, 'Coaching session payment'),
(63, 'Festival ticket refund'),
(64, 'Music lesson fee'),
(65, 'Childcare share'),
(66, 'Weekend barbecue expenses'),
(67, 'Surprise gift!'),
(68, 'Gas bill share'),
(69, 'Doctor visit reimbursement'),
(70, 'Parking fee refund'),
(71, 'Apology coffee :)'),
(72, 'Fixing your car'),
(73, 'Internet cable installation'),
(74, 'Thanks for everything'),
(75, 'Reimbursement for Uber'),
(76, 'Bus pass share'),
(77, 'Study materials help'),
(78, 'Group dinner money'),
(79, 'Shared cab ride'),
(80, 'Exam fee payment'),
(81, 'Grocery run last week'),
(82, 'Moving truck rental'),
(83, 'Laundry service fee'),
(84, 'Vacation expenses split'),
(85, 'Laundry detergent group buy'),
(86, 'Pet food order'),
(87, 'Online order refund'),
(88, 'Netflix monthly fee'),
(89, 'Workshop materials fee'),
(90, 'Thank you so much!'),
(91, 'Here you go'),
(92, 'Awesome service fee'),
(93, 'Your part of dinner'),
(94, 'Football tickets!'),
(95, 'Paying you back'),
(96, 'January rent payment'),
(97, 'Here is the money!'),
(98, 'March water bill'),
(99, 'Good luck gift!'),
(100, 'Cheers, mate!'); 

commit;


--- ##########################################################################################################################
--- TABLE: PAYMENT_TYPES
--- ##########################################################################################################################

DROP TABLE IF EXISTS TRANSFER_TYPES; 

CREATE TABLE TRANSFER_TYPES (
    id INT PRIMARY KEY,
    name varchar2(30)
); 

INSERT INTO TRANSFER_TYPES (id, name) VALUES
(1, 'SPEI'),
(2, 'LGEC'),
(3, 'CoDi');

commit;

--- ##########################################################################################################################
--- TABLE: JOBS
--- ##########################################################################################################################


-- Create the jobs table

DROP TABLE IF EXISTS JOBS; 

CREATE TABLE JOBS (
    id INT PRIMARY KEY,
    name VARCHAR(100)
);

-- Insert 50 job titles in English
INSERT INTO jobs (id, name) 
VALUES  (1, 'Civil Engineer'), 
        (2, 'Doctor'), 
        (3, 'Teacher'), 
        (4, 'Lawyer'), 
        (5, 'Architect'), 
        (6, 'Accountant'), 
        (7, 'Software Developer'), 
        (8, 'Nurse'), 
        (9, 'Psychologist'), 
        (10, 'Graphic Designer'), 
        (11, 'Pharmacist'), 
        (12, 'Nutritionist'), 
        (13, 'Veterinarian'), 
        (14, 'Electrician'), 
        (15, 'Mechanic'), 
        (16, 'Carpenter'), 
        (17, 'Driver'), 
        (18, 'Cook'), 
        (19, 'Waiter'), 
        (20, 'Police Officer'), 
        (21, 'Firefighter'), 
        (22, 'Journalist'), 
        (23, 'Photographer'), 
        (24, 'Librarian'), 
        (25, 'Data Scientist'), 
        (26, 'Systems Analyst'), 
        (27, 'Production Engineer'), 
        (28, 'Pilot'), 
        (29, 'Flight Attendant'), 
        (30, 'Actor'), 
        (31, 'Singer'), 
        (32, 'Visual Artist'), 
        (33, 'Advertiser'), 
        (34, 'Real Estate Agent'), 
        (35, 'Welder'), 
        (36, 'Barber'), 
        (37, 'Beautician'), 
        (38, 'Painter'), 
        (39, 'Bricklayer'), 
        (40, 'Administrative Assistant'), 
        (41, 'Receptionist'), 
        (42, 'Financial Analyst'), 
        (43, 'Project Manager'), 
        (44, 'Translator'), 
        (45, 'Video Editor'), 
        (46, 'IT Technician'), 
        (47, 'Environmental Engineer'), 
        (48, 'Geologist'), 
        (49, 'Astronomer'), 
        (50, 'Economist'); 

commit;


--- ##########################################################################################################################
--- SPATIAL INDEXES
--- ##########################################################################################################################

DELETE USER_SDO_GEOM_METADATA
WHERE TABLE_NAME IN ('SAMPLE_ADDRESSES', 'ACCOUNTS', 'BRANCHES', 'ZONES');

INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID)
VALUES (
  'SAMPLE_ADDRESSES',
  'LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LONGITUDE', -180, 180, 0.05),
    SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.05)
  ),
  4326 -- SRID
);

INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID)
VALUES (
  'ACCOUNTS',
  'CUSTOMER_LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LONGITUDE', -180, 180, 0.05),
    SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.05)
  ),
  4326 -- SRID
);

INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID)
VALUES (
  'BRANCHES',
  'BRANCH_LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LONGITUDE', -180, 180, 0.05),
    SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.05)
  ),
  4326 -- SRID
);

INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID)
VALUES (
  'ZONES',
  'AREA',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LONGITUDE', -180, 180, 0.05),
    SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.05)
  ),
  4326
);

COMMIT;

CREATE INDEX ix_sample_addresses_location
ON SAMPLE_ADDRESSES (location)
INDEXTYPE IS MDSYS.SPATIAL_INDEX;

CREATE INDEX ix_ZONES_area
ON ZONES (area)
INDEXTYPE IS MDSYS.SPATIAL_INDEX;