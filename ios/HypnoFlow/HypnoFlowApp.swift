//
//  HypnoFlowApp.swift
//  HypnoFlow
//
//  Created by Rork on July 4, 2026.
//

import SwiftUI

@main
struct HypnoFlowApp: App {
    @State private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
