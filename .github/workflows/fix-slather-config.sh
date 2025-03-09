#!/bin/bash

# Create Slather configuration file
cat > .slather.yml << EOF
coverage_service: html
xcodeproj: burstphoto.xcodeproj
scheme: gui
output_directory: coverage
ignore:
  - Tests/**/*
  - Pods/**/*
EOF

echo "Slather configuration created successfully" 