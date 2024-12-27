import boto3
def handler(event, context):
    result = "We're gerging!"
    return {
        'statusCode' : 200,
        'body': result
    }