import CareKit
import CareKitStore
import Foundation

final class CarekitStoreRepository: ObservableObject {
    @Published var store: OCKStore?

    init(store: OCKStore?) {
        self.store = store
    }

    func setupStore() {
        let store = OCKStore(
            name: "cloudNcarekit",
            type: .onDisk(),
            remote:
                CloudKitRemote(
                    container: .init(
                        identifier: "iCloud.com.koriai.cloudNcarekit"
                    ),
                    scope: .public
                ),

        )

        self.store = store
    }

    // MARK: - Patient Operations
    func fetchPatient(withId patientId: String) async throws -> OCKPatient? {
        try await withCheckedThrowingContinuation { continuation in
            store?.fetchPatients { result in
                switch result {
                case .success(let patients):
                    continuation.resume(
                        returning: patients.first(where: { $0.id == patientId })
                    )
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchAnyPatient() async throws -> OCKPatient? {
        try await withCheckedThrowingContinuation { continuation in
            store?.fetchPatients { result in
                switch result {
                case .success(let patients):
                    continuation.resume(returning: patients.first)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func savePatient(anyPatient: OCKAnyPatient) async throws -> OCKPatient {
        let patient = OCKPatient(
            id: anyPatient.id,
            givenName: anyPatient.name.givenName ?? "default",
            familyName: anyPatient.name.familyName ?? "name"
        )

        return try await withCheckedThrowingContinuation { continuation in
            store?.addPatient(patient) { result in
                switch result {
                case .success(let savedPatient):
                    continuation.resume(returning: savedPatient)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deletePatient(patient: OCKPatient) async throws {
        try await withCheckedThrowingContinuation { continuation in
            store?.deletePatients([patient]) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - CarePlan Operations

    func fetchCareplans() async throws -> [OCKCarePlan] {
        try await withCheckedThrowingContinuation { continuation in
            store?.fetchCarePlans(query: .init(for: .now)) { result in
                switch result {
                case .success(let plans):
                    print(plans)
                    continuation.resume(returning: plans)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func addCarePlan(_ careplan: OCKCarePlan) async throws -> OCKCarePlan {
        try await withCheckedThrowingContinuation { continuation in
            store?.addCarePlan(careplan) { result in
                switch result {
                case .success(let plan):
                    print("careplan saved: \(plan)")
                    continuation.resume(returning: plan)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateCarePlan(_ careplan: OCKCarePlan) async throws -> OCKCarePlan {
        try await withCheckedThrowingContinuation { continuation in
            store?.updateCarePlan(careplan) { result in
                switch result {
                case .success(let plan):
                    continuation.resume(returning: plan)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteCarePlan(_ careplan: OCKCarePlan) async throws {
        try await withCheckedThrowingContinuation { continuation in
            store?.deleteCarePlan(careplan) { result in
                switch result {
                case .success(let plan):
                    continuation.resume(returning: plan)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Task Operations

    func fetchTasks() async throws -> [OCKTask] {
        try await withCheckedThrowingContinuation { continuation in
            let query = OCKTaskQuery(for: .now)
            store?.fetchTasks(query: query) { result in
                switch result {
                case .success(let tasks):
                    print("Fetched \(tasks.count) tasks")
                    continuation.resume(returning: tasks)
                case .failure(let error):
                    print("Error fetching tasks: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchTasks(for carePlanUUID: UUID) async throws -> [OCKTask] {
        try await withCheckedThrowingContinuation { continuation in
            let query = OCKTaskQuery(for: .now)
//            query.carePlanIDs = [carePlanUUID.uuidString]
            store?.fetchTasks(query: query) { result in
                switch result {
                case .success(let tasks):
                    print("Fetched \(tasks.count) tasks for care plan \(carePlanUUID)")
                    continuation.resume(returning: tasks)
                case .failure(let error):
                    print("Error fetching tasks for care plan: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func addTask(_ task: OCKTask) async throws -> OCKTask {
        try await withCheckedThrowingContinuation { continuation in
            store?.addTask(task) { result in
                switch result {
                case .success(let added):
                    continuation.resume(returning: added)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateTask(_ task: OCKTask) async throws -> OCKTask {
        try await withCheckedThrowingContinuation { continuation in
            store?.updateTask(task) { result in
                switch result {
                case .success(let updated):
                    continuation.resume(returning: updated)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteTask(_ task: OCKTask) async throws {
        guard let store = self.store else {
            throw OCKStoreError.remoteSynchronizationFailed(reason: "")
        }
        _ = try await store.deleteTask(task)
    }
}
