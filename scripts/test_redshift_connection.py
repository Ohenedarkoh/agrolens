
import os

import psycopg2
from dotenv import load_dotenv


# Load environment variables from the project's .env file.
# This keeps database credentials out of the Python source code.
load_dotenv()


# Read the Redshift connection settings from environment variables.
# Non-sensitive settings have defaults; the password must be provided.
redshift_host = os.getenv("REDSHIFT_HOST")
redshift_port = os.getenv("REDSHIFT_PORT", "5439")
redshift_database = os.getenv("REDSHIFT_DATABASE", "agrolens")
redshift_user = os.getenv("REDSHIFT_USER", "agrolens_admin")
redshift_password = os.getenv("REDSHIFT_PASSWORD")


# Check that the required connection details are available.
# Fail early with a clear message instead of a confusing connection error.
if not redshift_host or not redshift_password:
    raise ValueError(
        "Missing REDSHIFT_HOST or REDSHIFT_PASSWORD in the .env file."
    )


# Establish a connection to the Redshift Serverless workgroup.
# SSL encrypts data travelling between this computer and AWS.
# The timeout prevents the script from waiting indefinitely.
connection = psycopg2.connect(
    host=redshift_host,
    port=redshift_port,
    dbname=redshift_database,
    user=redshift_user,
    password=redshift_password,
    sslmode="require",
    connect_timeout=10,
)

try:
    # A cursor allows us to execute SQL statements and retrieve results.
    with connection.cursor() as cursor:

        # Run a simple query to verify the database connection.
        # These functions identify the database, user and server time.
        cursor.execute("""
            SELECT
                current_database(),
                current_user,
                GETDATE();
        """)

        # fetchone() retrieves the single row returned by our query.
        result = cursor.fetchone()

        # Display the connection details to confirm everything works.
        print(f"Database: {result[0]}")
        print(f"User: {result[1]}")
        print(f"Server time: {result[2]}")

finally:
    # Always close the connection, even if the query encounters an error.
    connection.close()
    print("Connection closed.")
