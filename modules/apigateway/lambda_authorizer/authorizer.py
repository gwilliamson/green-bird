import jwt
import os

AWS_REGION = os.environ.get("AWS_REGION")
COGNITO_USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID")
COGNITO_CLIENT_ID = os.environ.get("COGNITO_CLIENT_ID")
JWKS_URL = f"https://cognito-idp.{AWS_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"

def handler(event, context):
    try:
        # Extract the token from the Cookie header
        cookie_header = event["headers"].get("cookie", "")
        token = cookie_header.split("id_token=")[-1].split(";")[0]

        # Use PyJWKClient to fetch and parse the JWKS
        jwk_client = jwt.PyJWKClient(JWKS_URL)
        signing_key = jwk_client.get_signing_key_from_jwt(token)

        # Decode and validate the token
        decoded_token = jwt.decode(
            token,
            signing_key.key,  # Use the key from PyJWKClient
            algorithms=["RS256"],
            audience=COGNITO_CLIENT_ID,
            options={"verify_exp": True}
        )

        return generate_policy(
            "Allow",
            event["routeArn"],
            decoded_token["sub"],
            decoded_token["cognito:username"],
            decoded_token["email"]
        )

    except jwt.ExpiredSignatureError:
        print("Token expired")
        return generate_policy("Deny", event["routeArn"], "Token expired")
    except jwt.InvalidAlgorithmError:
        print("Algorithm not supported")
        return generate_policy("Deny", event["routeArn"], "Algorithm not supported")
    except jwt.InvalidTokenError as e:
        print(f"Invalid token: {e}")
        return generate_policy("Deny", event["routeArn"], str(e))

def generate_policy(effect, resource, principal_id, username, email):
    return {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [{
                "Action": "execute-api:Invoke",
                "Effect": effect,
                "Resource": resource
            }]
        },
        "context": {
            "userId": principal_id,
            "username": username,
            "email": email
        }
    }
