import Charts
import SwiftUI

struct StatsSettingsView: View {
    let statsService: StatsService

    @State private var launches = 0
    @State private var panelOpens = 0
    @State private var pastes = 0
    @State private var searches = 0
    @State private var copies = 0
    @State private var firstDate: Date?
    @State private var dailyPastes: [(date: Date, count: Int)] = []
    @State private var dailyCopies: [(date: Date, count: Int)] = []
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            Divider()
            countersGrid
            Divider()
            chartSection
            Divider()
            resetSection
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
            counterCard(title: "Launches", value: launches, color: .green, tooltip: "App started")
            counterCard(title: "Opens", value: panelOpens, color: .blue, tooltip: "Panel opened via hotkey")
            counterCard(title: "Pastes", value: pastes, color: .purple, tooltip: "Items pasted from panel")
            counterCard(title: "Copies", value: copies, color: .orange, tooltip: "Clipboard items captured")
            counterCard(title: "Searches", value: searches, color: .pink, tooltip: "Search queries in panel")
        }
    }

    private func counterCard(title: String, value: Int, color: Color, tooltip: String) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.08)))
        .help(tooltip)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 14 days")
                .font(.system(size: 13, weight: .semibold))

            Chart {
                ForEach(dailyPastes, id: \.date) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Count", entry.count)
                    )
                    .foregroundStyle(Color.purple.gradient)
                    .cornerRadius(3)
                }
                ForEach(dailyCopies, id: \.date) { entry in
                    LineMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Count", entry.count)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartLegend(position: .bottom) {
                HStack(spacing: 16) {
                    Label("Pastes", systemImage: "square.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    Label("Copies", systemImage: "line.diagonal")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }
            .frame(height: 180)
        }
    }

    private var resetSection: some View {
        HStack {
            Spacer()
            Button("Reset Stats") {
                statsService.resetAll()
                refresh()
            }
            .controlSize(.small)
        }
    }

    private func refresh() {
        launches = statsService.totalCount(for: .launch)
        panelOpens = statsService.totalCount(for: .panelOpen)
        pastes = statsService.totalCount(for: .paste)
        searches = statsService.totalCount(for: .search)
        copies = statsService.totalCount(for: .copy)
        firstDate = statsService.firstEventDate()
        dailyPastes = statsService.dailyCounts(for: .paste)
        dailyCopies = statsService.dailyCounts(for: .copy)
    }
}
