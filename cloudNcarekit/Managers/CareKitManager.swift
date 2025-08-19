import CareKit  // CareKit: 헬스케어 앱에서 '활동(Task)'과 '결과(Outcome)'를 관리하는 UI/로직 프레임워크
import CareKitStore  // CareKitStore: CareKit의 데이터 저장소. Task, Outcome 등을 저장/조회 가능
import CloudKit
internal import Combine
import CoreData
import Foundation  // Swift 기본 기능 제공

/// Core Data + CloudKit 자동 동기화를 위한 OCKStore 서브클래스
final class CloudKitOCKStore: OCKStore {
    let cloudContainer: NSPersistentCloudKitContainer

    init(name: String, container: NSPersistentCloudKitContainer) {
        self.cloudContainer = container
        super.init(name: name)
    }

    /// OCKStore 내부 메서드에서 context 접근 시 CloudKit 컨테이너 사용
    var context: NSManagedObjectContext {
        cloudContainer.viewContext
    }
}

// CareKit 데이터와 상호작용하는 매니저 클래스
// 앱 전역에서 하나만 존재하도록 Singleton 패턴 사용 (shared 인스턴스)
class CareKitManager: ObservableObject {
    enum StoreMode {
        case remote
        case coreData
    }

    static private(set) var shared: CareKitManager!

    static func configure(mode: StoreMode) {
        shared = CareKitManager(mode: mode)
    }

    var store: OCKStore  // CareKit의 핵심 데이터베이스 역할
    let ockRemote: OCKRemoteSynchronizable?
    let nsContainer: NSPersistentCloudKitContainer?
    let mode: StoreMode

    // 생성자: OCKStore 초기화 및 기본 Task 등록
    private init(mode: StoreMode = .remote) {
        self.mode = mode

        switch mode {
        case .remote:
            ockRemote = CloudKitRemote(
                containerIdentifier: myContainerIdentifier
            )
            store = OCKStore(name: "BloodGlucoseStore", remote: ockRemote)
            nsContainer = nil
        case .coreData:
            ockRemote = nil
            let container = PersistenceController.shared.container
            nsContainer = container
            store = CloudKitOCKStore(
                name: "BloodGlucoseStore",
                container: container
            )
        }

        setupTasks()  // 앱 실행 시 기본 Task(혈당 측정) 생성
    }

    // 앱 시작 시 Task 생성 작업 실행
    private func setupTasks() {
        // Swift Concurrency를 사용해 비동기 작업 실행
        Task {
            await createBloodGlucoseTask()
        }
    }

    // '혈당 측정' Task를 CareKit에 등록하는 메서드
    private func createBloodGlucoseTask() async {
        // OCKTask: 사용자가 해야 하는 활동 정의
        let bloodGlucoseTask = OCKTask(
            id: "BloodGlucoseStore",  // Task 식별자
            title: "혈당 측정",  // UI에 표시될 제목
            carePlanUUID: nil,  // UUID(uuidString: Date().description),  // Care Plan(관리 계획)에 연결할 경우 UUID 필요
            schedule: OCKSchedule.dailyAtTime(  // 매일 특정 시간에 반복되는 스케줄 생성
                hour: 8,
                minutes: 0,
                start: Date(),  // 오늘부터 시작
                end: nil,  // 종료일 없음
                text: "혈당을 기록하세요"  // Task 설명
            )
        )

        do {
            // Task를 데이터베이스에 추가
            _ = try await store.addTask(bloodGlucoseTask)
        } catch {
            // 이미 존재하는 Task라면 추가하지 않음
            if error.localizedDescription.contains("already exists")
                || error.localizedDescription.contains("duplicate")
            {
                return
            }
            print("Failed to add blood glucose task: \(error)")
        }
    }

    ///
    func saveBloodGlucoseOutcome(value: Double, date: Date = Date())
        async throws
    {
        let taskUUID = try await getTaskUUID(for: "BloodGlucoseStore")

        // 오늘 날짜 TaskOccurrenceIndex 계산
        let taskOccurrenceIndex = 0  // 단순 예시: 하루 첫 번째
        let existingOutcomes = try await store.fetchOutcomes(
            query: OCKOutcomeQuery(for: Date())
        ).filter {
            $0.taskUUID == taskUUID
                && $0.taskOccurrenceIndex == taskOccurrenceIndex
        }

        if let existing = existingOutcomes.first {
            // 이미 존재하면 업데이트
            var updatedOutcome = existing
            updatedOutcome.values = [OCKOutcomeValue(value, units: "mg/dL")]
            try await store.updateOutcome(updatedOutcome)
        } else {
            // 존재하지 않으면 새로 추가
            let outcome = OCKOutcome(
                taskUUID: taskUUID,
                taskOccurrenceIndex: taskOccurrenceIndex,
                values: [OCKOutcomeValue(value, units: "mg/dL")]
            )
            try await store.addOutcome(outcome)

            if let context = nsContainer?.viewContext {
                _ = BloodGlucose.from(outcome: outcome, context: context)
                try context.save()
            }
        }
    }

    // Task의 UUID를 조회하는 헬퍼 메서드
    private func getTaskUUID(for taskID: String) async throws -> UUID {
        var query = OCKTaskQuery()
        query.ids = [taskID]  // 날짜 조건 제거

        let tasks = try await store.fetchTasks(query: query)
        guard let task = tasks.first else {
            throw CareKitError.taskNotFound
        }
        return task.uuid
    }

    // 특정 기간(startDate ~ endDate)의 혈당 측정 결과를 가져오기
    func fetchBloodGlucoseOutcomes(from startDate: Date, to endDate: Date)
        async throws -> [OCKOutcome]
    {
        // Outcome 검색 조건 생성 (기간 지정)
        let query = OCKOutcomeQuery(
            dateInterval: DateInterval(start: startDate, end: endDate)
        )

        // Outcome 목록 반환
        return try await store.fetchOutcomes(query: query)
    }
}

// CareKit 관련 에러 정의
enum CareKitError: Error, LocalizedError {
    case taskNotFound  // Task를 찾지 못한 경우
    case invalidOutcome  // 잘못된 Outcome 데이터

    var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Task not found"
        case .invalidOutcome:
            return "Invalid outcome data"
        }
    }
}
