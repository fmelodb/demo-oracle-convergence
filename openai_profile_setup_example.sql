-- connected as admin
GRANT execute ON DBMS_CLOUD_AI       to FMELO;
GRANT execute ON DBMS_CLOUD_PIPELINE to FMELO;

BEGIN  
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
         host => 'api.openai.com',
         ace  => xs$ace_type(privilege_list => xs$name_list('http'),
                             principal_name => 'your database username',
                             principal_type => xs_acl.ptype_db)
   );
END;
/

BEGIN
    DBMS_CLOUD.CREATE_CREDENTIAL(
        credential_name   => 'OPENAI_CRED', 
        username          =>  'your database username', 
        password          =>  'your api key'
    );
END;
/


