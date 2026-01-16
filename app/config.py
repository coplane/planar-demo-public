import asyncio
import concurrent.futures
import json
import os
from pathlib import Path

import boto3
from dotenv import load_dotenv


# Load environment variables from .env file if it exists
env_path = Path(__file__).parent.parent / ".env.dev"
if env_path.exists():
    print(f"Loading environment from {env_path}")
    load_dotenv(dotenv_path=env_path)
else:
    print("No .env file found, using system environment variables")


# ported from https://github.com/coplane/example-planar-invoice-processing/blob/main/app/config.py
def _get_secret_sync(secret_name, region_name="us-west-2"):
    # Create a synchronous session and client
    client = boto3.client("secretsmanager", region_name=region_name)

    # Get the secret value synchronously
    get_secret_value_response = client.get_secret_value(SecretId=secret_name)

    credentials = json.loads(get_secret_value_response["SecretString"])
    return credentials


async def get_secret_async(secret_name, region_name="us-west-2"):
    # Use asyncio.to_thread to run the synchronous boto3 call in a thread
    return await asyncio.to_thread(_get_secret_sync, secret_name, region_name)


async def setup_aws_postgresql_config() -> None:
    secret_name = os.environ.get("DB_SECRET_NAME")
    if not secret_name:
        raise ValueError("DB_SECRET_NAME environment variable is required")
    credentials = await get_secret_async(
        secret_name, os.environ.get("REGION", "us-west-2")
    )
    if not os.getenv("DB_HOST"):
        os.environ["DB_HOST"] = credentials.get("host", "localhost")
    if not os.getenv("DB_PORT"):
        os.environ["DB_PORT"] = str(credentials.get("port", "5432"))
    if not os.getenv("DB_USER"):
        os.environ["DB_USER"] = credentials.get("username", "dbadmin")
    if not os.getenv("DB_PASSWORD"):
        os.environ["DB_PASSWORD"] = credentials["password"]
    if not os.getenv("DB_NAME"):
        os.environ["DB_NAME"] = credentials.get("dbname", "appdb")


async def async_setup_prod_env_vars() -> None:
    await setup_aws_postgresql_config()


def setup_prod_env_vars():
    with concurrent.futures.ThreadPoolExecutor() as executor:
        future = executor.submit(lambda: asyncio.run(async_setup_prod_env_vars()))
        return future.result()