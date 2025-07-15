import SwiftUI
import taskchampShared

public struct CalendarView: View {
    @Environment(PathStore.self) var pathStore: PathStore
    @Binding var selectedFilter: TCFilter
    @State private var tasks: [TCTask] = []
    @State private var selectedDate = Date()
    @State private var calendarMode: CalendarMode = .week
    @State private var isShowingCreateTaskView = false
    @State private var selectedTask: TCTask?
    @State private var draggedTask: TCTask?

    public enum CalendarMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var icon: String {
            switch self {
            case .day: return "calendar.day.timeline.left"
            case .week: return "calendar"
            case .month: return "calendar.month"
            }
        }
    }

    public init(selectedFilter: Binding<TCFilter>) {
        _selectedFilter = selectedFilter
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar mode picker
                calendarModeHeader

                // Calendar content
                Group {
                    switch calendarMode {
                    case .day:
                        DayCalendarView(
                            selectedDate: $selectedDate,
                            tasks: tasks,
                            selectedTask: $selectedTask,
                            draggedTask: $draggedTask,
                            onTaskMoved: handleTaskMoved
                        )
                    case .week:
                        WeekCalendarView(
                            selectedDate: $selectedDate,
                            tasks: tasks,
                            selectedTask: $selectedTask,
                            draggedTask: $draggedTask,
                            onTaskMoved: handleTaskMoved
                        )
                    case .month:
                        MonthCalendarView(
                            selectedDate: $selectedDate,
                            tasks: tasks,
                            selectedTask: $selectedTask,
                            onTaskTapped: { task in
                                selectedTask = task
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Today") {
                        withAnimation {
                            selectedDate = Date()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isShowingCreateTaskView = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingCreateTaskView) {
                CreateTaskView()
                    .onDisappear {
                        updateTasks()
                    }
            }
            .sheet(item: $selectedTask) { task in
                NavigationView {
                    EditTaskView(task: task)
                        .onDisappear {
                            updateTasks()
                        }
                }
            }
            .onAppear {
                updateTasks()
            }
            .onChange(of: selectedFilter) {
                updateTasks()
            }
        }
    }

    private var calendarModeHeader: some View {
        HStack {
            // Mode picker
            Picker("Calendar Mode", selection: $calendarMode) {
                ForEach(CalendarMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            Spacer()

            // Date navigation
            HStack {
                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(
                            byAdding: calendarMode == .day ? .day : calendarMode == .week ? .weekOfYear : .month,
                            value: -1,
                            to: selectedDate
                        ) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }

                Text(dateHeaderText)
                    .font(.headline)
                    .frame(minWidth: 120)

                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(
                            byAdding: calendarMode == .day ? .day : calendarMode == .week ? .weekOfYear : .month,
                            value: 1,
                            to: selectedDate
                        ) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var dateHeaderText: String {
        let formatter = DateFormatter()
        switch calendarMode {
        case .day:
            formatter.dateFormat = "EEEE, MMM d"
        case .week:
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? selectedDate
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter.string(from: selectedDate)
    }

    private func updateTasks() {
        Task {
            do {
                let dbService = try DBService()
                let filteredTasks = try await dbService.getTasks(filters: selectedFilter.convertToSqlFilters())
                await MainActor.run {
                    self.tasks = filteredTasks.filter { !$0.isDeleted }
                }
            } catch {
                print("Error updating tasks: \(error)")
            }
        }
    }

    private func handleTaskMoved(task: TCTask, to newDate: Date) {
        Task {
            do {
                let dbService = try DBService()
                var updatedTask = task
                updatedTask.due = newDate

                // Update the task in the database
                try await dbService.updateTask(updatedTask)

                // Refresh the tasks
                await MainActor.run {
                    updateTasks()
                }
            } catch {
                print("Error moving task: \(error)")
            }
        }
    }
}

#Preview {
    CalendarView(selectedFilter: .constant(.defaultFilter))
}
