import json
import jwt  # PyJWT library
import urllib.request
from boto3 import client

def get_ssm_param(name, region="us-east-1", with_decryption=False):
    """Retrieve the client secret from AWS Parameter Store."""
    ssm = client("ssm", region_name=region)
    response = ssm.get_parameter(
        Name=name,
        WithDecryption=with_decryption
    )
    return response["Parameter"]["Value"]

# Fetch Cognito's public keys
def get_cognito_keys():
    response = urllib.request.urlopen(JWKS_URL)
    keys = json.loads(response.read())["keys"]
    return {key["kid"]: key for key in keys}

# TODO Can these be cached?
AWS_REGION = get_ssm_param("/cognito/green_bird_region")
COGNITO_USER_POOL_ID = get_ssm_param("/cognito/green_bird_user_pool_id")
COGNITO_CLIENT_ID = get_ssm_param("/cognito/green_bird_client_id")
JWKS_URL = f"https://cognito-idp.{AWS_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"
COGNITO_KEYS = get_cognito_keys()


# Verify the JWT
def verify_jwt(token):
    header = jwt.get_unverified_header(token)
    key = COGNITO_KEYS.get(header["kid"])
    if not key:
        raise Exception("Public key not found in Cognito JWKS")

    public_key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(key))
    payload = jwt.decode(
        token,
        public_key,
        algorithms=["RS256"],
        audience=COGNITO_CLIENT_ID
    )
    return payload


def handler(event, context):
    request = event['Records'][0]['cf']['request']
    uri = request['uri']

    # Check if the request is for the `assets` directory
    if uri.startswith('/assets/'):
        print("URI starts with /assets/")
        headers = request.get('headers', {})
        print("headers has {} elements".format(len(headers)))
        cookies = headers.get('cookie', [])
        print("cookies has {} elements".format(len(cookies)))

        # Extract the JWT from the cookies
        jwt_token = None
        for cookie in cookies:
            cookie_value = cookie['value']
            print("cookie_value: ", cookie_value)
            for part in cookie_value.split(';'):
                if part.strip().startswith("id_token="):
                    jwt_token = part.strip().split('=')[1]
                    break

        if not jwt_token:
            return {
                'status': '403',
                'statusDescription': 'Forbidden',
                'body': json.dumps({
                    'message': 'Access denied. JWT cookie not found.',
                }),
                'headers': {
                    'content-type': [{'key': 'Content-Type', 'value': 'application/json'}],
                },
            }

        # Verify the JWT
        try:
            verify_jwt(jwt_token)
        except Exception as e:
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

    # Allow the request to proceed
    return request
