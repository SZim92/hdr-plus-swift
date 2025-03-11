#!/usr/bin/env swift
import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Constants

/// Output directory for test patterns
let outputBaseDir = "Tests/TestResources/TestInputs/Patterns"

/// Available pattern types
enum PatternType: String, CaseIterable {
    case gradient = "gradient"
    case checkerboard = "checkerboard"
    case noise = "noise"
    case colorBars = "color_bars"
    case siemensStars = "siemens_stars"
    case resolution = "resolution"
    case zoneSystem = "zone_system"
    case macbeth = "macbeth"
    case highlight = "highlight_recovery"
    case chromatic = "chromatic_test"
}

/// Available sizes
let sizes = [
    (width: 256, height: 256),
    (width: 512, height: 512),
    (width: 1024, height: 1024),
    (width: 2048, height: 1536)
]

/// Available noise levels
let noiseLevels = ["low", "medium", "high"]

// MARK: - Main Functions

/// Main entry point
func main() {
    print("Generating test patterns...")
    
    // Create output directory
    createDirectory(at: outputBaseDir)
    
    // Generate patterns for each size
    for size in sizes {
        let sizeDir = "\(outputBaseDir)/\(size.width)x\(size.height)"
        createDirectory(at: sizeDir)
        
        // Generate all pattern types
        for pattern in PatternType.allCases {
            generatePattern(type: pattern, width: size.width, height: size.height, outputDir: sizeDir)
        }
        
        // Generate noise variants at different levels
        for level in noiseLevels {
            let noiseDir = "\(sizeDir)/noise_\(level)"
            createDirectory(at: noiseDir)
            
            // Add noise to each pattern type
            for pattern in PatternType.allCases where pattern != .noise {
                generatePattern(
                    type: pattern,
                    width: size.width,
                    height: size.height,
                    outputDir: noiseDir,
                    noiseLevel: level
                )
            }
        }
    }
    
    // Generate special test cases
    generateHDRTestSeries()
    generateBurstSequence()
    
    print("Done generating test patterns.")
}

