//
//  CarePlanView.swift
//  cloudNcarekit
//
//  Created by Ken on 8/21/25.
//

import CareKit
import CareKitFHIR
import CareKitStore
import CareKitUI
import SwiftUI

struct CarePlanView: View {

    private let repository: CarekitStoreRepository
    @StateObject private var viewModel: CareplanViewModel
    @ObservedObject var patientViewModel: PatientViewModel

    @State private var careplanTitle: String = ""
    @State private var saveResult: String = ""

    init(repository: CarekitStoreRepository, patientViewModel: PatientViewModel)
    {
        self.repository = repository
        _viewModel = .init(wrappedValue: .init(repository: repository))
        self.patientViewModel = patientViewModel
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("Patient Name")
                CardView(content: {
                    VStack {
                        Text(
                            "given name:  \(String(describing: patientViewModel.patient?.name.givenName))"
                        )
                        Text(
                            "family name:  \(String(describing: patientViewModel.patient?.name.familyName))"
                        )
                    }.padding()
                })

                Text("Careplans").padding()

                TextField("Careplan Title", text: $careplanTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button("Add Careplan") {
                    Task {
                        print(patientViewModel.patient?.id ?? "nil patient")
                        await viewModel.addCareplan(
                            OCKCarePlan(
                                id: UUID().uuidString,
                                title: careplanTitle,
                                patientUUID: UUID(
                                    uuidString: patientViewModel.patient!.id
                                ),
                            )
                        )
                        try await viewModel.fetchCareplans()
                    }
                }
                Text("list of careplans")
                    .padding()

                ForEach(viewModel.careplans, id: \.id) { careplan in
                    NavigationLink(
                        destination: TaskView(
                            repository: repository,
                            careplan: careplan as! OCKCarePlan
                        )
                    ) {
                        RectangularCompletionView(
                            isComplete: false,
                            content: {
                                Text(careplan.id)
                                Text(careplan.title)
                                    .font(.headline)
                                    .padding()
                            }
                        )
                    }
                }
            }
        }.task {
            await patientViewModel.fetchAnyPatient()
            do {
                try await viewModel.fetchCareplans()
            } catch {
                print("Failed to fetch careplans: \(error)")
            }
        }

    }
}
