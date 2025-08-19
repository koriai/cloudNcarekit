//
//  cloudNcarekitApp.swift
//  cloudNcarekit
//
//  Created by Ken on 8/17/25.
//

import SwiftData
import SwiftUI

@main
struct cloudNcarekitApp: App {

    init() {
        CareKitManager.configure(mode: .coreData)  // 여기서 선택
    }

//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            BloodGlucose.self
//        ])
//        let modelConfiguration = ModelConfiguration(
//            schema: schema,
//            isStoredInMemoryOnly: false,
//            cloudKitDatabase: .private(myContainerIdentifier)
//        )
//
//        do {
//            return try ModelContainer(
//                for: schema,
//                configurations: [modelConfiguration],
//                
//            )
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }.environmentObject(CareKitManager.shared)
//            .modelContainer(sharedModelContainer)
    }
}
