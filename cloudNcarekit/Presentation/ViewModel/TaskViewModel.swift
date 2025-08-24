//
//  TaskViewModel.swift
//  cloudNcarekit
//
//  Created by Ken on 8/21/25.
//

import CareKitStore
import Foundation
import os

@MainActor
class TaskViewModel: ObservableObject {
    @Published var tasks: [OCKAnyTask] = []
    private let repository: CarekitStoreRepository
    private var currentCarePlanUUID: UUID?

    init(repository: CarekitStoreRepository) {
        self.repository = repository
        self.tasks = []
    }

    ///
    func fetchTasks() async throws {
        do {
            let fetched = try await repository.fetchTasks()
            self.tasks = fetched
            print("tasks: \(fetched)")
        } catch {
            print("Error fetching tasks: \(error)")
        }
    }
    
    func fetchTasks(for carePlanUUID: UUID) async throws {
        do {
            self.currentCarePlanUUID = carePlanUUID
            let fetched = try await repository.fetchTasks(for: carePlanUUID)
            self.tasks = fetched
            print("tasks for care plan \(carePlanUUID): \(fetched)")
        } catch {
            print("Error fetching tasks: \(error)")
        }
    }

    ///
    func addTask(_ task: OCKTask) async {
        do {
            print("Adding task: \(task.title ?? "no title") with care plan UUID: \(task.carePlanUUID)")
            let addedTask = try await repository.addTask(task)
            print("Task added successfully: \(addedTask.id)")
            if let carePlanUUID = currentCarePlanUUID {
                try await fetchTasks(for: carePlanUUID)
            } else {
                try await fetchTasks()
            }
        } catch {
            print("Error adding task: \(error)")
        }
    }

    ///
    func updateTask(_ task: OCKTask) async {
        do {
            let _ = try await repository.updateTask(task)
            try await fetchTasks()
        } catch {
            print("Error updating task: \(error)")
        }
    }

    ///
    func deleteTask(_ task: OCKTask) async {
        do {
            try await repository.deleteTask(task)
            try await fetchTasks()
        } catch {
            print("Error deleting task: \(error)")
        }
    }
}
