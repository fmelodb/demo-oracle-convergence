
-- run if using Podman

CREATE OR REPLACE DIRECTORY DM_DUMP AS '/home/oracle';

BEGIN
   DBMS_VECTOR.LOAD_ONNX_MODEL(
        directory => 'DM_DUMP',
        file_name => 'all_MiniLM_L12_v2.onnx',
        model_name => 'ALL_MINILM_L12');
END;
/

select model_name from user_mining_models;


-- run if using ADB-S

set define off
exec dbms_cloud.create_credential( credential_name => 'oss_credential', username => 'put your username here', password => 'put your password here' );


-- load onnx model
declare
    model_source blob := NULL;
begin
    model_source := dbms_cloud.get_object(
        credential_name => 'oss_credential',
        object_uri => 'put your object storage URI for all_MiniLM_L12_v2.onnx'
    ); 

    dbms_vector.load_onnx_model('all_MiniLM_L12', model_source);
END;
/

select model_name from user_mining_models;