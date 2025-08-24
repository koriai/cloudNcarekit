//
//  TaskView.swift
//  cloudNcarekit
//
//  Created by Ken on 8/21/25.
//

import CareKit
import CareKitStore
import CareKitUI
import SwiftUI

struct TaskView: View {

    private let repository: CarekitStoreRepository
    @StateObject private var viewModel: TaskViewModel
    @State private var showAddTaskSheet: Bool = false

    var careplan: OCKCarePlan

    @State private var taskTitle: String = ""

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

            ForEach(viewModel.tasks, id: \.id) { task in

                RectangularCompletionView(
                    isComplete: false,
                    content: {
                        Text(task.id)
                        Text(task.title ?? "task title")
                            .font(.headline)
                            .padding()
                    }
                )

            }

        }.task {
            do {
                try await viewModel.fetchTasks()
            } catch {
                print("Failed to fetch careplans: \(error)")
            }
        }.toolbar {
            ToolbarItem(content: {
                Button(action: {
                    showAddTaskSheet = true
                }) { Image(systemName: "plus") }
            })
        }.sheet(
            isPresented: $showAddTaskSheet,
            content: {
                VStack {

                    TextField("Task Title", text: $taskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button("Add Task") {
                        Task {
                            await viewModel.addTask(
                                OCKTask(
                                    id: UUID().uuidString,
                                    title: taskTitle,
                                    carePlanUUID: careplan.uuid,
                                    schedule: .dailyAtTime(
                                        hour: 8,
                                        minutes: 0,
                                        start: Date(),
                                        end: Date(),
                                        text: taskTitle
                                    )
                                )

                            )
                            try await viewModel.fetchTasks()
                            showAddTaskSheet = false
                        }
                    }
                }
            }
        )
    }
}
