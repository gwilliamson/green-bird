import os
import json
import jwt  # Install this package in your Lambda deployment package

def handler(event, context):
    headers = event.get("headers", {})
    auth_header = headers.get("Authorization")

    # Retrieve values from environment variables
    cognito_domain = os.environ["COGNITO_DOMAIN"]
    client_id = os.environ["COGNITO_CLIENT_ID"]
    redirect_uri = os.environ["REDIRECT_URI"]
    issuer = os.environ["COGNITO_ISSUER"]

    redirect_to_login = (
        f"https://{cognito_domain}/login"
        f"?response_type=token"
        f"&client_id={client_id}"
        f"&redirect_uri={redirect_uri}"
    )

    # Check Authorization header
    if not auth_header:
        return {
            "statusCode": 302,
            "headers": {
                "Location": redirect_to_login
            },
            "body": ""
        }

    try:
        # Validate JWT (Replace 'your-public-key' with your actual key or use a library for key retrieval)
        token = auth_header.split(" ")[1]  # Bearer <token>
        decoded_token = jwt.decode(
            token,
            "your-public-key",
            algorithms=["RS256"],
            audience=client_id,
            issuer=issuer
        )

        # Token is valid; redirect to /app
        return {
            "statusCode": 302,
            "headers": {
                "Location": redirect_uri
            },
            "body": ""
        }

    except jwt.ExpiredSignatureError:
        return {
            "statusCode": 302,
            "headers": {
                "Location": redirect_to_login
            },
            "body": ""
        }
    except jwt.InvalidTokenError:
        return {
            "statusCode": 302,
            "headers": {
                "Location": redirect_to_login
            },
            "body": ""
        }
