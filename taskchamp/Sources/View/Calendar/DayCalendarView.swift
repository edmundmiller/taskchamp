import SwiftUI
import taskchampShared

struct DayCalendarView: View {
    @Binding var selectedDate: Date
    let tasks: [TCTask]
    @Binding var selectedTask: TCTask?
    @Binding var draggedTask: TCTask?
    let onTaskMoved: (TCTask, Date) -> Void

    private let hourHeight: CGFloat = 60
    private let hours = Array(0 ... 23)

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            hourRow(hour: hour, width: geometry.size.width)
                        }
                    }
                }
                .onAppear {
                    // Scroll to current time
                    let currentHour = Calendar.current.component(.hour, from: Date())
                    proxy.scrollTo(currentHour, anchor: .center)
                }
                .onChange(of: selectedDate) {
                    let currentHour = Calendar.current.component(.hour, from: Date())
                    proxy.scrollTo(currentHour, anchor: .center)
                }
            }
        }
    }

    private func hourRow(hour: Int, width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Time label
            timeLabel(hour: hour)
                .frame(width: 60)

            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)

            // Task area
            taskArea(hour: hour, width: width - 61)
        }
        .frame(height: hourHeight)
        .id(hour)
    }

    private func timeLabel(hour: Int) -> some View {
        VStack {
            Text(formatHour(hour))
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 4)
        .padding(.trailing, 8)
    }

    private func taskArea(hour: Int, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Background with grid lines
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: hourHeight)
                    .overlay(
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 1),
                        alignment: .bottom
                    )
            }

            // Current time indicator
            if Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                currentTimeIndicator(hour: hour, width: width)
            }

            // Tasks for this hour
            ForEach(tasksForHour(hour), id: \.uuid) { task in
                taskCard(task: task, width: width)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let taskId = items.first,
                  let draggedTask = draggedTask,
                  draggedTask.uuid == taskId else { return false }

            let newDate = dateForHour(hour)
            onTaskMoved(draggedTask, newDate)
            return true
        }
    }

    private func currentTimeIndicator(hour: Int, width _: CGFloat) -> some View {
        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)
        let currentMinute = Calendar.current.component(.minute, from: now)

        if currentHour == hour {
            let offset = (CGFloat(currentMinute) / 60.0) * hourHeight
            return AnyView(
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 2)
                    Spacer()
                }
                .offset(y: offset)
            )
        }
        return AnyView(EmptyView())
    }

    private func taskCard(task: TCTask, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(priorityColor(task.priority))
                    .frame(width: 8, height: 8)

                Text(task.description)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Spacer()

                if task.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                }
            }

            if let project = task.project, !project.isEmpty {
                Text(project)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let due = task.due {
                Text(formatTaskTime(due))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                .stroke(task.isCompleted ? Color.green : Color.blue, lineWidth: 1)
        )
        .frame(width: width - 16)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
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

    private func tasksForHour(_ hour: Int) -> [TCTask] {
        return tasks.filter { task in
            guard let due = task.due else { return false }
            let taskHour = Calendar.current.component(.hour, from: due)
            return Calendar.current.isDate(due, inSameDayAs: selectedDate) && taskHour == hour
        }
    }

    private func dateForHour(_ hour: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? selectedDate
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private func formatTaskTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
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
}

#Preview {
    DayCalendarView(
        selectedDate: .constant(Date()),
        tasks: [
            TCTask(
                uuid: "1",
                description: "Morning standup",
                status: .pending,
                priority: .high,
                due: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
            ),
            TCTask(
                uuid: "2",
                description: "Review pull requests",
                status: .pending,
                priority: .medium,
                due: Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date())
            ),
            TCTask(
                uuid: "3",
                description: "Lunch meeting",
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
