//
//  PersistenceController.swift
//  cloudNcarekit
//
//  Created by Ken on 8/19/25.
//

import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "CareKitStore")  // 모델 이름과 동일해야 함
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(
                fileURLWithPath: "/dev/null"
            )
        }

        // CloudKit 옵션 지정
        guard let description = container.persistentStoreDescriptions.first
        else {
            fatalError("Persistent store description not found.")
        }
        description.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(
                containerIdentifier: myContainerIdentifier
            )

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
