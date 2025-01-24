import json

def handler(event, context):
    """
    Lambda function for the /user route.
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
            "userId": user_id,
            "username": username,
            "email": email
        })
    }
