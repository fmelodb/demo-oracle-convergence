import oracledb
import os
from dotenv import load_dotenv

# connection info
load_dotenv()
oracledb.init_oracle_client(lib_dir=r"D:\instantclient_23_8") # Adjust the path as needed
username = os.getenv("DB_USER")
password = os.getenv("DB_PASS")
dsn      = os.getenv("DB_URL_PODMAN")

# insert and query
with oracledb.connect(user=username, password=password, dsn=dsn)  as connection:
    soda = connection.getSodaDatabase()
    collection = soda.createCollection("exchange_rate")
    
    # Insert a new document
    document = {"source":"USD", "target":"MXN", "rate":18.68}

    collection.insertOne(document)
    connection.commit()

    # Retrieve a simple document
    cursor = collection.find().getCursor()
    
    for doc in cursor:        
        print("Document: ", doc.getContent())