import CareKit
import CareKitFHIR
import CareKitStore
import Foundation
import SwiftData
import CoreData

// MARK: - BloodGlucose Model
class BloodGlucose: NSManagedObject {
    @NSManaged var value: Double
    @NSManaged var unit: String
    @NSManaged var timestamp: Date
    @NSManaged var notes: String
}

//
//// MARK: - FHIR Integration
//extension BloodGlucose {
//
//    /// Convert BloodGlucose to FHIR-compatible OCKHealthKitPassthroughStore format
//    func toFHIRObservation(patientId: String = "patient-1") -> [String: Any] {
//        var observation: [String: Any] = [:]
//
//        // Basic FHIR Observation structure
//        observation["resourceType"] = "Observation"
//        observation["id"] = UUID().uuidString
//        observation["status"] = "final"
//        observation["effectiveDateTime"] = ISO8601DateFormatter().string(
//            from: timestamp
//        )
//
//        // Subject (Patient reference)
//        observation["subject"] = [
//            "reference": "Patient/\(patientId)"
//        ]
//
//        // Category - vital signs
//        observation["category"] = [
//            [
//                "coding": [
//                    [
//                        "system":
//                            "http://terminology.hl7.org/CodeSystem/observation-category",
//                        "code": "vital-signs",
//                        "display": "Vital Signs",
//                    ]
//                ]
//            ]
//        ]
//
//        // Code - Blood glucose (LOINC)
//        observation["code"] = [
//            "coding": [
//                [
//                    "system": "http://loinc.org",
//                    "code": "33747-0",
//                    "display": "Glucose [Mass/volume] in Blood",
//                ]
//            ]
//        ]
//
//        // Value - glucose measurement
//        observation["valueQuantity"] = [
//            "value": value,
//            "unit": unit,
//            "system": "http://unitsofmeasure.org",
//            "code": unit,
//        ]
//
//        // Notes if available
//        if let notes = notes, !notes.isEmpty {
//            observation["note"] = [
//                [
//                    "text": notes,
//                    "time": ISO8601DateFormatter().string(from: Date()),
//                ]
//            ]
//        }
//
//        return observation
//    }
//
//    /// Create BloodGlucose from FHIR Observation dictionary
//    static func fromFHIRObservation(_ observationDict: [String: Any])
//        -> BloodGlucose?
//    {
//        guard
//            let valueQuantity = observationDict["valueQuantity"]
//                as? [String: Any],
//            let value = valueQuantity["value"] as? Double,
//            let unit = valueQuantity["unit"] as? String,
//            let effectiveDateTimeString = observationDict["effectiveDateTime"]
//                as? String,
//            let timestamp = ISO8601DateFormatter().date(
//                from: effectiveDateTimeString
//            )
//        else {
//            return nil
//        }
//
//        // Extract notes if available
//        var notes: String? = nil
//        if let noteArray = observationDict["note"] as? [[String: Any]],
//            let firstNote = noteArray.first,
//            let noteText = firstNote["text"] as? String
//        {
//            notes = noteText
//        }
//
//        return BloodGlucose(
//            value: value,
//            unit: unit,
//            timestamp: timestamp,
//            notes: notes
//        )
//    }
//}
//
//// MARK: - CareKit Integration
//extension BloodGlucose {
//
//    /// Convert to CareKit OCKOutcome
//    func toOCKOutcome(for taskUUID: UUID? = nil, taskOccurrenceIndex: Int = 0)
//        -> OCKOutcome
//    {
//        // Main glucose value
//        let glucoseValue = OCKOutcomeValue(value, units: unit)
//        var values = [glucoseValue]
//
//        // Add notes if available
//        if let notes = notes, !notes.isEmpty {
//            let notesValue = OCKOutcomeValue(notes, units: "notes")
//            values.append(notesValue)
//        }
//
//        var outcome = OCKOutcome(
//            taskUUID: taskUUID ?? UUID(),
//            taskOccurrenceIndex: taskOccurrenceIndex,
//            values: values
//        )
//        outcome.createdDate = timestamp
//
//        return outcome
//    }
//
//    /// Create BloodGlucose from CareKit OCKOutcome
//    static func fromOCKOutcome(_ outcome: OCKOutcome) -> BloodGlucose? {
//        // Find glucose value (mg/dL or mmol/L)
//        guard
//            let glucoseValue = outcome.values.first(where: {
//                $0.units == "mg/dL" || $0.units == "mmol/L"
//            }),
//            let value = glucoseValue.doubleValue,
//            let unit = glucoseValue.units
//        else {
//            return nil
//        }
//
//        // Extract notes
//        let notesValue = outcome.values.first(where: { $0.units == "notes" })
//        let notes = notesValue?.stringValue
//
//        return BloodGlucose(
//            value: value,
//            unit: unit,
//            timestamp: outcome.createdDate ?? Date(),
//            notes: notes
//        )
//    }
//}
//
//// MARK: - Blood Glucose Manager
//class BloodGlucoseManager {
//    private let careStore: OCKStore
//
//    init(careStore: OCKStore) {
//        self.careStore = careStore
//    }
//
//    /// Save blood glucose measurement
//    func saveBloodGlucose(
//        _ bloodGlucose: BloodGlucose,
//        taskID: String = "blood-glucose"
//    ) async throws -> OCKOutcome {
//        // First, get the task to find its UUID
//        var taskQuery = OCKTaskQuery()
//        taskQuery.ids = [taskID]
//
//        let tasks = try await careStore.fetchTasks(query: taskQuery)
//        guard let task = tasks.first else {
//            throw BloodGlucoseError.taskNotFound
//        }
//
//        // Create outcome with task UUID
//        let outcome = bloodGlucose.toOCKOutcome(
//            for: task.uuid,
//            taskOccurrenceIndex: 0
//        )
//
//        // Save to CareKit store
//        let savedOutcome = try await careStore.addOutcome(outcome)
//        return savedOutcome
//    }
//
//    /// Fetch blood glucose measurements within date range
//    func fetchBloodGlucoseReadings(
//        from startDate: Date,
//        to endDate: Date,
//        taskID: String = "blood-glucose"
//    ) async throws -> [BloodGlucose] {
//        let dateInterval = DateInterval(start: startDate, end: endDate)
//        var query = OCKOutcomeQuery(dateInterval: dateInterval)
//        query.taskIDs = [taskID]
//
//        let outcomes = try await careStore.fetchOutcomes(query: query)
//        return outcomes.compactMap { BloodGlucose.fromOCKOutcome($0) }
//    }
//
//    /// Fetch all blood glucose measurements
//    func fetchAllBloodGlucoseReadings(taskID: String = "blood-glucose")
//        async throws -> [BloodGlucose]
//    {
//        var query = OCKOutcomeQuery()
//        query.taskIDs = [taskID]
//
//        let outcomes = try await careStore.fetchOutcomes(query: query)
//        return outcomes.compactMap { BloodGlucose.fromOCKOutcome($0) }
//    }
//
//    /// Create blood glucose monitoring task
//    func createBloodGlucoseTask(taskID: String = "blood-glucose") async throws
//        -> OCKTask
//    {
//        // Create a schedule for blood glucose monitoring
//        // Daily measurements at specific times
//        let schedule = OCKSchedule.dailyAtTime(
//            hour: 8,
//            minutes: 0,
//            start: Date(),
//            end: nil,
//            text: "혈당 측정"
//        )
//
//        var task = OCKTask(
//            id: taskID,
//            title: "혈당 측정",
//            carePlanUUID: nil,
//            schedule: schedule
//        )
//        task.instructions = "혈당 측정기를 사용하여 혈당을 측정하고 결과를 기록해주세요."
//        task.asset = "glucose.meter"  // Asset name for icon
//
//        let savedTask = try await careStore.addTask(task)
//        return savedTask
//    }
//
//    /// Update blood glucose measurement
//    func updateBloodGlucose(_ bloodGlucose: BloodGlucose, outcomeUUID: UUID)
//        async throws -> OCKOutcome
//    {
//        // Fetch existing outcome
//        var query = OCKOutcomeQuery()
//        query.uuids = [outcomeUUID]
//
//        let outcomes = try await careStore.fetchOutcomes(query: query)
//        guard var existingOutcome = outcomes.first else {
//            throw BloodGlucoseError.outcomeNotFound
//        }
//
//        // Update values
//        let glucoseValue = OCKOutcomeValue(
//            bloodGlucose.value,
//            units: bloodGlucose.unit
//        )
//        var values = [glucoseValue]
//
//        if let notes = bloodGlucose.notes, !notes.isEmpty {
//            let notesValue = OCKOutcomeValue(notes, units: "notes")
//            values.append(notesValue)
//        }
//
//        existingOutcome.values = values
//        existingOutcome.createdDate = bloodGlucose.timestamp
//
//        let updatedOutcome = try await careStore.updateOutcome(existingOutcome)
//        return updatedOutcome
//    }
//
//    /// Delete blood glucose measurement
//    func deleteBloodGlucose(outcomeUUID: UUID) async throws {
//        var query = OCKOutcomeQuery()
//        query.uuids = [outcomeUUID]
//
//        let outcomes = try await careStore.fetchOutcomes(query: query)
//        guard let outcome = outcomes.first else {
//            throw BloodGlucoseError.outcomeNotFound
//        }
//
//        try await careStore.deleteOutcome(outcome)
//    }
//}
//
//// MARK: - Error Handling
//enum BloodGlucoseError: Error, LocalizedError {
//    case taskNotFound
//    case outcomeNotFound
//    case invalidData
//    case conversionError
//
//    var errorDescription: String? {
//        switch self {
//        case .taskNotFound:
//            return "혈당 측정 태스크를 찾을 수 없습니다."
//        case .outcomeNotFound:
//            return "혈당 측정 결과를 찾을 수 없습니다."
//        case .invalidData:
//            return "유효하지 않은 혈당 데이터입니다."
//        case .conversionError:
//            return "데이터 변환 중 오류가 발생했습니다."
//        }
//    }
//}
//
//// MARK: - FHIR Store Integration
//extension BloodGlucoseManager {
//
//    /// Convert and export blood glucose data to FHIR format
//    func exportToFHIR(patientId: String = "patient-1") async throws -> [[String:
//        Any]]
//    {
//        let bloodGlucoseReadings = try await fetchAllBloodGlucoseReadings()
//        return bloodGlucoseReadings.map {
//            $0.toFHIRObservation(patientId: patientId)
//        }
//    }
//
//    /// Import FHIR observations and save as blood glucose measurements
//    func importFromFHIR(
//        _ fhirObservations: [[String: Any]],
//        taskID: String = "blood-glucose"
//    ) async throws {
//        for observationDict in fhirObservations {
//            if let bloodGlucose = BloodGlucose.fromFHIRObservation(
//                observationDict
//            ) {
//                try await saveBloodGlucose(bloodGlucose, taskID: taskID)
//            }
//        }
//    }
//}
//
//// MARK: - Usage Example
//class BloodGlucoseExample {
//
//    static func exampleUsage() async {
//        // Initialize store and manager
//        let store = OCKStore(name: "MyHealthStore", type: .onDisk())
//        let manager = BloodGlucoseManager(careStore: store)
//
//        do {
//            // 1. Create blood glucose task
//            let task = try await manager.createBloodGlucoseTask()
//            print("Created task: \(task.title)")
//
//            // 2. Create and save blood glucose reading
//            let reading = BloodGlucose(
//                value: 95.0,
//                unit: "mg/dL",
//                timestamp: Date(),
//                notes: "공복 상태에서 측정"
//            )
//
//            let savedOutcome = try await manager.saveBloodGlucose(reading)
//            print("Saved reading: \(reading.value) \(reading.unit)")
//
//            // 3. Fetch recent readings
//            let endDate = Date()
//            let startDate =
//                Calendar.current.date(byAdding: .day, value: -7, to: endDate)
//                ?? endDate
//            let recentReadings = try await manager.fetchBloodGlucoseReadings(
//                from: startDate,
//                to: endDate
//            )
//
//            print("Found \(recentReadings.count) readings in the last 7 days")
//
//            // 4. Convert to FHIR format
//            let fhirObservations = try await manager.exportToFHIR()
//            print("Exported \(fhirObservations.count) FHIR observations")
//
//        } catch {
//            print("Error: \(error.localizedDescription)")
//        }
//    }
//}
