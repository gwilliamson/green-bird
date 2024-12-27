import boto3
import os

# Initialize the S3 client
s3_client = boto3.client("s3")

def handler(event, context):
    # Specify your bucket name and file key
    bucket_name = os.getenv("BUCKET_NAME")  # Pass the bucket name via an environment variable
    file_key = "templates/login.html"

    try:
        # Fetch the file from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
        html_content = response["Body"].read().decode("utf-8")

        # Return the HTML content as the response
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "text/html"
            },
            "body": html_content
        }
    except Exception as e:
        # Return an error response if something goes wrong
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "text/plain"
            },
            "body": f"Error fetching file: {str(e)}"
        }
