#!/usr/bin/env swift

import Foundation

// Test TaskChampion integration directly
print("Testing TaskChampion integration...")

// Add the project directory to the import path
let projectDir = "/Users/emiller/src/personal/taskchamp"

// Try to load the framework
print("Current working directory: \(FileManager.default.currentDirectoryPath)")

// Create a simple test
do {
    print("✅ Test script is running")
    
    // Check if TaskChampion swift files exist
    let taskchampionPath = "\(projectDir)/Dependencies/taskchampion-swift/Sources/Taskchampion.swift"
    if FileManager.default.fileExists(atPath: taskchampionPath) {
        print("✅ TaskChampion source file exists at: \(taskchampionPath)")
    } else {
        print("❌ TaskChampion source file not found at: \(taskchampionPath)")
    }
    
    // Check if the Rust library exists
    let rustLibPath = "\(projectDir)/Dependencies/taskchampion-swift/tc-swiftbridge/target/aarch64-apple-ios-sim/release/libtc_swiftbridge.a"
    if FileManager.default.fileExists(atPath: rustLibPath) {
        print("✅ Rust library exists at: \(rustLibPath)")
    } else {
        print("❌ Rust library not found at: \(rustLibPath)")
    }
    
} catch {
    print("❌ Error: \(error)")
}