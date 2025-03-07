/**
 * Main Application File for Burst Photo
 *
 * This file defines the application entry point, window behavior, and settings management
 * for the Burst Photo application. It handles application lifecycle events, user preferences
 * storage, window configuration, and the initial view hierarchy.
 */
import SwiftUI
import AppKit

/*
 * AppSettings - User Preferences and Application Settings
 *
 * This class encapsulates user-configurable settings for the Burst Photo application.
 * It leverages the @AppStorage property wrapper to persist settings in UserDefaults,
 * influencing photo processing parameters and user interface behaviors.
 */
class AppSettings: ObservableObject {
    @AppStorage("tile_size") var tile_size: String = "Medium"
    @AppStorage("search_distance") var search_distance: String = "Medium"
    @AppStorage("merging_algorithm") var merging_algorithm: String = "Fast"
    @AppStorage("noise_reduction") var noise_reduction: Double = 13.0
    @AppStorage("exposure_control") var exposure_control: String = " Linear (full bit range)"
    @AppStorage("output_bit_depth") var output_bit_depth: String = "Native"
}

/*
 * AppDelegate - Application Lifecycle Management
 * Handles application lifecycle events including launching, termination, and resource management.
 * Performs essential setup like initializing directories and cleaning up temporary files during termination.
 */
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /**
     * Ensures the application terminates when the main window is closed
     */
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // ensures that the app is terminated when the window is closed
        // https://stackoverflow.com/a/65743682/6495494
        return true
    }
    
    /**
     * Performs initialization tasks when the application finishes launching
     *
     * This method:
     * - Disables window tabbing to prevent tab creation
     * - Creates the output directory for processed photos
     * - Cleans up and creates a temporary directory for DNG files
     */
    func applicationDidFinishLaunching(_ notification: Notification) {
        // ensure that tabs cannot be created
        // let _ = NSApplication.shared.windows.map { $0.tabbingMode = .disallowed }
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // create output directory
        if !FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Pictures/Burst Photo/") {
            do {
                try FileManager.default.createDirectory(atPath: NSHomeDirectory() + "/Pictures/Burst Photo/", withIntermediateDirectories: true, attributes: nil)
            } catch {}
        }
        
        do {
            // If it exists, delete a previously leftover temporary directory
            var isDirectory : ObjCBool = true
            if FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Pictures/Burst Photo/.dngs/", isDirectory: &isDirectory) {
                try FileManager.default.removeItem(atPath: NSHomeDirectory() + "/Pictures/Burst Photo/.dngs/")
            }
            try FileManager.default.createDirectory(atPath: NSHomeDirectory() + "/Pictures/Burst Photo/.dngs/", withIntermediateDirectories: true)
        } catch {}
    }
    
    /**
     * Performs cleanup before the application terminates
     *
     * Deletes the temporary DNG directory used during photo processing
     */
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Delete the temporary DNG directory
        do {
            try FileManager.default.removeItem(atPath: NSHomeDirectory() + "/Pictures/Burst Photo/.dngs/")
        } catch {}
        return .terminateNow
    }
}

/*
 * Scene Extension
 * Provides additional window configuration utilities for the application.
 * Includes functionality to disable window resizing and full-screen mode to ensure a consistent UI layout.
 */
extension Scene {
    // disables window resizability on macos 13
    // https://developer.apple.com/forums/thread/719389?answerId=735997022#735997022
    func windowResizabilityContentSize() -> some Scene {
        if #available(macOS 13.0, *) {
            return windowResizability(.contentSize)
        } else {
            return self
        }
    }
}

/*
 * burstphotoApp - Main Application Entry Point
 *
 * This struct is the primary entry point for the Burst Photo application. It configures the main window,
 * sets up the SwiftUI view hierarchy, and bridges necessary AppKit functionalities for window
 * management and custom command handling. This struct integrates the user settings and application
 * lifecycle events to provide a cohesive and robust user experience.
 */
@main
struct burstphotoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var settings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willUpdateNotification), perform: { _ in disable_window_resizing()})
                .onAppear {initialize_xmp_sdk()}
                .onDisappear {terminate_xmp_sdk()}
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizabilityContentSize()
        .commands {
            CommandGroup(replacing: .newItem, addition: {}) // disables creating any new windows
            CommandGroup(replacing: .help) { // open Burst Photo website
                Button(action: {NSWorkspace.shared.open(URL(string: "https://burst.photo/help/")!)}) {
                    Text("Burst Photo Help")
                }
            }
        }
        Settings {
            SettingsView(settings: settings)
        }
    }
    
    /*
     * disable_window_resizing
     * Iterates through application windows to disable resizing and full-screen modes.
     * This function ensures that the main application window maintains its intended fixed dimensions.
     */
    func disable_window_resizing() {
        for window in NSApplication.shared.windows {
            // hides the "full screen" green button
            if let zoom_button = window.standardWindowButton(NSWindow.ButtonType.zoomButton) {
                zoom_button.isHidden = true
            }
            
            // disables full screen mode
            window.collectionBehavior = .fullScreenNone
        }
    }
}
