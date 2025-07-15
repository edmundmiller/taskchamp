import SwiftUI
import taskchampShared

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let tasks: [TCTask]
    @Binding var selectedTask: TCTask?
    @Binding var draggedTask: TCTask?
    let onTaskMoved: (TCTask, Date) -> Void

    private let dayHeight: CGFloat = 80
    private let calendar = Calendar.current

    var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }

        var days: [Date] = []
        var currentDate = weekInterval.start

        for _ in 0..<7 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 1) {
                    // Week header
                    weekHeader(width: geometry.size.width)

                    // Week grid
                    weekGrid(width: geometry.size.width)
                }
            }
        }
    }

    private func weekHeader(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Time column placeholder
            Rectangle()
                .fill(Color.clear)
                .frame(width: 60, height: 40)

            // Day headers
            ForEach(weekDays, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(dayFormatter.string(from: day))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(dateFormatter.string(from: day))
                        .font(.title3)
                        .fontWeight(calendar.isDateInToday(day) ? .bold : .medium)
                        .foregroundColor(calendar.isDateInToday(day) ? .blue : .primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(calendar.isDateInToday(day) ? Color.blue.opacity(0.1) : Color.clear)
                )
            }
        }
        .background(Color(.systemGray6))
    }

    private func weekGrid(width: CGFloat) -> some View {
        let columnWidth = (width - 60) / 7

        return VStack(spacing: 0) {
            ForEach(Array(6...23), id: \.self) { hour in
                HStack(spacing: 0) {
                    // Time label
                    timeLabel(hour: hour)
                        .frame(width: 60)

                    // Day columns
                    ForEach(weekDays, id: \.self) { day in
                        dayColumn(day: day, hour: hour, width: columnWidth)
                    }
                }
                .frame(height: dayHeight)
            }
        }
    }

    private func timeLabel(hour: Int) -> some View {
        VStack {
            Text(formatHour(hour))
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 4)
        .padding(.trailing, 8)
    }

    private func dayColumn(day: Date, hour: Int, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Background
            Rectangle()
                .fill(Color.clear)
                .frame(width: width, height: dayHeight)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 1),
                    alignment: .bottom
                )
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 1),
                    alignment: .trailing
                )

            // Current time indicator
            if calendar.isDateInToday(day) {
                currentTimeIndicator(hour: hour, width: width)
            }

            // Tasks for this day and hour
            LazyVStack(spacing: 2) {
                ForEach(tasksForDayAndHour(day: day, hour: hour), id: \.uuid) { task in
                    taskCard(task: task, width: width)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let taskId = items.first,
                  let draggedTask = draggedTask,
                  draggedTask.uuid == taskId else { return false }

            let newDate = dateForDayAndHour(day: day, hour: hour)
            onTaskMoved(draggedTask, newDate)
            return true
        }
    }

    private func currentTimeIndicator(hour: Int, width: CGFloat) -> some View {
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        if currentHour == hour {
            let offset = (CGFloat(currentMinute) / 60.0) * dayHeight
            return AnyView(
                Rectangle()
                    .fill(Color.red)
                    .frame(width: width - 4, height: 2)
                    .offset(y: offset)
                    .padding(.horizontal, 2)
            )
        }
        return AnyView(EmptyView())
    }

    private func taskCard(task: TCTask, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(priorityColor(task.priority))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.description)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let project = task.project, !project.isEmpty {
                    Text(project)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                .stroke(task.isCompleted ? Color.green : Color.blue, lineWidth: 0.5)
        )
        .frame(width: width - 4)
        .draggable(task.uuid) {
            Text(task.description)
                .padding(4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
        }
        .onTapGesture {
            selectedTask = task
        }
        .onDrag {
            draggedTask = task
            return NSItemProvider(object: task.uuid as NSString)
        }
    }

    private func tasksForDayAndHour(day: Date, hour: Int) -> [TCTask] {
        return tasks.filter { task in
            guard let due = task.due else { return false }
            let taskHour = calendar.component(.hour, from: due)
            return calendar.isDate(due, inSameDayAs: day) && taskHour == hour
        }
    }

    private func dateForDayAndHour(day: Date, hour: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? day
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private func priorityColor(_ priority: TCTask.Priority?) -> Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .yellow
        default:
            return .gray
        }
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
}

#Preview {
    WeekCalendarView(
        selectedDate: .constant(Date()),
        tasks: [
            TCTask(
                uuid: "1",
                description: "Morning standup meeting with team",
                status: .pending,
                priority: .high,
                due: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
            ),
            TCTask(
                uuid: "2",
                description: "Code review session",
                status: .pending,
                priority: .medium,
                due: Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date())
            ),
            TCTask(
                uuid: "3",
                description: "Lunch with client",
                status: .completed,
                priority: .low,
                due: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())
            )
        ],
        selectedTask: .constant(nil),
        draggedTask: .constant(nil),
        onTaskMoved: { _, _ in }
    )
}
