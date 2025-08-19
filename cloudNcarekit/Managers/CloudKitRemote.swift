//
//  CloudKitRemote.swift
//  cloudNcarekit
//
//  Created by Ken on 8/17/25.
//

import CareKit
import CareKitStore
import CloudKit

final class CloudKitRemote: OCKRemoteSynchronizable {
    var delegate: (any CareKitStore.OCKRemoteSynchronizationDelegate)?
    var automaticallySynchronizes: Bool = true

    private let container: CKContainer
    private let database: CKDatabase

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private enum RecordType {
        static let task = "CKTask"
        static let outcome = "CKOutcome"
    }

    private enum Field {
        static let payload = "payload"
        static let updatedAt = "updatedAt"
        static let id = "id"
        static let taskUUID = "taskUUID"
        static let taskOccurrenceIndex = "taskOccurrenceIndex"
    }

    private let lastPullDateKey = "CloudKitRemote.lastPullDate"

    init(containerIdentifier: String) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
    }

    func pushRevisions(
        deviceRevisions: [CareKitStore.OCKRevisionRecord],
        deviceKnowledge: CareKitStore.OCKRevisionRecord.KnowledgeVector,
        completion: @escaping ((any Error)?) -> Void
    ) {
        var recordsToSave: [CKRecord] = []
        do {
            for revision in deviceRevisions {
                for entity in revision.entities {
                    switch entity {
                    case .task(let task):
                        let uuid = task.uuid
                        let recID = CKRecord.ID(recordName: uuid.uuidString)
                        let rec = CKRecord(
                            recordType: RecordType.task,
                            recordID: recID
                        )
                        rec[Field.id] = task.id as CKRecordValue
                        rec[Field.updatedAt] =
                            (task.updatedDate ?? Date()) as CKRecordValue
                        rec[Field.payload] =
                            try encoder.encode(task) as CKRecordValue
                        recordsToSave.append(rec)
                    case .outcome(let outcome):
                        let uuid = outcome.uuid
                        let recID = CKRecord.ID(recordName: uuid.uuidString)
                        let rec = CKRecord(
                            recordType: RecordType.outcome,
                            recordID: recID
                        )
                        rec[Field.updatedAt] =
                            (outcome.updatedDate ?? Date()) as CKRecordValue
                        rec[Field.taskUUID] =
                            outcome.taskUUID.uuidString as CKRecordValue
                        rec[Field.taskOccurrenceIndex] = NSNumber(
                            value: outcome.taskOccurrenceIndex
                        )
                        rec[Field.payload] =
                            try encoder.encode(outcome) as CKRecordValue
                        recordsToSave.append(rec)
                    default:
                        continue
                    }
                }
            }
        } catch {
            completion(error)
            return
        }

        guard !recordsToSave.isEmpty else {
            completion(nil)
            return
        }

        let op = CKModifyRecordsOperation(
            recordsToSave: recordsToSave,
            recordIDsToDelete: nil
        )
        op.savePolicy = .allKeys
        op.isAtomic = false
        op.modifyRecordsCompletionBlock = { [weak self] _, _, error in
            if error == nil { self?.setLastPullDate(Date()) }
            completion(error)
        }
        database.add(op)
    }

    func chooseConflictResolution(
        conflicts: [CareKitStore.OCKEntity],
        completion: @escaping CareKitStore.OCKResultClosure<
            CareKitStore.OCKEntity
        >
    ) {
        let winner = conflicts.max { lhs, rhs in
            (lhs.updatedDate ?? .distantPast)
                < (rhs.updatedDate ?? .distantPast)
        }
        if let winner {
            completion(.success(winner))
        } else {
            completion(
                .failure(.fetchFailed(reason: "No conflicts to resolve"))
            )
        }
    }

    func pullRevisions(
        since knowledgeVector: OCKRevisionRecord.KnowledgeVector,
        mergeRevision: @escaping (OCKRevisionRecord) -> Void,
        completion: @escaping (Error?) -> Void
    ) {
        let sinceDate = lastPullDate() ?? .distantPast
        let group = DispatchGroup()
        var fetched: [OCKEntity] = []
        var firstError: Error?

        func fetch(type: String) {
            group.enter()
            let predicate = NSPredicate(
                format: "%K > %@",
                Field.updatedAt,
                sinceDate as NSDate
            )
            let query = CKQuery(recordType: type, predicate: predicate)
            let op = CKQueryOperation(query: query)
            op.resultsLimit = 200

            op.recordFetchedBlock = { [weak self] record in
                guard let self = self else { return }
                do {
                    if type == RecordType.task,
                        let data = record[Field.payload] as? Data
                    {
                        let task = try self.decoder.decode(
                            OCKTask.self,
                            from: data
                        )
                        fetched.append(.task(task))
                    } else if type == RecordType.outcome,
                        let data = record[Field.payload] as? Data
                    {
                        let outcome = try self.decoder.decode(
                            OCKOutcome.self,
                            from: data
                        )
                        fetched.append(.outcome(outcome))
                    }
                } catch {
                    if firstError == nil { firstError = error }
                    print("CloudKitRemote decode error: \(error)")
                }
            }

            op.queryCompletionBlock = { _, error in
                if firstError == nil, let error = error { firstError = error }
                group.leave()
            }
            database.add(op)
        }

        fetch(type: RecordType.task)
        fetch(type: RecordType.outcome)

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if !fetched.isEmpty {
                let revision = OCKRevisionRecord(
                    entities: fetched,
                    knowledgeVector: knowledgeVector
                )
                mergeRevision(revision)
                self.setLastPullDate(Date())
            }
            completion(firstError)
        }
    }

    private func lastPullDate() -> Date? {
        UserDefaults.standard.object(forKey: lastPullDateKey) as? Date
    }

    private func setLastPullDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastPullDateKey)
    }
}

extension OCKEntity {
    fileprivate var updatedDate: Date? {
        switch self {
        case .task(let t): return t.updatedDate
        case .outcome(let o): return o.updatedDate
        case .contact(let c): return c.updatedDate
        case .carePlan(let p): return p.updatedDate
        case .patient(let p): return p.updatedDate
        case .healthKitTask(let t): return t.updatedDate
        @unknown default: return nil
        }
    }
}
