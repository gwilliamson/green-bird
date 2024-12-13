import boto3
def handler(event, context):
    result = "Hello World"
    return {
        'statusCode' : 200,
        'body': result
    }