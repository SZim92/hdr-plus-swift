# Test Resources

This directory contains resources used for testing the HDR+ Swift project.

## Directory Structure

- `ReferenceImages/` - Reference images for visual testing
- `TestInputs/` - Input files for test cases
- `Mocks/` - Mock objects and data for unit tests

## Resource Types

### Reference Images

Reference images are used in visual testing to compare the output of processing operations with expected results. 

Files are named according to the convention: `<TestName>_<scenario>.png`

### Test Inputs

This directory contains input files for tests, including:

- `sample_raw.dng` - Sample RAW image input
- `burst_sequence/` - Set of images for burst processing tests
- `noisy_inputs/` - Images with various noise profiles for testing denoising
- `high_contrast/` - High dynamic range scenes for testing HDR processing

### Mocks

Mock objects and data used in unit testing:

- `mock_sensor_info.json` - Sensor specifications for testing
- `mock_pipeline_config.json` - Configuration for pipeline components
- `mock_metadata.json` - Metadata for test images

## Adding Resources

When adding new resources:

1. Place them in the appropriate directory based on type
2. Use descriptive filenames with the test purpose
3. Keep resources as small as possible while still being useful for testing
4. Document any special usage in the test files where they're used
5. If resources are large, consider adding them to `.gitignore` and providing instructions for downloading/generating them

## Generating Test Resources

Some test resources can be generated programmatically:

- `generate_test_patterns.swift` - Creates synthetic test images
- `downsample_test_images.sh` - Creates smaller versions of reference images for faster testing

Run these scripts from the project root directory:

```
swift Tests/TestResources/Scripts/generate_test_patterns.swift
``` 