#!/bin/bash

echo "Running standalone visual tests..."

# Change to the StandaloneTests directory
cd StandaloneTests

# Make sure the output directory exists
mkdir -p TestOutput

# Run the tests with Swift Package Manager
swift test -v

echo "Standalone tests completed."
