//
//  PersistenceController.swift
//  CoreDataSync
//

import CareKit
import CareKitStore
import CloudKit
import CoreData
import UIKit

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController()
        let viewContext = result.container.viewContext

        // Preview data for CareKit entities
        let carePlan = OCKCarePlan(
            id: "",
            title: "",
            patientUUID: UUID()
        )
        //        (context: viewContext)
        //        carePlan.id = "preview-care-plan"
        //        carePlan.title = "Preview Care Plan"
        //        carePlan.uuid = UUID()
        //        carePlan.createdDate = Date()
        //        carePlan.effectiveDate = Date()
        //
        let task = OCKTask(
            id: "String",
            title: "title",
            carePlanUUID: UUID(),
            schedule: .dailyAtTime(
                hour: 8,
                minutes: 0,
                start: Date(),
                end: Date(),
                text: ""
            )
        )
        //        task.id = "blood-glucose-preview"
        //        task.title = "혈당 측정"
        //        task.instructions = "매일 혈당을 측정하고 기록하세요"
        //        task.uuid = UUID()
        //        task.createdDate = Date()
        //        task.effectiveDate = Date()
        //        task.carePlan = carePlan

        let scheduleElement = OCKScheduleElement(
            start: Date(),
            end: Date(),
            interval: DateComponents(hour: 24)
        )
        //        scheduleElement.startDate = Date()
        //        scheduleElement.interval = 1
        //        scheduleElement.type = "daily"
        //        scheduleElement.text = "매일"
        //        scheduleElement.task = task

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "CoreDataSync")

        // CloudKit 설정
        guard let description = container.persistentStoreDescriptions.first
        else {
            fatalError("PersistentStoreDescription not found")
        }

        // CloudKit container identifier 설정
        description.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.yourcompany.CareKitCloud"
            )

        // CloudKit 동기화 옵션
        description.setOption(
            true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey
        )
        description.setOption(
            true as NSNumber,
            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
        )

        container.viewContext.automaticallyMergesChangesFromParent = true

        container.loadPersistentStores(completionHandler: {
            (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")

                // CloudKit 관련 에러 처리
                //                if let cloudKitError = error.userInfo[
                //                    NSPersistentCloudKitContainerErrorUserInfoKey
                //                ] as? CKError {
                //                    print("CloudKit error: \(cloudKitError)")
                //                }
            } else {
                print("Core Data stores loaded successfully")
            }
        })

        // CloudKit 이벤트 모니터링
        container.viewContext.automaticallyMergesChangesFromParent = true

        return container
    }()
    

    // MARK: - CloudKit Sync

    /// CloudKit 동기화 상태 확인
    func checkCloudKitStatus() async -> CKAccountStatus {
        return await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error = error {
                    print("CloudKit account status error: \(error)")
                }
                continuation.resume(returning: status)
            }
        }
    }

    /// 수동 동기화 실행
    func sync() async throws {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// CloudKit 변경사항 모니터링
    func startCloudKitMonitoring() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { notification in
            self.handleCloudKitEvent(notification)
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard
            let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event
        else {
            return
        }

        switch event.type {
        case .setup:
            print("CloudKit setup completed")
        case .import:
            print("CloudKit import completed")
            NotificationCenter.default.post(
                name: .cloudKitDataDidChange,
                object: nil
            )
        case .export:
            print("CloudKit export completed")
        @unknown default:
            print("CloudKit unknown event type")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudKitDataDidChange = Notification.Name(
        "cloudKitDataDidChange"
    )
}
