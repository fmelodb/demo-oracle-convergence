# Oracle Convergence Demo

It demonstrates how you can use different data formats with the same dataset with Oracle 23ai.

---

## 🚀 Getting Started

You can quickly get an image of Oracle Database 23ai Free (using Podman) or using Autonomous Database (ADB).

<B>If you want to run this demo from ADB</B>, connect to Oracle Cloud (OCI) and provision your database using [this quickstart guide](https://apexapps.oracle.com/pls/apex/dbpm/r/livelabs/view-workshop?wid=928). 

<B>If you want to run this demo from a Podman container</B>, use the following procedure:

- [Oracle Container Registry](https://container-registry.oracle.com)  Go to **Database > free (23ai)**

```sh
podman run --name oracle32aifree -p 1521:1521 -e ORACLE_PWD=password container-registry.oracle.com/database/free:latest
```

For the Vector demo, I am using the all_MiniLM_L12_v2.onnx embedding model for generating vectors. You can download it [here](https://adwc4pm.objectstorage.us-ashburn-1.oci.customer-oci.com/p/VBRD9P8ZFWkKvnfhrWxkpPe8K03-JIoM5h_8EJyJcpE80c108fuUjg7R5L5O7mMZ/n/adwc4pm/b/OML-Resources/o/all_MiniLM_L12_v2_augmented.zip).

---

## 📋 Steps

<B>FMELO</B> is my user schema, where all the objects are created, and the tests are done. You can replace it by your own. 

<B>SYSTEM</B> user is the admin for Podman database, and <B>ADMIN</B> is the admin for ADB-S database. 



### 1. Perform OpenAI credential setup (optional):

This step is optional - only consider this if you want to run SELECT AI demo, and you are running on ADB.

Run openai_profile_setup_example.sql for creating a credential for OpenAI. You have to provide your own API key.

SELECT AI is currently not available if you are running this demo from Podman.



### 2. Load the ONNX Model for Vector Demo:

Run the script load_onnx_model.sql using SYSTEM (Podman) or ADMIN (ADB-S) for loading the embedding model into the database, to be used for the Vector Demo. Follow the instructions for loading it into podman or ADB-S.



### 3. Create the VPD objects:

The last demo is related to FGAC, or VPD. Create the policy function and enable the security rule using SYSTEM (Podman) or ADMIN (ADB-S).

You can do this using 06_add_security.sql script.



### 4. Install the Python packages for JSON SODA demo:

soda.py requires oracledb and dotenv packages. Use pip for installing these packages:

```sh
pip install oracledb
pip install dotenv
```

Also, create a .env file and fill in the following environment variables using your own values:  DB_USER, DB_PASS, DB_URL

Update lib_dir path on soda.py according to your instant client install dir (it requires you to [download the instant client](https://www.oracle.com/database/technologies/instant-client/downloads.html)).



### 5. Run the demo:

Connect to VS Code or SQLcl, and run start_demo.sql. It is best if you just open the file and run interactively, command by command.


