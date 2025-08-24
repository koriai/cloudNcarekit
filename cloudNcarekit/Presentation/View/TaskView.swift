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
            List {
                ForEach(viewModel.tasks, id: \.uuid) { task in

                    RectangularCompletionView(
                        isComplete: false,
                        content: {
                            Text(task.id)
                            Text(task.title ?? "task title")
                                .font(.headline)
                                .padding()
                        }
                    )
                }.onDelete { indexSet in
                    if let index = indexSet.first {
                        let task = viewModel.tasks[index]
                        Task {
                            if let ockTask = task as? OCKTask {
                                await viewModel.deleteTask(ockTask)
                            }
                        }
                    }
                }
            }

        }.task {
            do {
                try await viewModel.fetchTasks(for: careplan.uuid)
            } catch {
                print("Failed to fetch tasks: \(error)")
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
                            print("Creating task with title: \(taskTitle)")
                            print("Care plan UUID: \(careplan.uuid)")
                            print("Care plan ID: \(careplan.id)")

                            let task = OCKTask(
                                id: UUID().uuidString,
                                title: taskTitle,
                                carePlanUUID: careplan.uuid,
                                schedule: .dailyAtTime(
                                    hour: 8,
                                    minutes: 0,
                                    start: Date(),
                                    end: nil,
                                    text: taskTitle
                                )
                            )

                            print("Task created: \(task.id)")
                            print("Task care plan UUID: \(task.carePlanUUID)")

                            await viewModel.addTask(task)
                            try await viewModel.fetchTasks(for: careplan.uuid)
                            showAddTaskSheet = false
                        }
                    }
                }
            }
        )
    }
}
