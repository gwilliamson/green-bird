import json
import os
from boto3 import client
from requests import post
from urllib.parse import urlencode

def handler(event, context):
    # Extract the authorization code from the query string
    query_params = event['queryStringParameters']
    auth_code = query_params.get('code')

    if not auth_code:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing authorization code"})
        }

    AWS_REGION = os.environ['AWS_REGION']
    COGNITO_DOMAIN = os.environ['COGNITO_DOMAIN']
    COGNITO_CLIENT_ID = os.environ['COGNITO_CLIENT_ID']
    COGNITO_CLIENT_SECRET = get_client_secret()
    CALLBACK_URI = os.environ['CALLBACK_URI']
    AUTH_COOKIE_DOMAIN = os.environ['AUTH_COOKIE_DOMAIN']

    # Exchange the authorization code for tokens
    token_url = f"https://{COGNITO_DOMAIN}.auth.{AWS_REGION}.amazoncognito.com/oauth2/token"

    data = {
        "grant_type": "authorization_code",
        "client_id": COGNITO_CLIENT_ID,
        "client_secret": COGNITO_CLIENT_SECRET,
        "code": auth_code,
        "redirect_uri": CALLBACK_URI
    }

    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    response = post(token_url, data=urlencode(data), headers=headers)

    if response.status_code != 200:
        return {
            "statusCode": response.status_code,
            "body": response.text
        }

    tokens = response.json()

    # Return a response with cookies and a script to redirect
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/html"
        },
        "multiValueHeaders": {
            "Set-Cookie": [
                build_cookie("access_token", tokens['access_token'], AUTH_COOKIE_DOMAIN),
                build_cookie("id_token", tokens['id_token'], AUTH_COOKIE_DOMAIN),
                build_cookie("refresh_token", tokens['refresh_token'], AUTH_COOKIE_DOMAIN),
            ]
        },
        "body": """
        <html>
            <head>
                <title>Redirecting...</title>
                <script>
                    // Redirect to /api after cookies are set
                    window.location.href = "/api";
                </script>
            </head>
            <body>
                <p>Redirecting to your dashboard...</p>
            </body>
        </html>
        """
    }

def get_client_secret():
    """Retrieve the client secret from AWS Parameter Store."""
    ssm = client("ssm", region_name=os.environ["AWS_REGION"])
    response = ssm.get_parameter(
        Name="/cognito/client_secret",
        WithDecryption=True
    )
    return response["Parameter"]["Value"]

def build_cookie(name, value, domain, path="/", secure=True, http_only=True, same_site="Strict"):
    attributes = [
        f"{name}={value}",
        f"Path={path}",
        f"Domain={domain}",
        f"SameSite={same_site}"
    ]
    if secure:
        attributes.append("Secure")
    if http_only:
        attributes.append("HttpOnly")
    return "; ".join(attributes)
