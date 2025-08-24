//
//  CarePlanView.swift
//  cloudNcarekit
//
//  Created by Ken on 8/21/25.
//

import CareKit
import CareKitStore
import SwiftUI

struct PatientView: View {

    private let repository: CarekitStoreRepository
    @ObservedObject var patientViewModel: PatientViewModel

    init(repository: CarekitStoreRepository, patientViewModel: PatientViewModel)
    {
        self.repository = repository
        self.patientViewModel = patientViewModel
    }

    @State private var path = NavigationPath()

    @State private var patientId: String = ""
    @State private var givenName: String = ""
    @State private var familyName: String = ""
    @State private var saveResult: String = ""

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 16) {
                TextField("Patient ID", text: $patientId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                TextField("Given Name", text: $givenName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                TextField("Family Name", text: $familyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button("Save Patient") {
                    let anyPatient = OCKPatient(
                        id: patientId,
                        name: PersonNameComponents(
                            givenName: givenName,
                            familyName: familyName
                        )
                    )
                    Task {
                        do {
                            let saved = try await patientViewModel.savePatient(
                                anyPatient: anyPatient
                            )
                            print(saveResult)
                            path.append("careplan")
                        } catch {
                            saveResult = "Error: \(error.localizedDescription)"
                            print(saveResult)
                        }
                    }
                }
                .padding()
                .buttonStyle(.borderedProminent)

                Text(saveResult)
                    .foregroundColor(.blue)
            }.task {
                repository.setupStore()
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        Task {
                            do {
                                //                                try await repository.del.deleteOCKAnyPatient()
                            } catch {
                                print("삭제 실패: \(error)")
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .padding()
            .navigationDestination(for: String.self) { value in
                switch value {
                case "careplan":
                    CarePlanView(
                        repository: repository,
                        patientViewModel: patientViewModel
                    )
                default:
                    EmptyView()
                }
            }
        }
    }
}
