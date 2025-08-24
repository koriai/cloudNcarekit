//
//  TaskViewModel.swift
//  cloudNcarekit
//
//  Created by Ken on 8/21/25.
//

import CareKitStore
import Foundation
import os

class TaskViewModel: ObservableObject {
    @Published var tasks: [OCKAnyTask] = []
    private let repository: CarekitStoreRepository

    init(repository: CarekitStoreRepository) {
        self.repository = repository
        self.tasks = []
    }

    ///
    func fetchTasks() async {
        do {
            self.tasks = try await repository.fetchTasks()
        } catch {
            print("Error fetching tasks: \(error)")
        }
    }

    ///
    func addTask(_ task: OCKTask) async {
        do {
            let _ = try await repository.addTask(task)
            await fetchTasks()
        } catch {
            print("Error adding task: \(error)")
        }
    }

    ///
    func updateTask(_ task: OCKTask) async {
        do {
            let _ = try await repository.updateTask(task)
            await fetchTasks()
        } catch {
            print("Error updating task: \(error)")
        }
    }

    ///
    func deleteTask(_ task: OCKTask) async {
        do {
            try await repository.deleteTask(task)
            await fetchTasks()
        } catch {
            print("Error deleting task: \(error)")
        }
    }
}
