#!/bin/bash

# This script clones necessary repositories, sets up the build environment,
# and attempts to cross-compile a Windows executable of the ArttulOS browser
# on an Ubuntu Linux machine.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting Arttulcat Windows cross-compilation build script..."

# Define the target architecture for Windows
# This should match what you configure in your .mozconfig for cross-compilation.
TARGET_ARCH="x86_64-pc-mingw32" # Example for 64-bit Windows

# Define the build object directory based on the target
BUILD_OBJ_DIR="obj-${TARGET_ARCH}"
# Define the expected output directory for the final artifacts
OUTPUT_DIR="release_artifacts" # This directory will hold the final .exe or installer

# Clean up previous build directories if they exist
echo "Cleaning up previous build directories..."
rm -rf arttulcat_browser
rm -rf arttulcat_configs
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}" # Create the output directory

# 1. Clone the main browser repository
echo "Cloning arttulcat_browser repository..."
git clone https://github.com/Sprunglesonthehub/arttulcat_browser.git

# Navigate into the browser directory to handle branding and configs
echo "Changing directory to arttulcat_browser..."
cd arttulcat_browser

# 2. Handle branding
echo "Cloning arttulcat_branding repository..."
git clone https://github.com/Sprunglesonthehub/arttulcat_branding.git browser/branding/arttulcat_branding
cd browser/branding/arttulcat_branding
mv arttulcat/ ../
cd ../../../ # Go back to the root of the cloned arttulcat_browser repo
rm -rf browser/branding/arttulcat_branding # Clean up the branding repo clone

# 3. Handle configurations (.mozconfig)
echo "Cloning arttulcat_configs repository and moving .mozconfig..."
git clone https://github.com/Sprunglesonthehub/arttulcat_configs.git arttulcat_configs
mv arttulcat_configs/mozconfig/.mozconfig .
rm -rf arttulcat_configs # Clean up the configs repo clone

# IMPORTANT CROSS-COMPILATION SETUP:
# Your .mozconfig file MUST be correctly configured for Windows cross-compilation.
# It should include lines similar to:
# ac_add_options --target=${TARGET_ARCH}
# ac_add_options --host=x86_64-unknown-linux-gnu # Or your specific Linux host
# ac_add_options --with-toolchain-prefix=/usr/bin/${TARGET_ARCH}- # Adjust if your toolchain prefix is different
# ac_add_options --enable-application=browser
# ac_add_options --disable-jemalloc # Often needed for MinGW builds

# Ensure the .mozconfig is correctly set up for cross-compilation.
# If you need to dynamically modify it, you could add sed commands here.
echo "Verifying .mozconfig for Windows cross-compilation..."
if ! grep -q "ac_add_options --target=${TARGET_ARCH}" .mozconfig; then
  echo "WARNING: .mozconfig does not appear to be configured for target ${TARGET_ARCH}."
  echo "Please ensure your .mozconfig includes 'ac_add_options --target=${TARGET_ARCH}' and other cross-compilation flags."
  # You might want to exit here or add a default configuration.
fi

# 4. Bootstrap the build environment
echo "Running ./mach bootstrap..."
./mach bootstrap

# 5. Clean the build directory (optional, but good practice before a fresh package build)
echo "Running ./mach clobber..."
./mach clobber

# 6. Build and package the browser for Windows
# For cross-compilation, `mach build` will compile the code, and `mach package`
# will attempt to create the installer/archive.
# The output will be in the object directory created by the build system.
echo "Running ./mach build and ./mach package for Windows..."
./mach build # This will perform the cross-compilation
./mach package # This will attempt to create the Windows package (e.g., .exe installer)

# 7. Move the generated artifacts to the expected output directory for GitHub Actions
echo "Moving generated Windows artifacts to ${OUTPUT_DIR}..."
# The exact path to the generated .exe or installer might vary.
# Common locations are within the 'dist' subdirectory of the build object directory.
# You might need to adjust the source path below based on your actual build output.
# Example: find ./${BUILD_OBJ_DIR}/dist/ -name "*.exe" -exec mv {} "${OUTPUT_DIR}/" \;
# Example: find ./${BUILD_OBJ_DIR}/dist/ -name "*.msi" -exec mv {} "${OUTPUT_DIR}/" \;

# A more robust way might be to copy the entire 'dist' folder if it contains all necessary files.
if [ -d "./${BUILD_OBJ_DIR}/dist" ]; then
  cp -r "./${BUILD_OBJ_DIR}/dist/"* "${OUTPUT_DIR}/"
  echo "Copied contents of ./${BUILD_OBJ_DIR}/dist/ to ${OUTPUT_DIR}/"
else
  echo "WARNING: Could not find ./${BUILD_OBJ_DIR}/dist/. Please verify the build output path."
  # Attempt to find common Windows build artifacts directly
  find . -name "*.exe" -exec cp {} "${OUTPUT_DIR}/" \; 2>/dev/null || true
  find . -name "*.msi" -exec cp {} "${OUTPUT_DIR}/" \; 2>/dev/null || true
  if [ -z "$(ls -A ${OUTPUT_DIR})" ]; then
    echo "ERROR: No Windows artifacts found in the expected locations. Build might have failed or output path is incorrect."
    exit 1
  fi
fi

echo "Windows cross-compilation build script finished."
