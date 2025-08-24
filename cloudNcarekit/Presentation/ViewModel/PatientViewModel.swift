//
//  PatientInformationViewModel.swift
//  cloudNcarekit
//
//  Created by Ken on 8/20/25.
//

import CareKitStore
import Foundation

@MainActor
class PatientViewModel: ObservableObject {
    @Published var patient: OCKAnyPatient?
    private let repository: CarekitStoreRepository

    init(repository: CarekitStoreRepository) {
        self.repository = repository
    }

    ///
    func fetchPatient(withId patientId: String) async {
        do {
            if let fetched = try await repository.fetchPatient(
                withId: patientId
            ) {
                self.patient = fetched
            }
        } catch {
            print("Error fetching patient: \(error)")
        }
    }

    ///
    func fetchAnyPatient() async {
        do {

            if let fetched = try await repository.fetchAnyPatient() {
                DispatchQueue.main.async {
                    self.patient = fetched
                }
            }
        } catch {
            print("Error fetching any patient: \(error)")
        }
    }

    ///
    func savePatient(anyPatient: OCKAnyPatient) async {
        do {
            let saved = try await repository.savePatient(anyPatient: anyPatient)
            self.patient = saved
        } catch {
            print("Error saving patient: \(error)")
        }
    }

    ///
    func deleteCurrentPatient() async {
        guard let currentPatient = self.patient as? OCKPatient else { return }
        do {
            try await repository.deletePatient(patient: currentPatient)
            self.patient = nil
        } catch {
            print("Error deleting patient: \(error)")
        }
    }
}
