
-- Create policy function
CREATE OR REPLACE FUNCTION accounts_vpd_policy (
  schema_name  IN VARCHAR2,
  table_name   IN VARCHAR2
)
RETURN VARCHAR2
AS
BEGIN  
  IF SYS_CONTEXT('USERENV', 'SESSION_USER') = 'FMELO' THEN    
    RETURN 'NAME <> ''LETISHA''';
  ELSE
    -- Para outros usuários, nenhuma restrição
    RETURN '1=1';
  END IF;
END;
/

-- create policy
BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'FMELO', -- Substitua pelo schema que contém a tabela ACCOUNTS
    object_name     => 'ACCOUNTS',
    policy_name     => 'POLICY_BLOCK_FMELO',
    function_schema => 'SYSTEM', -- Schema onde está a função acima [SYSTEM = PODMAN, ADMIN = ATP]
    policy_function => 'accounts_vpd_policy',
    statement_types => 'SELECT'
  );
END;
/

-- enable/disable policy
BEGIN
  DBMS_RLS.ENABLE_POLICY(
    object_schema   => 'FMELO',       
    object_name     => 'ACCOUNTS',    
    policy_name     => 'POLICY_BLOCK_FMELO',
    enable          => FALSE          -- FALSE = disable policy, TRUE = enable policy
  );
END;
/
