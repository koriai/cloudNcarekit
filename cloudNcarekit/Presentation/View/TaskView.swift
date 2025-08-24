//
//  TaskView.swift
//  cloudNcarekit
//
//  Created by Ken on 8/21/25.
//

import CareKit
import CareKitStore
import SwiftUI

struct TaskView: View {

    private let repository: CarekitStoreRepository
    @StateObject private var viewModel: TaskViewModel
    @State private var showAddTaskSheet: Bool = false

    var careplan: OCKCarePlan

    init(repository: CarekitStoreRepository, careplan: OCKCarePlan) {
        self.repository = repository
        _viewModel = .init(wrappedValue: .init(repository: repository))
        self.careplan = careplan
    }

    var body: some View {
        VStack {
            Text(careplan.title)
                .font(.headline)
                .padding()

        }.toolbar {
            ToolbarItem(content: {
                Button(action: {
                    showAddTaskSheet = true
                }) { Image(systemName: "plus") }
            })
        }.sheet(isPresented: $showAddTaskSheet, content: {
            VStack {
                
            }
        })
    }
}
