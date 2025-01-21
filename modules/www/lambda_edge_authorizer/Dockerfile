# Use the official Python 3.12 image as a base
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container
COPY requirements.txt .

# Install the required dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application and test files into the container
COPY . .

# Set the entrypoint to make the container ready for testing
ENTRYPOINT ["python", "-m", "unittest", "discover", "-s", ".", "-p", "test_*.py"]