/// Generate a test pattern
func generatePattern(type: PatternType, width: Int, height: Int, outputDir: String, noiseLevel: String? = nil) {
    // Generate pattern data
    let filename: String
    if let level = noiseLevel {
        filename = "\(type.rawValue)_\(level).png"
    } else {
        filename = "\(type.rawValue).png"
    }
    
    let outputPath = "\(outputDir)/\(filename)"
    
    print("Generating: \(outputPath)")
    
    // Generate appropriate pattern
    switch type {
    case .gradient:
        generateGradient(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    case .checkerboard:
        generateCheckerboard(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    case .noise:
        generateNoise(width: width, height: height, outputPath: outputPath, level: noiseLevel ?? "medium")
    case .colorBars:
        generateColorBars(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    case .siemensStars:
        generateSiemensStars(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    case .resolution:
        generateResolutionPattern(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    case .zoneSystem:
        generateZoneSystem(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    case .macbeth:
        generateMacbethChart(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    case .highlight:
        generateHighlightTest(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    case .chromatic:
        generateChromaticTest(width: width, height: height, outputPath: outputPath, noiseLevel: noiseLevel)
    }
}

/// Create directory if it doesn't exist
func createDirectory(at path: String) {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path) {
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch {
            print("Error creating directory: \(error)")
        }
    }
}

// MARK: - Pattern Generation Functions

/// Generate a gradient pattern
func generateGradient(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Create gradient
    let gradient = NSGradient(colors: [.black, .white])!
    gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 0)
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Generate a checkerboard pattern
func generateCheckerboard(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    let context = NSGraphicsContext.current!.cgContext
    let squareSize = min(width, height) / 8
    
    for y in 0..<(height / squareSize + 1) {
        for x in 0..<(width / squareSize + 1) {
            let isWhite = (x + y) % 2 == 0
            context.setFillColor(isWhite ? NSColor.white.cgColor : NSColor.black.cgColor)
            
            let rect = CGRect(
                x: x * squareSize,
                y: y * squareSize,
                width: squareSize,
                height: squareSize
            )
            context.fill(rect)
        }
    }
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Generate a noise pattern
func generateNoise(width: Int, height: Int, outputPath: String, level: String) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Fill with mid-gray
    NSColor.gray.set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    
    // Add appropriate noise level
    addNoise(level: level)
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Generate color bars pattern
func generateColorBars(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    let colors: [NSColor] = [
        .white,
        .yellow,
        .cyan,
        .green,
        .magenta,
        .red,
        .blue,
        .black
    ]
    
    let barWidth = width / colors.count
    
    for (index, color) in colors.enumerated() {
        color.set()
        let rect = NSRect(
            x: index * barWidth,
            y: 0,
            width: barWidth,
            height: height
        )
        rect.fill()
    }
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Generate Siemens stars pattern
func generateSiemensStars(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Fill background with white
    NSColor.white.set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    
    let context = NSGraphicsContext.current!.cgContext
    context.setLineWidth(1.0)
    context.setStrokeColor(NSColor.black.cgColor)
    
    // Draw center star
    drawSiemensStar(
        center: CGPoint(x: width / 2, y: height / 2),
        radius: min(width, height) / 3,
        spokeCount: 72
    )
    
    // Draw smaller stars in corners
    let cornerRadius = min(width, height) / 6
    let margin = cornerRadius * 1.2
    
    // Top-left
    drawSiemensStar(
        center: CGPoint(x: margin, y: height - margin),
        radius: cornerRadius,
        spokeCount: 36
    )
    
    // Top-right
    drawSiemensStar(
        center: CGPoint(x: width - margin, y: height - margin),
        radius: cornerRadius,
        spokeCount: 48
    )
    
    // Bottom-left
    drawSiemensStar(
        center: CGPoint(x: margin, y: margin),
        radius: cornerRadius,
        spokeCount: 24
    )
    
    // Bottom-right
    drawSiemensStar(
        center: CGPoint(x: width - margin, y: margin),
        radius: cornerRadius,
        spokeCount: 60
    )
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Draw a single Siemens star
func drawSiemensStar(center: CGPoint, radius: CGFloat, spokeCount: Int) {
    #if canImport(AppKit)
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    
    // Draw alternating black/white wedges
    for i in 0..<spokeCount {
        let startAngle = CGFloat(i) * (2 * .pi / CGFloat(spokeCount))
        let endAngle = CGFloat(i + 1) * (2 * .pi / CGFloat(spokeCount))
        
        context.move(to: center)
        context.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        context.closePath()
        
        if i % 2 == 0 {
            context.setFillColor(NSColor.black.cgColor)
        } else {
            context.setFillColor(NSColor.white.cgColor)
        }
        context.fillPath()
    }
    
    // Draw circles
    context.setStrokeColor(NSColor.gray.cgColor)
    context.setLineWidth(1.0)
    
    for r in stride(from: radius / 4, through: radius, by: radius / 4) {
        context.strokeEllipse(in: CGRect(
            x: center.x - r,
            y: center.y - r,
            width: r * 2,
            height: r * 2
        ))
    }
    
    context.restoreGState()
    #endif
}

/// Generate resolution test pattern
func generateResolutionPattern(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Fill background with white
    NSColor.white.set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    
    let context = NSGraphicsContext.current!.cgContext
    context.setFillColor(NSColor.black.cgColor)
    
    // Generate resolution patterns
    let startX = width / 10
    let startY = height / 10
    let endX = width - startX
    let endY = height - startY
    
    // Horizontal lines
    let lineCount = 10
    let lineHeight = (endY - startY) / (lineCount * 2 - 1)
    
    for i in 0..<lineCount {
        let y = startY + i * lineHeight * 2
        context.fill(CGRect(
            x: startX,
            y: y,
            width: endX - startX,
            height: lineHeight
        ))
    }
    
    // Vertical lines
    let verticalLineWidth = (endX - startX) / (lineCount * 2 - 1)
    
    for i in 0..<lineCount {
        let x = startX + i * verticalLineWidth * 2
        context.fill(CGRect(
            x: x,
            y: startY,
            width: verticalLineWidth,
            height: endY - startY
        ))
    }
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Generate zone system pattern
func generateZoneSystem(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Create 11 zones (0-10)
    let zoneCount = 11
    let zoneWidth = width / zoneCount
    
    for zone in 0..<zoneCount {
        let brightness = CGFloat(zone) / CGFloat(zoneCount - 1)
        NSColor(white: brightness, alpha: 1.0).set()
        
        let rect = NSRect(
            x: zone * zoneWidth,
            y: 0,
            width: zoneWidth,
            height: height
        )
        rect.fill()
        
        // Draw zone number
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: height / 20),
            .foregroundColor: brightness > 0.5 ? NSColor.black : NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let text = "\(zone)"
        let textRect = NSRect(
            x: zone * zoneWidth,
            y: height / 2 - height / 40,
            width: zoneWidth,
            height: height / 20
        )
        
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Generate Macbeth ColorChecker pattern
func generateMacbethChart(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Fill background with light gray
    NSColor.lightGray.set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    
    // Macbeth chart has 24 patches (4x6)
    let rows = 4
    let cols = 6
    let margin = min(width, height) / 10
    
    let patchWidth = (width - 2 * margin) / cols
    let patchHeight = (height - 2 * margin) / rows
    
    // Macbeth chart RGB values (approximate)
    let colors = [
        // Row 1
        NSColor(red: 0.400, green: 0.233, blue: 0.196, alpha: 1.0),
        NSColor(red: 0.584, green: 0.376, blue: 0.314, alpha: 1.0),
        NSColor(red: 0.255, green: 0.278, blue: 0.439, alpha: 1.0),
        NSColor(red: 0.192, green: 0.318, blue: 0.243, alpha: 1.0),
        NSColor(red: 0.345, green: 0.267, blue: 0.400, alpha: 1.0),
        NSColor(red: 0.471, green: 0.439, blue: 0.196, alpha: 1.0),
        // Row 2
        NSColor(red: 0.667, green: 0.263, blue: 0.200, alpha: 1.0),
        NSColor(red: 0.325, green: 0.314, blue: 0.078, alpha: 1.0),
        NSColor(red: 0.431, green: 0.310, blue: 0.369, alpha: 1.0),
        NSColor(red: 0.176, green: 0.212, blue: 0.502, alpha: 1.0),
        NSColor(red: 0.384, green: 0.506, blue: 0.231, alpha: 1.0),
        NSColor(red: 0.875, green: 0.624, blue: 0.047, alpha: 1.0),
        // Row 3
        NSColor(red: 0.545, green: 0.192, blue: 0.306, alpha: 1.0),
        NSColor(red: 0.145, green: 0.369, blue: 0.235, alpha: 1.0),
        NSColor(red: 0.063, green: 0.176, blue: 0.365, alpha: 1.0),
        NSColor(red: 0.675, green: 0.451, blue: 0.059, alpha: 1.0),
        NSColor(red: 0.553, green: 0.231, blue: 0.459, alpha: 1.0),
        NSColor(red: 0.047, green: 0.482, blue: 0.620, alpha: 1.0),
        // Row 4
        NSColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1.0),
        NSColor(red: 0.753, green: 0.753, blue: 0.753, alpha: 1.0),
        NSColor(red: 0.502, green: 0.502, blue: 0.502, alpha: 1.0),
        NSColor(red: 0.251, green: 0.251, blue: 0.251, alpha: 1.0),
        NSColor(red: 0.122, green: 0.122, blue: 0.122, alpha: 1.0),
        NSColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 1.0)
    ]
    
    for row in 0..<rows {
        for col in 0..<cols {
            let index = row * cols + col
            colors[index].set()
            
            let rect = NSRect(
                x: margin + col * patchWidth,
                y: margin + (rows - row - 1) * patchHeight,
                width: patchWidth,
                height: patchHeight
            )
            rect.fill()
        }
    }
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Generate highlight recovery test pattern
func generateHighlightTest(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Fill background with middle gray
    NSColor(white: 0.5, alpha: 1.0).set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    
    let context = NSGraphicsContext.current!.cgContext
    
    // Create highlight regions
    let regions = 5
    let regionHeight = height / regions
    
    for i in 0..<regions {
        // Create gradient from white to bright color
        let brightness = 0.8 + CGFloat(i) * 0.05
        let startColor = NSColor.white
        let endColor = NSColor(calibratedRed: brightness, green: brightness, blue: brightness, alpha: 1.0)
        
        let gradient = NSGradient(starting: startColor, ending: endColor)!
        let rect = NSRect(
            x: 0,
            y: i * regionHeight,
            width: width,
            height: regionHeight
        )
        
        gradient.draw(in: rect, angle: 0)
        
        // Draw label
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: regionHeight / 8),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        let exposure = String(format: "+%.1f EV", 0.5 + Double(i) * 0.5)
        let textRect = NSRect(
            x: width / 3,
            y: i * regionHeight + regionHeight / 2 - regionHeight / 16,
            width: width / 3,
            height: regionHeight / 8
        )
        
        exposure.draw(in: textRect, withAttributes: attributes)
    }
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

/// Generate chromatic aberration test pattern
func generateChromaticTest(width: Int, height: Int, outputPath: String, noiseLevel: String? = nil) {
    #if canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    
    image.lockFocus()
    
    // Fill background with white
    NSColor.white.set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    
    let context = NSGraphicsContext.current!.cgContext
    
    // Draw high-contrast edges
    context.setLineWidth(3.0)
    
    // Draw black and white grid
    let gridSize = min(width, height) / 10
    let lineCount = max(width, height) / gridSize
    
    context.setStrokeColor(NSColor.black.cgColor)
    
    for i in 0...lineCount {
        // Vertical lines
        let x = i * gridSize
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: height))
        
        // Horizontal lines
        let y = i * gridSize
        context.move(to: CGPoint(x: 0, y: y))
        context.addLine(to: CGPoint(x: width, y: y))
    }
    
    context.strokePath()
    
    // Add noise if specified
    if let level = noiseLevel {
        addNoise(level: level)
    }
    
    image.unlockFocus()
    
    saveImage(image, to: outputPath)
    #else
    generateBlankImage(width: width, height: height, outputPath: outputPath)
    #endif
}

// MARK: - Special Test Cases

/// Generate a series of HDR test exposures
func generateHDRTestSeries() {
    let outputDir = "\(outputBaseDir)/HDRSeries"
    createDirectory(at: outputDir)
    
    let width = 1024
    let height = 768
    
    // Generate a base scene
    #if canImport(AppKit)
    let baseImage = NSImage(size: NSSize(width: width, height: height))
    
    baseImage.lockFocus()
    
    // Create a scene with high dynamic range
    // (gradient background with some elements)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0),
        NSColor(red: 0.8, green: 0.8, blue: 0.9, alpha: 1.0)
    ])!
    
    gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)
    
    // Draw some "scene elements"
    let context = NSGraphicsContext.current!.cgContext
    
    // Bright window/light
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: width/2 - 100, y: height/2 - 100, width: 200, height: 200))
    
    // Dark shadow area
    context.setFillColor(NSColor(white: 0.1, alpha: 1.0).cgColor)
    context.fill(CGRect(x: 50, y: 50, width: 300, height: 300))
    
    // Mid-tone area
    context.setFillColor(NSColor(white: 0.5, alpha: 1.0).cgColor)
    context.fill(CGRect(x: width - 350, y: 50, width: 300, height: 300))
    
    baseImage.unlockFocus()
    
    // Generate different exposures from the base scene
    let exposures = [-2.0, -1.0, 0.0, 1.0, 2.0]
    
    for (i, ev) in exposures.enumerated() {
        let outputPath = "\(outputDir)/exposure_\(i)_ev\(ev > 0 ? "+" : "")\(Int(ev)).png"
        
        // Apply exposure adjustment
        let exposedImage = NSImage(size: NSSize(width: width, height: height))
        exposedImage.lockFocus()
        
        // Draw the base image with exposure adjustment
        let exposureFactor = pow(2.0, ev)
        let tint = NSColor(white: 1.0, alpha: CGFloat(exposureFactor))
        
        baseImage.draw(in: NSRect(x: 0, y: 0, width: width, height: height),
                      from: NSRect.zero,
                      operation: .sourceOver,
                      fraction: ev < 0 ? 1.0 : CGFloat(1.0 / exposureFactor))
        
        if ev > 0 {
            // For overexposure, overlay with white
            tint.set()
            NSRect(x: 0, y: 0, width: width, height: height).fill(using: .sourceAtop)
        }
        
        // Add noise appropriate for the exposure
        if ev < 0 {
            // More noise in underexposed images
            addNoise(level: "high")
        } else if ev == 0 {
            addNoise(level: "medium")
        } else {
            addNoise(level: "low")
        }
        
        exposedImage.unlockFocus()
        
        saveImage(exposedImage, to: outputPath)
    }
    #else
    for i in 0..<5 {
        let outputPath = "\(outputDir)/exposure_\(i).png"
        generateBlankImage(width: width, height: height, outputPath: outputPath)
    }
    #endif
}

/// Generate a simulated burst sequence
func generateBurstSequence() {
    let outputDir = "\(outputBaseDir)/BurstSequence"
    createDirectory(at: outputDir)
    
    let width = 1024
    let height = 768
    
    #if canImport(AppKit)
    // Create base scene
    let baseImage = NSImage(size: NSSize(width: width, height: height))
    
    baseImage.lockFocus()
    
    // Fill with a gradient background
    let gradient = NSGradient(colors: [
        NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
        NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
    ])!
    
    gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 45)
    
    // Add some basic shapes
    let context = NSGraphicsContext.current!.cgContext
    
    // Circle
    context.setFillColor(NSColor.red.cgColor)
    context.fillEllipse(in: CGRect(x: width/2 - 100, y: height/2 - 100, width: 200, height: 200))
    
    // Rectangle
    context.setFillColor(NSColor.blue.cgColor)
    context.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
    
    // Triangle
    context.setFillColor(NSColor.green.cgColor)
    context.move(to: CGPoint(x: width - 100, y: 100))
    context.addLine(to: CGPoint(x: width - 300, y: 100))
    context.addLine(to: CGPoint(x: width - 200, y: 300))
    context.closePath()
    context.fillPath()
    
    baseImage.unlockFocus()
    
    // Generate burst images with slight variations
    let frameCount = 8
    
    for i in 0..<frameCount {
        let outputPath = "\(outputDir)/frame_\(i).png"
        
        // Create frame with variation
        let frameImage = NSImage(size: NSSize(width: width, height: height))
        frameImage.lockFocus()
        
        // Draw base image
        baseImage.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        
        // Add slight translation to simulate camera shake
        let translateX = CGFloat(arc4random_uniform(21) - 10) // -10 to +10
        let translateY = CGFloat(arc4random_uniform(21) - 10) // -10 to +10
        
        NSGraphicsContext.current!.cgContext.translateBy(x: translateX, y: translateY)
        
        // Add noise for each frame (simulating sensor noise variation)
        addNoise(level: "medium")
        
        frameImage.unlockFocus()
        
        saveImage(frameImage, to: outputPath)
    }
    
    // Create metadata file
    let metadata: [String: Any] = [
        "frame_count": frameCount,
        "width": width,
        "height": height,
        "bit_depth": 8,
        "frames": (0..<frameCount).map { [
            "filename": "frame_\($0).png",
            "exposure_time": 1.0/30.0,
            "iso": 100,
            "timestamp": Date().timeIntervalSince1970 + Double($0) * 0.1
        ] }
    ]
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    
    if let data = try? JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted) {
        let metadataPath = "\(outputDir)/metadata.json"
        try? data.write(to: URL(fileURLWithPath: metadataPath))
    }
    #else
    for i in 0..<8 {
        let outputPath = "\(outputDir)/frame_\(i).png"
        generateBlankImage(width: width, height: height, outputPath: outputPath)
    }
    
    // Create simple metadata file
    let metadataPath = "\(outputDir)/metadata.json"
    let metadataContent = "{ \"frame_count\": 8 }"
    try? metadataContent.write(to: URL(fileURLWithPath: metadataPath), atomically: true, encoding: .utf8)
    #endif
}

// MARK: - Helper Functions

/// Add noise to the current image context
func addNoise(level: String) {
    #if canImport(AppKit)
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    
    var intensity: CGFloat
    switch level {
    case "low":
        intensity = 0.05
    case "high":
        intensity = 0.2
    case "medium", _:
        intensity = 0.1
    }
    
    guard let currentContext = NSGraphicsContext.current,
          let image = currentContext.cgContext.makeImage() else { return }
    
    let width = image.width
    let height = image.height
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else { return }
    
    // Draw original image
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    context.draw(image, in: rect)
    
    // Get image data
    guard let data = context.data else { return }
    let dataPtr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    
    // Add random noise
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            
            for c in 0..<3 { // RGB channels
                let noise = CGFloat(arc4random_uniform(255)) / 255.0 * intensity
                let sign = arc4random_uniform(2) == 0 ? -1.0 : 1.0
                let value = CGFloat(dataPtr[offset + c]) / 255.0
                let newValue = max(0, min(1, value + CGFloat(sign) * noise))
                
                dataPtr[offset + c] = UInt8(newValue * 255.0)
            }
        }
    }
    
    // Create image from modified data
    guard let newImage = context.makeImage() else { return }
    
    // Draw back the noisy image
    NSGraphicsContext.current?.cgContext.draw(newImage, in: rect)
    #endif
}

/// Generate a blank image (for non-AppKit platforms)
func generateBlankImage(width: Int, height: Int, outputPath: String) {
    let message = "This is a placeholder. Image generation requires AppKit."
    
    let fileURL = URL(fileURLWithPath: outputPath)
    try? message.write(to: fileURL, atomically: true, encoding: .utf8)
    
    print("Platform doesn't support image generation. Created placeholder at: \(outputPath)")
}

/// Save image to file
func saveImage(_ image: Any, to path: String) {
    #if canImport(AppKit)
    if let nsImage = image as? NSImage,
       let tiffData = nsImage.tiffRepresentation,
       let bitmapImage = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
        
        try? pngData.write(to: URL(fileURLWithPath: path))
    }
    #endif
}

// MARK: - Run Main Function

main() 