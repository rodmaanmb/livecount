//
//  LIVECOUNTApp.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 08/01/2026.
//

import SwiftUI

@main
struct LIVECOUNTApp: App {

    init() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "runSelfTests") {
            MetricsCalculatorSelfTests.runAll()
        }
        #endif

    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
    }
}

