import boto3
def handler(event, context):
    result = "LOGIN PAGE HERE"
    return {
        'statusCode' : 200,
        'body': result
    }