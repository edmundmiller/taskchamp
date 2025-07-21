import SwiftUI
import taskchampShared

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    let tasks: [TCTask]
    @Binding var selectedTask: TCTask?
    let onTaskTapped: (TCTask) -> Void

    private let calendar = Calendar.current
    private let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 7)

    var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else {
            return []
        }

        var days: [Date] = []
        var currentDate = monthInterval.start

        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }

    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(0 ..< 7) { index in
                    Text(weekdayName(index: index))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
            .background(Color(.systemGray6))

            // Month grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(monthDates, id: \ .self) { date in
                        dayCell(date: date)
                    }
                }
            }
        }
    }

    private func dayCell(date: Date) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)

        return ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(isCurrentMonth ? Color.white : Color(.systemGray6))
                .frame(height: 60)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 1),
                    alignment: .top
                )
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 1),
                    alignment: .trailing
                )

            VStack(spacing: 4) {
                Text(String(calendar.component(.day, from: date)))
                    .font(.footnote)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(isToday ? .blue : .primary)

                taskDots(for: date)
            }
        }
        .onTapGesture {
            if let task = tasksForDay(date: date).first {
                selectedTask = task
                onTaskTapped(task)
            }
        }
    }

    private func taskDots(for date: Date) -> some View {
        HStack(spacing: 2) {
            ForEach(tasksForDay(date: date), id: \.uuid) { task in
                Circle()
                    .fill(priorityColor(task.priority))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func tasksForDay(date: Date) -> [TCTask] {
        return tasks.filter { task in
            guard let due = task.due else { return false }
            return calendar.isDate(due, inSameDayAs: date)
        }
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

    private func weekdayName(index: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let date = Calendar.current.date(bySetting: .weekday, value: index + 1, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

#Preview {
    MonthCalendarView(
        selectedDate: .constant(Date()),
        tasks: [
            TCTask(
                uuid: "1",
                description: "Team meeting",
                status: .pending,
                priority: .high,
                due: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())
            ),
            TCTask(
                uuid: "2",
                description: "Code review",
                status: .pending,
                priority: .medium,
                due: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())
            ),
            TCTask(
                uuid: "3",
                description: "Project deadline",
                status: .pending,
                priority: .high,
                due: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())
            )
        ],
        selectedTask: .constant(nil),
        onTaskTapped: { _ in }
    )
}
