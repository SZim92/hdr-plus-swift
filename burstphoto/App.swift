/**
 * Main Application File for Burst Photo
 *
 * This file defines the application entry point, window behavior, and settings management
 * for the Burst Photo application. It handles application lifecycle events, user preferences
 * storage, window configuration, and the initial view hierarchy.
 */
import SwiftUI
import AppKit

/**
 * Application settings and user preferences management
 *
 * This class serves as the central store for user preferences, persisting them
 * using the @AppStorage property wrapper which stores values in UserDefaults.
 * These settings control various aspects of the photo processing algorithms.
 */
class AppSettings: ObservableObject {
    @AppStorage("tile_size") var tile_size: String = "Medium"
    @AppStorage("search_distance") var search_distance: String = "Medium"
    @AppStorage("merging_algorithm") var merging_algorithm: String = "Fast"
    @AppStorage("noise_reduction") var noise_reduction: Double = 13.0
    @AppStorage("exposure_control") var exposure_control: String = " Linear (full bit range)"
    @AppStorage("output_bit_depth") var output_bit_depth: String = "Native"
}

/**
 * Application delegate handling lifecycle events and application-level behaviors
 *
 * This class manages application startup, shutdown, and window behaviors,
 * including directory setup for output files and temporary storage.
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

/**
 * Extension adding window resizability control based on macOS version
 *
 * This extension enables consistent window behavior across different
 * macOS versions by adapting to API changes in macOS 13+.
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

/**
 * Main application structure defining the app's entry point and UI organization
 *
 * This structure:
 * - Initializes the application delegate
 * - Creates the main window and view hierarchy
 * - Configures window styling and behavior
 * - Sets up application menus
 * - Manages XMP SDK initialization and termination
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
    
    /**
     * Disables window resizing and full-screen functionality
     *
     * This method is called when the window updates to ensure consistent
     * window behavior by hiding the zoom button and preventing full-screen mode.
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
