import json

def handler(event, context):
    """
    Simple Lambda function for the /api route.
    """
    # Extract claims from the event if available
    claims = event.get("requestContext", {}).get("authorizer", {})

    # Extract useful details (optional)
    user_id = claims.get("userId", "unknown")
    username = claims.get("username", "unknown")
    email = claims.get("email", "unknown")

    # Log the request (optional)
    print(f"Protected endpoint accessed by user: {username}, email: {email}")

    # Return a success response
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Welcome to the API!",
            "userId": user_id,
            "username": username,
            "email": email
        })
    }
