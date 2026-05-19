// ClaudePetApp.swift
import SwiftUI
import AppKit

@main
struct ClaudePetApp: App {
    // AppDelegate를 SwiftUI 앱에 연결
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 빈 Settings scene: 윈도우는 AppDelegate가 NSPanel로 직접 띄움
        Settings { EmptyView() }
    }
}
