import json

def handler(event, context):
    """
    Simple Lambda function for the /protected route.
    """
    # Pretty-print the event and context
    print("Event: ", json.dumps(event, indent=4))
    print("Context: ", json.dumps({
        "function_name": context.function_name,
        "function_version": context.function_version,
        "invoked_function_arn": context.invoked_function_arn,
        "memory_limit_in_mb": context.memory_limit_in_mb,
        "aws_request_id": context.aws_request_id,
        "log_group_name": context.log_group_name,
        "log_stream_name": context.log_stream_name
    }, indent=4))

    # Extract claims from the event if available
    claims = event.get("requestContext", {}).get("authorizer", {})

    # Extract useful details (optional)
    userId = claims.get("userId", "unknown")
    username = claims.get("username", "unknown")
    email = claims.get("email", "unknown")

    # Log the request (optional)
    print(f"Protected endpoint accessed by user: {username}, email: {email}")

    # Return a success response
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Welcome to the protected endpoint!",
            "userId": userId,
            "username": username,
            "email": email
        })
    }
