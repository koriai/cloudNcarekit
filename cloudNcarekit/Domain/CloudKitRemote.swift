import CareKitStore
import CloudKit
import Foundation

let carekitRecordType = "CareKitEntity"

/// A minimal CloudKit remote for CareKit
final class CloudKitRemote: OCKRemoteSynchronizable {

    var automaticallySynchronizes: Bool

    func chooseConflictResolution(
        conflicts: [CareKitStore.OCKEntity],
        completion: @escaping CareKitStore.OCKResultClosure<
            CareKitStore.OCKEntity
        >
    ) {
        //
    }

    // MARK: - Properties

    let database: CKDatabase
    weak var delegate: OCKRemoteSynchronizationDelegate?

    init(
        container: CKContainer,
        scope: CKDatabase.Scope
    ) {
        self.database = {
            switch scope {
            case .private: return container.privateCloudDatabase
            case .public: return container.publicCloudDatabase
            case .shared: return container.sharedCloudDatabase
            @unknown default:
                return container.privateCloudDatabase
            }
        }()
        self.automaticallySynchronizes = true
    }

    // MARK: - OCKRemoteSynchronizable

    func pullRevisions(
        since knowledgeVector: CareKitStore.OCKRevisionRecord.KnowledgeVector,
        mergeRevision: @escaping (CareKitStore.OCKRevisionRecord) -> Void,
        completion: @escaping ((any Error)?) -> Void
    ) {
        // 1. Fetch records from CloudKit
        let query = CKQuery(
            recordType: carekitRecordType,
            predicate: NSPredicate(value: true)
        )

        database.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(error)
                return
            }

            guard let records = records else {
                completion(nil)
                return
            }

            // 2. Map CKRecords → OCKEntities
            var patients: [OCKPatient] = []
            var careplans: [OCKCarePlan] = []
            var tasks: [OCKTask] = []
            var outcomes: [OCKOutcome] = []

            for record in records {
                if let type = record["type"] as? String {
                    switch type {
                    case "patient":
                        if let name = record["name"] as? String {
                            let patient = OCKPatient(
                                id: record.recordID.recordName,
                                givenName: name,
                                familyName: ""
                            )
                            patients.append(patient)
                        }
                    case "careplan":
                        if let name = record["title"] as? String {
                            let careplan = OCKCarePlan(
                                id: record.recordID.recordName,
                                title: name,
                                patientUUID: nil
                            )

                            careplans.append(careplan)
                        }
                    case "task":
                        if let title = record["title"] as? String {
                            let task = OCKTask(
                                id: record.recordID.recordName,
                                title: title,
                                carePlanUUID: nil,
                                schedule: .dailyAtTime(
                                    hour: 8,
                                    minutes: 0,
                                    start: Date(),
                                    end: nil,
                                    text: ""
                                )
                            )
                            tasks.append(task)
                        }
                    case "outcome":
                        // Simplified outcome
                        let outcome = OCKOutcome(
                            taskUUID: UUID(),
                            taskOccurrenceIndex: 0,
                            values: []
                        )
                        outcomes.append(outcome)
                    default: break
                    }
                }
            }

            // 3. Build revision record
            let revision = OCKRevisionRecord(
                entities: patients.map { .patient($0) }
                    + tasks.map { .task($0) } + outcomes.map { .outcome($0) },
                knowledgeVector: OCKRevisionRecord.KnowledgeVector()
            )

            // 4. Merge into local store
            mergeRevision(revision)
            completion(nil)
        }
    }

    func pushRevisions(
        deviceRevisions: [CareKitStore.OCKRevisionRecord],
        deviceKnowledge: CareKitStore.OCKRevisionRecord.KnowledgeVector,
        completion: @escaping ((any Error)?) -> Void
    ) {
        var records: [CKRecord] = []

        for revision in deviceRevisions {
            for entity in revision.entities {
                let record: CKRecord

                switch entity {
                case .patient(let patient):
                    record = CKRecord(
                        recordType: carekitRecordType,
                        recordID: CKRecord.ID(recordName: patient.id)
                    )
                    record["type"] = "patient"
                    record["name"] = patient.name.givenName
                case .carePlan(let careplan):
                    record = CKRecord(
                        recordType: carekitRecordType,
                        recordID: CKRecord.ID(recordName: careplan.id)
                    )
                    record["type"] = "careplan"
                case .task(let task):
                    record = CKRecord(
                        recordType: carekitRecordType,
                        recordID: CKRecord.ID(recordName: task.id)
                    )
                    record["type"] = "task"
                    record["title"] = task.title
                case .outcome:
                    record = CKRecord(recordType: carekitRecordType)
                    record["type"] = "outcome"
                default:
                    continue
                }

                records.append(record)
            }
        }

        let operation = CKModifyRecordsOperation(
            recordsToSave: records,
            recordIDsToDelete: nil
        )
        operation.modifyRecordsCompletionBlock = { _, _, error in
            completion(error)
        }
        database.add(operation)
    }

    func reset(completion: @escaping (Error?) -> Void) {
        // Clear all CK records (careful in production!)
        let query = CKQuery(
            recordType: "CareKitEntity",
            predicate: NSPredicate(value: true)
        )
        database.perform(query, inZoneWith: nil) { records, error in
            guard let records = records else {
                completion(error)
                return
            }
            let operation = CKModifyRecordsOperation(
                recordsToSave: nil,
                recordIDsToDelete: records.map { $0.recordID }
            )
            operation.modifyRecordsCompletionBlock = { _, _, error in
                completion(error)
            }
            self.database.add(operation)
        }
    }
}
