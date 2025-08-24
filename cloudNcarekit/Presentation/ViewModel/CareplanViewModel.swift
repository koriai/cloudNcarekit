//
//  CareplanViewModel.swift
//  cloudNcarekit
//
//  Created by Ken on 8/21/25.
//

import CareKitStore
import Foundation

@MainActor
class CareplanViewModel: ObservableObject {
    @Published var patient: OCKAnyPatient?
    @Published var careplans: [OCKAnyCarePlan] = []
    private let repository: CarekitStoreRepository

    init(repository: CarekitStoreRepository) {
        self.repository = repository
        self.patient = nil
        self.careplans = []
    }

    ///
    func setupStore() {
        repository.setupStore()
    }

    ///
    func fetchCareplans() async throws {
        do {
            let fetched = try await repository.fetchCareplans()
            self.careplans = fetched
            print("careplans: \(fetched)")
        } catch {
            print("Error fetching careplans: \(error)")
        }
    }

    ///
    func addCareplan(_ careplan: OCKCarePlan) async {
        do {
            let _ = try await repository.addCarePlan(careplan)
            try await fetchCareplans()
        } catch {
            print("Error adding careplan: \(error)")
        }
    }

    ///
    func updateCarePlan(_ careplan: OCKCarePlan) async {
        do {
            let _ = try await repository.updateCarePlan(careplan)
            try await fetchCareplans()
        } catch {
            print("Error updating careplan: \(error)")
        }
    }
}
