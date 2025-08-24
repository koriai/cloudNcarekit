//
//  RootView.swift
//  cloudNcarekit
//
//  Created by Ken on 8/21/25.
//

import CareKitStore
import SwiftUI

struct RootView: View {

    @StateObject private var repository: CarekitStoreRepository
    @StateObject private var viewModel: PatientViewModel
    @State private var path = NavigationPath()

    init() {
        let repo = CarekitStoreRepository(
            store: OCKStore(name: "cloudNcarekit")
        )
        _repository = StateObject(wrappedValue: repo)
        _viewModel = StateObject(
            wrappedValue: PatientViewModel(repository: repo)
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            if viewModel.patient == nil {
                PatientView(repository: repository, patientViewModel: viewModel)
            } else {
                CarePlanView(repository: repository, patientViewModel: viewModel)
            }
        }.task {
            do {
                _ = try await viewModel.fetchAnyPatient()
            } catch {
                print("Error fetching patient: \(error)")
            }
        }
    }
}
