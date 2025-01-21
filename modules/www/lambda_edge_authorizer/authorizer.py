import traceback
import logging
import json
from jwt import decode, get_unverified_header
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import urllib.request
from boto3 import client

# Set up logging
logging.basicConfig(format='%(message)s')
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_ssm_param(name, region="us-east-1", with_decryption=False):
    logger.info(f"Fetching SSM parameter: {name} in region {region} with decryption={with_decryption}")
    try:
        ssm = client("ssm", region_name=region)
        response = ssm.get_parameter(
            Name=name,
            WithDecryption=with_decryption
        )
        value = response["Parameter"]["Value"]
        logger.info(f"Retrieved value for {name}: {value}")
        return value
    except Exception as e:
        logger.error(f"Error fetching SSM parameter {name}: {e}")
        logger.error(traceback.format_exc())
        raise

def get_config():
    logger.info("Fetching configuration")
    try:
        aws_region = "us-east-1" # get_ssm_param("/cognito/green_bird_region")
        user_pool_id = "us-east-1_DlOBmODkE" # get_ssm_param("/cognito/green_bird_user_pool_id")
        client_id = "7tgp3ba34oof082un43cfmtk9r" # get_ssm_param("/cognito/green_bird_client_id")
        jwks_url = f"https://cognito-idp.{aws_region}.amazonaws.com/{user_pool_id}/.well-known/jwks.json"
        config = {
            "AWS_REGION": aws_region,
            "COGNITO_USER_POOL_ID": user_pool_id,
            "COGNITO_CLIENT_ID": client_id,
            "JWKS_URL": jwks_url,
        }
        logger.info(f"Configuration: {config}")
        return config
    except Exception as e:
        logger.error("Error getting configuration")
        logger.error(traceback.format_exc())
        raise

def get_cognito_keys(jwks_url):
    try:
        response = urllib.request.urlopen(jwks_url)
        keys = json.loads(response.read())["keys"]
        return {key["kid"]: key for key in keys}
    except Exception as e:
        logger.error(f"Error fetching Cognito keys from {jwks_url}: {e}")
        logger.error(traceback.format_exc())
        raise

def verify_jwt(token, cognito_keys, client_id):
    try:
        # Extract the key ID (kid) from the token's header
        header = get_unverified_header(token)
        key = cognito_keys.get(header["kid"])
        if not key:
            raise Exception("Public key not found in Cognito JWKS")

        # Load the RSA public key from the JWKS
        public_key = serialization.load_pem_public_key(
            rsa.RSAPublicNumbers(
                e=int.from_bytes(bytes.fromhex(key["e"]), byteorder="big"),
                n=int.from_bytes(bytes.fromhex(key["n"]), byteorder="big")
            ).public_key(default_backend())
        )

        # Decode and validate the JWT
        payload = decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=client_id
        )
        return payload
    except Exception as e:
        raise Exception(f"JWT verification failed: {e}")
def handler(event, context):
    logger.info("Running handler")
    try:
        request = event['Records'][0]['cf']['request']
        uri = request['uri']
        logger.info(f"Request URI: {uri}")

        config = get_config()
        cognito_keys = get_cognito_keys(config["JWKS_URL"])

        headers = request.get('headers', {})
        cookies = headers.get('cookie', [])
        logger.info(f"Cookies count: {len(cookies)}")

        # Extract the JWT from the cookies
        jwt_token = None
        for cookie in cookies:
            cookie_value = cookie['value']
            for part in cookie_value.split(';'):
                if part.strip().startswith("id_token="):
                    jwt_token = part.strip().split('=')[1]
                    break

        if not jwt_token:
            raise Exception("JWT cookie not found")

        # Verify the JWT
        verify_jwt(jwt_token, cognito_keys, config["COGNITO_CLIENT_ID"])

        logger.info("JWT verification successful")
        return request

    except Exception as e:
        logger.error("Error in handler")
        logger.error(traceback.format_exc())
        return {
            'status': '403',
            'statusDescription': 'Forbidden',
            'body': json.dumps({
                'message': 'Access denied. Invalid JWT.',
                'error': str(e),
            }),
            'headers': {
                'content-type': [{'key': 'Content-Type', 'value': 'application/json'}],
            },
        }
