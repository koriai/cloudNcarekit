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
        // For this example, we'll just choose the first one.
        // A real app might require a more sophisticated strategy, like choosing the most recent version.
        if let first = conflicts.first {
            completion(.success(first))
        }
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

    //MARK: - Pull
    func pullRevisions(
        since knowledgeVector: CareKitStore.OCKRevisionRecord.KnowledgeVector,
        mergeRevision: @escaping (CareKitStore.OCKRevisionRecord) -> Void,
        completion: @escaping ((any Error)?) -> Void
    ) {
        let query = CKQuery(recordType: carekitRecordType, predicate: NSPredicate(value: true))

        database.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(error)
                return
            }

            guard let records = records else {
                completion(nil)
                return
            }

            var patients: [OCKPatient] = []
            var careplans: [OCKCarePlan] = []
            var tasks: [OCKTask] = []
            var outcomes: [OCKOutcome] = []

            for record in records {
                guard let type = record["type"] as? String else { continue }
                
                switch type {
                case "patient":
                    let patient = OCKPatient(
                        id: record.recordID.recordName,
                        givenName: record["name"] as? String ?? "",
                        familyName: ""
                    )
                    patients.append(patient)
                    
                case "careplan":
                    // ✅ [PULL] CloudKit의 'patient' 참조(Reference) 필드에서 patientUUID를 복원합니다.
                    var patientUUID: UUID?
                    if let patientRef = record["patient"] as? CKRecord.Reference {
                        patientUUID = UUID(uuidString: patientRef.recordID.recordName)
                    }
                    
                    let careplan = OCKCarePlan(
                        id: record.recordID.recordName,
                        title: record["title"] as? String ?? "",
                        patientUUID: patientUUID
                    )
                    careplans.append(careplan)
                    
                case "task":
                    // ✅ [PULL] CloudKit의 'carePlan' 참조(Reference) 필드에서 carePlanUUID를 복원합니다.
                    var carePlanUUID: UUID?
                    if let carePlanRef = record["carePlan"] as? CKRecord.Reference {
                        carePlanUUID = UUID(uuidString: carePlanRef.recordID.recordName)
                    }

                    let task = OCKTask(
                        id: record.recordID.recordName,
                        title: record["title"] as? String ?? "",
                        carePlanUUID: carePlanUUID,
                        schedule: .dailyAtTime(hour: 8, minutes: 0, start: Date(), end: nil, text: "")
                    )
                    tasks.append(task)
                    
                case "outcome":
                    // Outcome pull logic if needed
                    break
                    
                default: break
                }
            }

            let revision = OCKRevisionRecord(
                entities: patients.map { .patient($0) } + careplans.map { .carePlan($0) } + tasks.map { .task($0) } + outcomes.map { .outcome($0) },
                knowledgeVector: .init()
            )

            mergeRevision(revision)
            completion(nil)
        }
    }

    // MARK: - PUSH
    func pushRevisions(
        deviceRevisions: [CareKitStore.OCKRevisionRecord],
        deviceKnowledge: CareKitStore.OCKRevisionRecord.KnowledgeVector,
        completion: @escaping ((any Error)?) -> Void
    ) {
        // Use a dictionary for records to save. This ensures that for any given ID,
        // only the latest version from the revisions is included, preventing "save same record twice" errors.
        var recordsToSaveDict: [CKRecord.ID: CKRecord] = [:]
        
        // Use a set for record IDs to delete to automatically handle duplicates.
        var recordIDsToDeleteSet: Set<CKRecord.ID> = Set()

        for revision in deviceRevisions {
            for entity in revision.entities {
                switch entity {
                case .patient(let patient):
                    let recordID = CKRecord.ID(recordName: patient.id)
                    if patient.deletedDate != nil {
                        recordIDsToDeleteSet.insert(recordID)
                        recordsToSaveDict.removeValue(forKey: recordID)
                    } else {
                        let record = CKRecord(recordType: carekitRecordType, recordID: recordID)
                        record["type"] = "patient"
                        record["name"] = patient.name.givenName ?? ""
                        recordsToSaveDict[recordID] = record
                        recordIDsToDeleteSet.remove(recordID) // Ensure it's not marked for both save and delete
                    }
                    
                case .carePlan(let carePlan):
                    let recordID = CKRecord.ID(recordName: carePlan.id)
                    if carePlan.deletedDate != nil {
                        recordIDsToDeleteSet.insert(recordID)
                        recordsToSaveDict.removeValue(forKey: recordID)
                    } else {
                        let record = CKRecord(recordType: carekitRecordType, recordID: recordID)
                        record["type"] = "careplan"
                        record["title"] = carePlan.title
                        
                        if let patientUUID = carePlan.patientUUID {
                            let patientID = CKRecord.ID(recordName: patientUUID.uuidString)
                            record["patient"] = CKRecord.Reference(recordID: patientID, action: .deleteSelf)
                        }
                        recordsToSaveDict[recordID] = record
                        recordIDsToDeleteSet.remove(recordID)
                    }

                case .task(let task):
                    let recordID = CKRecord.ID(recordName: task.id)
                    if task.deletedDate != nil {
                        recordIDsToDeleteSet.insert(recordID)
                        recordsToSaveDict.removeValue(forKey: recordID)
                    } else {
                        let record = CKRecord(recordType: carekitRecordType, recordID: recordID)
                        record["type"] = "task"
                        record["title"] = task.title ?? ""

                        if let carePlanUUID = task.carePlanUUID {
                            let carePlanID = CKRecord.ID(recordName: carePlanUUID.uuidString)
                            record["carePlan"] = CKRecord.Reference(recordID: carePlanID, action: .deleteSelf)
                        }
                        recordsToSaveDict[recordID] = record
                        recordIDsToDeleteSet.remove(recordID)
                    }
                    
                case .outcome(let outcome):
                    let recordID = CKRecord.ID(recordName: outcome.id)
                    if outcome.deletedDate != nil {
                        recordIDsToDeleteSet.insert(recordID)
                        recordsToSaveDict.removeValue(forKey: recordID)
                    } else {
                        let record = CKRecord(recordType: carekitRecordType, recordID: recordID)
                        record["type"] = "outcome"
                        // Add any necessary outcome data to the record here
                        recordsToSaveDict[recordID] = record
                        recordIDsToDeleteSet.remove(recordID)
                    }
                    
                default:
                    continue
                }
            }
        }

        let operation = CKModifyRecordsOperation(
            recordsToSave: Array(recordsToSaveDict.values),
            recordIDsToDelete: Array(recordIDsToDeleteSet)
        )
        operation.savePolicy = .changedKeys
        
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if let error = error {
                print("❌ CloudKit Modify Error: \(error.localizedDescription)")
                if let ckError = error as? CKError, let partialErrors = ckError.partialErrorsByItemID {
                    for (recordID, partialError) in partialErrors {
                        print("   - Failed on RecordID \(recordID.description): \(partialError.localizedDescription)")
                    }
                }
            } else {
                print("☁️ CloudKit Push Success! Saved: \(savedRecords?.count ?? 0), Deleted: \(deletedRecordIDs?.count ?? 0)")
            }
            completion(error)
        }
        database.add(operation)
    }

    func reset(completion: @escaping (Error?) -> Void) {
        // Implementation for reset if needed
        completion(nil)
    }
}
