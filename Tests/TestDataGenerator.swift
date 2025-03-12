import Foundation
import CoreGraphics

/// A utility for generating test data for HDR+ tests.
/// This class provides methods to create various types of test data including images,
/// matrices, histograms, and other inputs needed for testing the HDR+ pipeline.
public class TestDataGenerator {
    
    /// Singleton instance
    public static let shared = TestDataGenerator()
    
    /// Error types for test data generation
    public enum TestDataError: Error, LocalizedError {
        /// File could not be saved
        case fileSaveError(String)
        /// Invalid parameters provided
        case invalidParameters(String)
        /// Image creation failed
        case imageCreationFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .fileSaveError(let details):
                return "Failed to save file: \(details)"
            case .invalidParameters(let details):
                return "Invalid parameters: \(details)"
            case .imageCreationFailed(let details):
                return "Image creation failed: \(details)"
            }
        }
    }
    
    /// Image patterns for test image generation
    public enum ImagePattern {
        /// Solid color image
        case solid(color: CGColor)
        /// Gradient from one color to another (horizontal or vertical)
        case gradient(startColor: CGColor, endColor: CGColor, horizontal: Bool)
        /// Checkerboard pattern with two colors
        case checkerboard(color1: CGColor, color2: CGColor, size: Int)
        /// Radial gradient from center color to edge color
        case radial(centerColor: CGColor, edgeColor: CGColor)
        /// Test chart with color patches and grayscale gradient
        case testChart
        /// Noise pattern with given intensity (0.0-1.0)
        case noise(intensity: Double)
        /// Resolution test pattern with concentric circles and grid
        case resolution
        /// Sinusoidal pattern with given frequency and orientation
        case sinusoidal(frequency: Double, orientation: Double)
    }
    
    /// Configuration for test image generation
    public struct ImageConfig {
        /// Width of the image in pixels
        public var width: Int
        /// Height of the image in pixels
        public var height: Int
        /// Bit depth (8, 16, or 32)
        public var bitDepth: Int = 8
        /// Whether the image has an alpha channel
        public var hasAlpha: Bool = false
        /// Color space (RGB, grayscale, etc.)
        public var colorSpace: CGColorSpace
        
        /// Standard RGB color space
        public static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        /// Extended RGB color space
        public static let extendedRGB = CGColorSpace(name: CGColorSpace.extendedSRGB)!
        /// Linear RGB color space
        public static let linearRGB = CGColorSpace(name: CGColorSpace.linearSRGB)!
        /// Gray color space
        public static let gray = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
        
        /// Create standard 8-bit RGB configuration
        public static func standardRGB(width: Int, height: Int) -> ImageConfig {
            return ImageConfig(width: width, height: height, bitDepth: 8, hasAlpha: false, colorSpace: sRGB)
        }
        
        /// Create 16-bit extended RGB configuration
        public static func hdr(width: Int, height: Int) -> ImageConfig {
            return ImageConfig(width: width, height: height, bitDepth: 16, hasAlpha: false, colorSpace: extendedRGB)
        }
        
        /// Create 32-bit floating point RGB configuration
        public static func floatingPoint(width: Int, height: Int) -> ImageConfig {
            return ImageConfig(width: width, height: height, bitDepth: 32, hasAlpha: false, colorSpace: linearRGB)
        }
        
        /// Create grayscale configuration
        public static func grayscale(width: Int, height: Int, bitDepth: Int = 8) -> ImageConfig {
            return ImageConfig(width: width, height: height, bitDepth: bitDepth, hasAlpha: false, colorSpace: gray)
        }
        
        /// Initialize with defaults
        public init(width: Int, height: Int, bitDepth: Int = 8, hasAlpha: Bool = false, colorSpace: CGColorSpace = sRGB) {
            self.width = width
            self.height = height
            self.bitDepth = bitDepth
            self.hasAlpha = hasAlpha
            self.colorSpace = colorSpace
        }
    }
    
    /// Generate a test image with the given pattern and configuration
    public func generateImage(pattern: ImagePattern, config: ImageConfig) throws -> CGImage {
        // Determine the bitmap info
        var bitmapInfo: CGBitmapInfo
        var bitsPerComponent: Int
        var bytesPerRow: Int
        
        switch config.bitDepth {
        case 8:
            bitsPerComponent = 8
            bitmapInfo = config.hasAlpha ? CGBitmapInfo.alphaInfoMask : CGBitmapInfo()
            bytesPerRow = config.width * (config.hasAlpha ? 4 : 3)
        case 16:
            bitsPerComponent = 16
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
            bytesPerRow = config.width * (config.hasAlpha ? 8 : 6)
        case 32:
            bitsPerComponent = 32
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
                .union(.floatComponents)
            bytesPerRow = config.width * (config.hasAlpha ? 16 : 12)
        default:
            throw TestDataError.invalidParameters("Unsupported bit depth: \(config.bitDepth)")
        }
        
        // Create the context
        guard let context = CGContext(
            data: nil,
            width: config.width,
            height: config.height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: config.colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw TestDataError.imageCreationFailed("Failed to create CGContext")
        }
        
        // Draw the pattern
        switch pattern {
        case .solid(let color):
            context.setFillColor(color)
            context.fill(CGRect(x: 0, y: 0, width: config.width, height: config.height))
            
        case .gradient(let startColor, let endColor, let horizontal):
            // Create a gradient
            let colors = [startColor, endColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let locations: [CGFloat] = [0.0, 1.0]
            
            guard let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors,
                locations: locations
            ) else {
                throw TestDataError.imageCreationFailed("Failed to create gradient")
            }
            
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = horizontal ?
                CGPoint(x: CGFloat(config.width), y: 0) :
                CGPoint(x: 0, y: CGFloat(config.height))
            
            context.drawLinearGradient(
                gradient,
                start: startPoint,
                end: endPoint,
                options: []
            )
            
        case .checkerboard(let color1, let color2, let size):
            for y in stride(from: 0, to: config.height, by: size) {
                for x in stride(from: 0, to: config.width, by: size) {
                    let useColor1 = ((x / size) + (y / size)) % 2 == 0
                    context.setFillColor(useColor1 ? color1 : color2)
                    let rectSize = min(size, config.width - x, config.height - y)
                    context.fill(CGRect(x: x, y: y, width: rectSize, height: rectSize))
                }
            }
            
        case .radial(let centerColor, let edgeColor):
            // Create a radial gradient
            let colors = [centerColor, edgeColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let locations: [CGFloat] = [0.0, 1.0]
            
            guard let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors,
                locations: locations
            ) else {
                throw TestDataError.imageCreationFailed("Failed to create gradient")
            }
            
            let center = CGPoint(x: CGFloat(config.width) / 2.0, y: CGFloat(config.height) / 2.0)
            let radius = max(CGFloat(config.width), CGFloat(config.height)) / 2.0
            
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )
            
        case .testChart:
            // Create a color test chart with various patches
            let patchSize = min(config.width, config.height) / 8
            let colors: [(CGFloat, CGFloat, CGFloat)] = [
                (1.0, 0.0, 0.0), // Red
                (0.0, 1.0, 0.0), // Green
                (0.0, 0.0, 1.0), // Blue
                (1.0, 1.0, 0.0), // Yellow
                (1.0, 0.0, 1.0), // Magenta
                (0.0, 1.0, 1.0), // Cyan
                (1.0, 1.0, 1.0), // White
                (0.0, 0.0, 0.0), // Black
                (0.5, 0.0, 0.0), // Dark red
                (0.0, 0.5, 0.0), // Dark green
                (0.0, 0.0, 0.5), // Dark blue
                (0.5, 0.5, 0.0), // Dark yellow
                (0.5, 0.0, 0.5), // Dark magenta
                (0.0, 0.5, 0.5), // Dark cyan
                (0.5, 0.5, 0.5), // Gray
                (0.75, 0.75, 0.75) // Light gray
            ]
            
            for (i, colorTuple) in colors.enumerated() {
                let row = i / 4
                let col = i % 4
                let x = col * patchSize
                let y = row * patchSize
                
                let colorComponents: [CGFloat] = [
                    colorTuple.0, colorTuple.1, colorTuple.2, 1.0
                ]
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
                let color = CGColor(colorSpace: colorSpace, components: colorComponents)!
                
                context.setFillColor(color)
                context.fill(CGRect(x: x, y: y, width: patchSize, height: patchSize))
            }
            
            // Add a grayscale gradient at the bottom
            let gradientRect = CGRect(
                x: 0,
                y: 4 * patchSize,
                width: config.width,
                height: config.height - 4 * patchSize
            )
            
            let colors = [
                CGColor(gray: 0.0, alpha: 1.0),
                CGColor(gray: 1.0, alpha: 1.0)
            ] as CFArray
            
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let locations: [CGFloat] = [0.0, 1.0]
            
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors,
                locations: locations
            ) {
                context.saveGState()
                context.clip(to: gradientRect)
                
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 4 * patchSize),
                    end: CGPoint(x: CGFloat(config.width), y: 4 * patchSize),
                    options: []
                )
                context.restoreGState()
            }
            
        case .noise(let intensity):
            let pixelCount = config.width * config.height
            var pixels = [UInt8](repeating: 0, count: pixelCount * 4)
            
            for i in 0..<pixelCount {
                let randomValue = UInt8(Double.random(in: 0...255) * intensity)
                let pixelIndex = i * 4
                
                // Set RGB to random values
                pixels[pixelIndex] = randomValue
                pixels[pixelIndex + 1] = randomValue
                pixels[pixelIndex + 2] = randomValue
                pixels[pixelIndex + 3] = 255 // Alpha
            }
            
            // Create a data provider from the pixel data
            guard let dataProvider = CGDataProvider(data: Data(pixels) as CFData) else {
                throw TestDataError.imageCreationFailed("Failed to create data provider")
            }
            
            // Create a bitmap context and draw into it
            context.data?.copyMemory(from: pixels, byteCount: pixels.count)
            
        case .resolution:
            // Draw a resolution test pattern
            context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
            context.fill(CGRect(x: 0, y: 0, width: config.width, height: config.height))
            
            context.setStrokeColor(CGColor(gray: 0.0, alpha: 1.0))
            context.setLineWidth(1.0)
            
            // Draw concentric circles
            let center = CGPoint(x: CGFloat(config.width) / 2.0, y: CGFloat(config.height) / 2.0)
            let maxRadius = min(CGFloat(config.width), CGFloat(config.height)) / 2.0
            
            for radius in stride(from: maxRadius / 10.0, through: maxRadius, by: maxRadius / 10.0) {
                context.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
                context.strokePath()
            }
            
            // Draw grid lines
            for x in stride(from: 0, to: config.width, by: config.width / 20) {
                context.move(to: CGPoint(x: CGFloat(x), y: 0))
                context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(config.height)))
                context.strokePath()
            }
            
            for y in stride(from: 0, to: config.height, by: config.height / 20) {
                context.move(to: CGPoint(x: 0, y: CGFloat(y)))
                context.addLine(to: CGPoint(x: CGFloat(config.width), y: CGFloat(y)))
                context.strokePath()
            }
            
        case .sinusoidal(let frequency, let orientation):
            // Draw a sinusoidal pattern
            let angleRad = orientation * .pi / 180.0
            let sinCos = (sin: sin(angleRad), cos: cos(angleRad))
            
            for y in 0..<config.height {
                for x in 0..<config.width {
                    // Project the point onto the wave direction
                    let projection = Double(x) * sinCos.cos + Double(y) * sinCos.sin
                    
                    // Calculate the sine value
                    let sineValue = (sin(projection * frequency * 2 * .pi / 100.0) + 1.0) / 2.0
                    let pixelValue = UInt8(sineValue * 255.0)
                    
                    // Set the pixel value
                    let pixelData: [UInt8] = [pixelValue, pixelValue, pixelValue, 255]
                    let pixelDataSize = MemoryLayout<UInt8>.size * 4
                    
                    if let baseAddress = context.data {
                        let pixelOffset = (y * config.width + x) * 4
                        baseAddress.advanced(by: pixelOffset).copyMemory(from: pixelData, byteCount: pixelDataSize)
                    }
                }
            }
        }
        
        // Create and return the image
        guard let image = context.makeImage() else {
            throw TestDataError.imageCreationFailed("Failed to create image from context")
        }
        
        return image
    }
    
    /// Generate a collection of test images with different exposures
    /// - Parameters:
    ///   - baseImage: Base image to use (if nil, a test chart will be generated)
    ///   - config: Image configuration
    ///   - exposures: Array of exposure values (EV) to generate
    ///   - saveToDirectory: Directory to save images (optional)
    /// - Returns: Array of images with different exposures
    public func generateExposureSeries(
        baseImage: CGImage? = nil,
        config: ImageConfig,
        exposures: [Double],
        saveToDirectory: URL? = nil
    ) throws -> [CGImage] {
        // Generate or use base image
        let baseImg: CGImage
        if let image = baseImage {
            baseImg = image
        } else {
            baseImg = try generateImage(pattern: .testChart, config: config)
        }
        
        var result = [CGImage]()
        
        // Generate images with different exposures
        for exposure in exposures {
            // Create a context for the exposure-adjusted image
            guard let context = CGContext(
                data: nil,
                width: config.width,
                height: config.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: config.colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw TestDataError.imageCreationFailed("Failed to create context")
            }
            
            // Draw the base image
            context.draw(baseImg, in: CGRect(x: 0, y: 0, width: config.width, height: config.height))
            
            // Adjust the exposure
            let exposureFactor = pow(2.0, exposure)
            
            if let imgData = context.data {
                let bytesPerRow = context.bytesPerRow
                let bytesPerPixel = 4
                
                for y in 0..<config.height {
                    for x in 0..<config.width {
                        let pixelPos = y * bytesPerRow + x * bytesPerPixel
                        
                        // Get the RGB values
                        var red = Double(imgData.load(fromByteOffset: pixelPos, as: UInt8.self))
                        var green = Double(imgData.load(fromByteOffset: pixelPos + 1, as: UInt8.self))
                        var blue = Double(imgData.load(fromByteOffset: pixelPos + 2, as: UInt8.self))
                        let alpha = imgData.load(fromByteOffset: pixelPos + 3, as: UInt8.self)
                        
                        // Adjust exposure
                        red = min(255, max(0, red * exposureFactor))
                        green = min(255, max(0, green * exposureFactor))
                        blue = min(255, max(0, blue * exposureFactor))
                        
                        // Write back the adjusted values
                        imgData.storeBytes(of: UInt8(red), toByteOffset: pixelPos, as: UInt8.self)
                        imgData.storeBytes(of: UInt8(green), toByteOffset: pixelPos + 1, as: UInt8.self)
                        imgData.storeBytes(of: UInt8(blue), toByteOffset: pixelPos + 2, as: UInt8.self)
                        imgData.storeBytes(of: alpha, toByteOffset: pixelPos + 3, as: UInt8.self)
                    }
                }
            }
            
            // Create image from context
            guard let exposedImage = context.makeImage() else {
                throw TestDataError.imageCreationFailed("Failed to create exposure-adjusted image")
            }
            
            // Save the image if a directory is provided
            if let saveDir = saveToDirectory {
                try saveImage(exposedImage, to: saveDir.appendingPathComponent("exposure_\(exposure).png"))
            }
            
            result.append(exposedImage)
        }
        
        return result
    }
    
    /// Generate a 2D matrix with various patterns
    public enum MatrixPattern {
        /// Identity matrix
        case identity
        /// Matrix filled with a constant value
        case constant(value: Double)
        /// Matrix with random values between min and max
        case random(min: Double, max: Double)
        /// Matrix with a Gaussian pattern centered at the middle
        case gaussian(sigma: Double)
        /// Matrix with a linear gradient from min to max
        case gradient(min: Double, max: Double, horizontal: Bool)
        /// Custom matrix from provided data
        case custom(data: [[Double]])
    }
    
    /// Generate a 2D matrix with the specified pattern
    /// - Parameters:
    ///   - rows: Number of rows
    ///   - columns: Number of columns
    ///   - pattern: Matrix pattern to generate
    /// - Returns: 2D array of values
    public func generateMatrix(
        rows: Int,
        columns: Int,
        pattern: MatrixPattern
    ) throws -> [[Double]] {
        var matrix = Array(repeating: Array(repeating: 0.0, count: columns), count: rows)
        
        switch pattern {
        case .identity:
            for i in 0..<min(rows, columns) {
                matrix[i][i] = 1.0
            }
            
        case .constant(let value):
            for i in 0..<rows {
                for j in 0..<columns {
                    matrix[i][j] = value
                }
            }
            
        case .random(let min, let max):
            for i in 0..<rows {
                for j in 0..<columns {
                    matrix[i][j] = Double.random(in: min...max)
                }
            }
            
        case .gaussian(let sigma):
            let centerRow = Double(rows - 1) / 2.0
            let centerCol = Double(columns - 1) / 2.0
            
            for i in 0..<rows {
                for j in 0..<columns {
                    let distSq = pow(Double(i) - centerRow, 2) + pow(Double(j) - centerCol, 2)
                    matrix[i][j] = exp(-distSq / (2.0 * sigma * sigma))
                }
            }
            
        case .gradient(let min, let max, let horizontal):
            for i in 0..<rows {
                for j in 0..<columns {
                    if horizontal {
                        matrix[i][j] = min + (max - min) * Double(j) / Double(columns - 1)
                    } else {
                        matrix[i][j] = min + (max - min) * Double(i) / Double(rows - 1)
                    }
                }
            }
            
        case .custom(let data):
            if data.count != rows || data.first?.count != columns {
                throw TestDataError.invalidParameters(
                    "Custom data dimensions (\(data.count)x\(data.first?.count ?? 0)) " +
                    "don't match requested dimensions (\(rows)x\(columns))"
                )
            }
            matrix = data
        }
        
        return matrix
    }
    
    /// Generate a histogram with various distributions
    public enum HistogramDistribution {
        /// Uniform distribution
        case uniform
        /// Normal distribution with given mean and standard deviation
        case normal(mean: Double, stdDev: Double)
        /// Bimodal distribution with two peaks
        case bimodal(mean1: Double, stdDev1: Double, mean2: Double, stdDev2: Double, weight: Double)
        /// Exponential distribution with given lambda
        case exponential(lambda: Double)
        /// Custom distribution from provided data
        case custom(values: [Double])
    }
    
    /// Generate a histogram with the specified distribution
    /// - Parameters:
    ///   - bins: Number of bins
    ///   - sampleCount: Number of samples to generate
    ///   - distribution: Distribution pattern
    ///   - range: Range of values (min, max)
    /// - Returns: Array of bin counts
    public func generateHistogram(
        bins: Int,
        sampleCount: Int,
        distribution: HistogramDistribution,
        range: (min: Double, max: Double) = (0.0, 1.0)
    ) throws -> [Int] {
        var samples = [Double]()
        
        // Generate samples based on the distribution
        switch distribution {
        case .uniform:
            for _ in 0..<sampleCount {
                samples.append(Double.random(in: range.min...range.max))
            }
            
        case .normal(let mean, let stdDev):
            // Box-Muller transform to generate normal distribution
            for _ in 0..<(sampleCount / 2 + sampleCount % 2) {
                let u1 = Double.random(in: 0.001...0.999)
                let u2 = Double.random(in: 0.001...0.999)
                
                let z1 = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
                let z2 = sqrt(-2.0 * log(u1)) * sin(2.0 * .pi * u2)
                
                samples.append(z1 * stdDev + mean)
                if samples.count < sampleCount {
                    samples.append(z2 * stdDev + mean)
                }
            }
            
        case .bimodal(let mean1, let stdDev1, let mean2, let stdDev2, let weight):
            // Box-Muller transform for two distributions
            for _ in 0..<sampleCount {
                let useFirst = Double.random(in: 0.0...1.0) < weight
                let mean = useFirst ? mean1 : mean2
                let stdDev = useFirst ? stdDev1 : stdDev2
                
                let u1 = Double.random(in: 0.001...0.999)
                let u2 = Double.random(in: 0.001...0.999)
                
                let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
                samples.append(z * stdDev + mean)
            }
            
        case .exponential(let lambda):
            for _ in 0..<sampleCount {
                let u = Double.random(in: 0.001...0.999)
                let x = -log(u) / lambda
                samples.append(x)
            }
            
        case .custom(let values):
            if values.count != sampleCount {
                throw TestDataError.invalidParameters(
                    "Custom data count (\(values.count)) doesn't match requested sample count (\(sampleCount))"
                )
            }
            samples = values
        }
        
        // Clamp samples to the range
        samples = samples.map { min(max($0, range.min), range.max) }
        
        // Count samples in each bin
        var histogram = Array(repeating: 0, count: bins)
        let binWidth = (range.max - range.min) / Double(bins)
        
        for sample in samples {
            let binIndex = min(bins - 1, max(0, Int((sample - range.min) / binWidth)))
            histogram[binIndex] += 1
        }
        
        return histogram
    }
    
    /// Save an image to a file
    public func saveImage(_ image: CGImage, to url: URL) throws {
        let fileExtension = url.pathExtension.lowercased()
        
        #if os(macOS)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        guard let data: Data = {
            switch fileExtension {
            case "jpg", "jpeg":
                return nsImage.jpegData(compressionQuality: 0.9)
            case "png":
                return nsImage.pngData()
            default:
                return nsImage.tiffRepresentation
            }
        }() else {
            throw TestDataError.fileSaveError("Failed to convert image to data")
        }
        #else
        let uiImage = UIImage(cgImage: image)
        
        guard let data: Data = {
            switch fileExtension {
            case "jpg", "jpeg":
                return uiImage.jpegData(compressionQuality: 0.9)
            case "png":
                return uiImage.pngData()
            default:
                throw TestDataError.fileSaveError("Unsupported file format: \(fileExtension)")
            }
        }() else {
            throw TestDataError.fileSaveError("Failed to convert image to data")
        }
        #endif
        
        // Ensure the directory exists
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Write the data to file
        try data.write(to: url)
    }
    
    /// Generate a test image and save it to a file
    public func generateAndSaveImage(
        pattern: ImagePattern,
        config: ImageConfig,
        to url: URL
    ) throws {
        let image = try generateImage(pattern: pattern, config: config)
        try saveImage(image, to: url)
    }
    
    /// Generate a series of test images with different parameters
    public func generateImageSeries(
        baseConfig: ImageConfig,
        pattern: ImagePattern,
        variations: [(String, ImageConfig)],
        saveToDirectory: URL
    ) throws -> [String: CGImage] {
        var result = [String: CGImage]()
        
        // Generate base image
        let baseImage = try generateImage(pattern: pattern, config: baseConfig)
        result["base"] = baseImage
        try saveImage(baseImage, to: saveToDirectory.appendingPathComponent("base.png"))
        
        // Generate variations
        for (name, config) in variations {
            let image = try generateImage(pattern: pattern, config: config)
            result[name] = image
            try saveImage(image, to: saveToDirectory.appendingPathComponent("\(name).png"))
        }
        
        return result
    }
} 