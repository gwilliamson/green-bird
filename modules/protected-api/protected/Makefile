# Variables
APP_NAME := protected
PYTHON_VERSION := 3.12
DOCKER_IMAGE := public.ecr.aws/lambda/python:$(PYTHON_VERSION)
BUILD_DIR := build
DIST_DIR := dist
ZIP_FILE := $(DIST_DIR)/$(APP_NAME).zip

# Create directories if they don't exist
make_build_dir:
	mkdir -p $(BUILD_DIR)

make_dist_dir:
	mkdir -p $(DIST_DIR)

# Build the Lambda package
build: make_build_dir make_dist_dir
	# Install dependencies into the build directory
	docker run --rm \
		--entrypoint /bin/bash \
		-v $(PWD):/var/task \
		-w /var/task \
		$(DOCKER_IMAGE) \
		-c "pip install --platform manylinux2014_x86_64 --only-binary=:all: --target=$(BUILD_DIR) -r requirements.txt"

	# Copy the Lambda handler file into the build directory
	cp protected.py $(BUILD_DIR)/

# Package the Lambda function
package: build
	cd $(BUILD_DIR) && zip -r ../$(ZIP_FILE) .

# Clean up build artifacts
clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)

# Default target
all: clean build package
