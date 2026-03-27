import Charts
import SwiftUI

struct StatsSettingsView: View {
    let statsService: StatsService

    @State private var panelOpens = 0
    @State private var pastes = 0
    @State private var searches = 0
    @State private var copies = 0
    @State private var firstDate: Date?
    @State private var dailySeries: [DailySeries] = []
    @State private var refreshTimer: Timer?
    @State private var selectedDate: Date?

    struct DailySeries: Identifiable {
        let id: String
        let color: Color
        let data: [(date: Date, count: Int)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            Divider()
            countersGrid
            Divider()
            chartSection
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refresh()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                DispatchQueue.main.async { refresh() }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("ClipMoar Stats")
                    .font(.system(size: 18, weight: .semibold))
                if let firstDate {
                    Text("Using since \(firstDate, format: .dateTime.month(.wide).year())")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var countersGrid: some View {
        HStack(spacing: 8) {
            counterCard(title: "Opens", value: panelOpens, color: .blue, tooltip: "Panel opened via hotkey")
            counterCard(title: "Pastes", value: pastes, color: .purple, tooltip: "Items pasted from panel")
            counterCard(title: "Copies", value: copies, color: .orange, tooltip: "Clipboard items captured")
            counterCard(title: "Searches", value: searches, color: .pink, tooltip: "Search queries in panel")
        }
    }

    private func counterCard(title: String, value: Int, color: Color, tooltip: String) -> some View {
        CounterCardView(title: title, value: value, color: color, tooltip: tooltip)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 14 days")
                .font(.system(size: 13, weight: .semibold))

            Chart {
                ForEach(dailySeries) { series in
                    ForEach(series.data, id: \.date) { entry in
                        AreaMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Count", entry.count)
                        )
                        .foregroundStyle(by: .value("Type", series.id))
                        .interpolationMethod(.catmullRom)
                        .opacity(0.15)

                        LineMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Count", entry.count)
                        )
                        .foregroundStyle(by: .value("Type", series.id))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                    }
                }

                if let selectedDate {
                    RuleMark(x: .value("Date", selectedDate, unit: .day))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartForegroundStyleScale([
                "Opens": Color.blue,
                "Pastes": Color.purple,
                "Copies": Color.orange,
                "Searches": Color.pink,
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartLegend(position: .bottom)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if let selectedDate {
                    chartTooltip(for: selectedDate)
                        .padding(.leading, 8)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func chartTooltip(for date: Date) -> some View {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let items = dailySeries.compactMap { series -> (String, Int, Color)? in
            guard let entry = series.data.first(where: { calendar.isDate($0.date, inSameDayAs: day) }),
                  entry.count > 0 else { return nil }
            return (series.id, entry.count, series.color)
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(day, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 10, weight: .semibold))
            ForEach(items, id: \.0) { name, count, color in
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text("\(name): \(count)")
                        .font(.system(size: 10))
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color(.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
    }

    private func refresh() {
        panelOpens = statsService.totalCount(for: .panelOpen)
        pastes = statsService.totalCount(for: .paste)
        searches = statsService.totalCount(for: .search)
        copies = statsService.totalCount(for: .copy)
        firstDate = statsService.firstEventDate()
        dailySeries = [
            DailySeries(id: "Opens", color: .blue, data: statsService.dailyCounts(for: .panelOpen)),
            DailySeries(id: "Pastes", color: .purple, data: statsService.dailyCounts(for: .paste)),
            DailySeries(id: "Copies", color: .orange, data: statsService.dailyCounts(for: .copy)),
            DailySeries(id: "Searches", color: .pink, data: statsService.dailyCounts(for: .search)),
        ]
    }
}

private struct CounterCardView: View {
    let title: String
    let value: Int
    let color: Color
    let tooltip: String

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(isHovered ? 0.15 : 0.08)))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .overlay(alignment: .top) {
            if isHovered {
                Text(tooltip)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(.darkGray)))
                    .fixedSize()
                    .offset(y: 58)
                    .zIndex(1)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
