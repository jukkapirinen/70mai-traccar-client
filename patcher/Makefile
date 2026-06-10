.PHONY: all build patch clean

# Default action if you just type 'make'
all: build patch

# Step 1: Build the Docker image
build:
	@echo "🔨 Building the dashcam-patcher Docker image..."
	docker build -t dashcam-patcher .

# Step 2: Run the container with the correct parent directory mounts
patch:
	@echo "🚀 Running the firmware patcher..."
	docker run --rm \
		-v "$(CURDIR):/workspace" \
		-v "$(CURDIR)/../usr:/workspace/usr" \
		dashcam-patcher

# Optional: Clean up the generated files to start fresh
clean:
	@echo "🧹 Cleaning up generated firmware files..."
	rm -f FW96580A.bin FW96580A.orig.bin
	rm -rf work
