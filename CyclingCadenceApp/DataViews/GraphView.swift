//
//  GraphView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 21/10/2024.
// GraphView.swift
// CyclingCadenceApp

import SwiftUI
import Charts

struct GraphView: View {
    let session: Session

    @State private var selectedDataTypes: Set<DataType> = [.speed]
    @State private var applyMovingAverage: Bool = false
    @State private var movingAveragePeriod: Double = 5.0

    @State private var timeWindowStart: Double
    @State private var timeWindowEnd: Double

    @State private var sessionStartTime: TimeInterval
    @State private var maxTimeValue: Double

    @StateObject private var rangeSliderViewModel: RangeSlider.ViewModel

    @State private var dataCache: [DataType: [ChartDataPoint]] = [:]

    enum DataType: String, CaseIterable, Identifiable {
        case speed = "Speed"
        case cadence = "Cadence"
        case accelerometerX = "Accel X"
        case accelerometerY = "Accel Y"
        case accelerometerZ = "Accel Z"
        case rotationRateX = "Rotation X"
        case rotationRateY = "Rotation Y"
        case rotationRateZ = "Rotation Z"

        var id: String { self.rawValue }
    }

    init(session: Session) {
        self.session = session

        if let firstTimestamp = session.data.first?.timestamp.timeIntervalSinceReferenceDate,
           let lastTimestamp = session.data.last?.timestamp.timeIntervalSinceReferenceDate {
            let totalDuration = lastTimestamp - firstTimestamp

            let initialLowerValue = totalDuration * 0.25
            let initialUpperValue = totalDuration * 0.75
            let sliderBounds = 0.0...totalDuration

            self._sessionStartTime = State(initialValue: firstTimestamp)
            self._maxTimeValue = State(initialValue: totalDuration)
            self._timeWindowStart = State(initialValue: initialLowerValue)
            self._timeWindowEnd = State(initialValue: initialUpperValue)

            _rangeSliderViewModel = StateObject(wrappedValue: RangeSlider.ViewModel(
                sliderPosition: initialLowerValue...initialUpperValue,
                sliderBounds: sliderBounds
            ))
        } else {
            // Fallback values
            self._sessionStartTime = State(initialValue: 0)
            self._maxTimeValue = State(initialValue: 1)
            self._timeWindowStart = State(initialValue: 0)
            self._timeWindowEnd = State(initialValue: 1)

            _rangeSliderViewModel = StateObject(wrappedValue: RangeSlider.ViewModel(
                sliderPosition: 0...1,
                sliderBounds: 0...1
            ))
        }
    }

    var body: some View {
        VStack {
            dataTypeSelectionView
            movingAverageToggleView
            timeWindowSlider
            timeWindowLabels
            chartView
            settingsBarsView
        }
        .navigationTitle("Data Graph")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var dataTypeSelectionView: some View {
        VStack {
            Text("Select Data Types:")
                .font(.headline)
                .padding(.top)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(DataType.allCases) { dataType in
                        Button(action: {
                            toggleDataTypeSelection(dataType)
                        }) {
                            Text(dataType.rawValue)
                                .padding()
                                .background(selectedDataTypes.contains(dataType) ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var movingAverageToggleView: some View {
        VStack {
            Toggle("Apply Moving Average", isOn: $applyMovingAverage)
                .padding()

            if applyMovingAverage {
                HStack {
                    Text("Period:")
                    Slider(value: $movingAveragePeriod, in: 1...20, step: 1)
                    Text("\(Int(movingAveragePeriod))")
                }
                .padding(.horizontal)
            }
        }
    }

    private var timeWindowSlider: some View {
        VStack {
            Text("Time Window:")
                .font(.headline)
            RangeSlider(viewModel: rangeSliderViewModel) { newRange in
                self.timeWindowStart = newRange.lowerBound
                self.timeWindowEnd = newRange.upperBound
            }
            .padding(.horizontal)
        }
    }

    private var timeWindowLabels: some View {
        HStack {
            Text("Start: \(formattedTime(from: timeWindowStart + sessionStartTime))")
            Spacer()
            Text("End: \(formattedTime(from: timeWindowEnd + sessionStartTime))")
        }
        .padding(.horizontal)
    }

    private var chartView: some View {
        Chart {
            ForEach(selectedDataTypes.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { dataType in
                plotData(for: dataType)
            }
        }
        .chartYAxis { AxisMarks() }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
        .padding()
    }

    private var settingsBarsView: some View {
        VStack(spacing: 4) {
            SettingsBarView(segments: gearSegments, totalDuration: timeWindowEnd - timeWindowStart, label: "Gear")
            SettingsBarView(segments: terrainSegments, totalDuration: timeWindowEnd - timeWindowStart, label: "Terrain")
            SettingsBarView(segments: positionSegments, totalDuration: timeWindowEnd - timeWindowStart, label: "Position")
        }
        .frame(height: 90)
        .padding(.horizontal)
    }

    // MARK: - Helper Functions

    private func toggleDataTypeSelection(_ dataType: DataType) {
        if selectedDataTypes.contains(dataType) {
            selectedDataTypes.remove(dataType)
        } else {
            selectedDataTypes.insert(dataType)
        }
    }

    private func downsampleDataPoints(_ dataPoints: [ChartDataPoint], targetCount: Int) -> [ChartDataPoint] {
        guard dataPoints.count > targetCount else { return dataPoints }
        let factor = dataPoints.count / targetCount
        return stride(from: 0, to: dataPoints.count, by: factor).map { dataPoints[$0] }
    }

    private func plotData(for dataType: DataType) -> some ChartContent {
        let allDataPoints = filteredData(for: dataType)
        let dataPoints = downsampleDataPoints(allDataPoints, targetCount: 1000)
        return ForEach(dataPoints.indices, id: \.self) { index in
            LineMark(
                x: .value("Time", dataPoints[index].time),
                y: .value(dataType.rawValue, dataPoints[index].value)
            )
            .foregroundStyle(by: .value("DataType", dataType.rawValue))
            .interpolationMethod(.linear)
        }
    }

    // Segments for gear, terrain, and position
    struct Segment: Identifiable {
        var id = UUID()
        var startTime: TimeInterval
        var endTime: TimeInterval
        var value: String
        var color: Color
    }

    var gearSegments: [Segment] {
        generateSegments(keyPath: \.gear, valueFormatter: { "\($0)" }, colorProvider: colorForGear)
    }

    var terrainSegments: [Segment] {
        generateSegments(keyPath: \.terrain, valueFormatter: { $0 }, colorProvider: colorForTerrain)
    }

    var positionSegments: [Segment] {
        generateSegments(keyPath: \.isStanding, valueFormatter: { $0 ? "Standing" : "Sitting" }, colorProvider: colorForPosition)
    }

    func generateSegments<T: Equatable>(
        keyPath: KeyPath<CyclingData, T>,
        valueFormatter: (T) -> String,
        colorProvider: (T) -> Color
    ) -> [Segment] {
        let intervals = extractSettingIntervals(keyPath: keyPath)
        let filteredIntervals = intervals.filter { interval in
            interval.end > timeWindowStart + sessionStartTime && interval.start < timeWindowEnd + sessionStartTime
        }

        return filteredIntervals.map { interval in
            let adjustedStart = max(interval.start, timeWindowStart + sessionStartTime) - (timeWindowStart + sessionStartTime)
            let adjustedEnd = min(interval.end, timeWindowEnd + sessionStartTime) - (timeWindowStart + sessionStartTime)
            return Segment(
                startTime: adjustedStart,
                endTime: adjustedEnd,
                value: valueFormatter(interval.value),
                color: colorProvider(interval.value)
            )
        }
    }

    var maxGearValue: Int {
        session.data.map { $0.gear }.max() ?? 1
    }

    func colorForGear(_ gear: Int) -> Color {
        guard gear > 0 else { return .black } // Default color for invalid gear numbers

        let fraction = Double(gear - 1) / Double(maxGearValue - 1)
        let startColor = Color.red // Starting color of the gradient
        let endColor = Color.blue  // Ending color of the gradient

        return Color.lerp(from: startColor, to: endColor, fraction: fraction)
    }

    func colorForTerrain(_ terrain: String) -> Color {
        switch terrain.lowercased() {
        case "road":
            return .gray
        case "gravel":
            return .brown
        case "mountain":
            return .green
        default:
            return .black
        }
    }

    func colorForPosition(_ isStanding: Bool) -> Color {
        return isStanding ? .purple : .blue
    }

    func extractSettingIntervals<T: Equatable>(
        keyPath: KeyPath<CyclingData, T>
    ) -> [(start: TimeInterval, end: TimeInterval, value: T)] {
        var intervals: [(start: TimeInterval, end: TimeInterval, value: T)] = []
        guard !session.data.isEmpty else { return intervals }

        let data = session.data
        var currentStart = data.first!.timestamp.timeIntervalSinceReferenceDate
        var currentValue = data.first![keyPath: keyPath]

        for i in 1..<data.count {
            let timestamp = data[i].timestamp.timeIntervalSinceReferenceDate
            let value = data[i][keyPath: keyPath]

            if value != currentValue {
                intervals.append((start: currentStart, end: timestamp, value: currentValue))
                currentStart = timestamp
                currentValue = value
            }
        }

        intervals.append((start: currentStart, end: data.last!.timestamp.timeIntervalSinceReferenceDate, value: currentValue))

        return intervals
    }

    // Filter data within the time window
    func filteredData(for dataType: DataType) -> [ChartDataPoint] {
        let dataPoints = session.data.filter { dataPoint in
            let time = dataPoint.timestamp.timeIntervalSinceReferenceDate - sessionStartTime
            return time >= timeWindowStart && time <= timeWindowEnd
        }

        var values: [Double] = []
        switch dataType {
        case .speed:
            values = dataPoints.map { $0.speed }
        case .cadence:
            values = dataPoints.map { $0.cadence }
        case .accelerometerX:
            values = dataPoints.map { $0.sensorData.accelerationX }
        case .accelerometerY:
            values = dataPoints.map { $0.sensorData.accelerationY }
        case .accelerometerZ:
            values = dataPoints.map { $0.sensorData.accelerationZ }
        case .rotationRateX:
            values = dataPoints.map { $0.sensorData.rotationRateX }
        case .rotationRateY:
            values = dataPoints.map { $0.sensorData.rotationRateY }
        case .rotationRateZ:
            values = dataPoints.map { $0.sensorData.rotationRateZ }
        }

        if applyMovingAverage {
            values = movingAverage(values: values, period: Int(movingAveragePeriod))
        }

        let times = dataPoints.map { $0.timestamp.timeIntervalSinceReferenceDate - sessionStartTime - timeWindowStart }

        return zip(times, values).map { ChartDataPoint(time: $0, value: $1) }
    }

    func movingAverage(values: [Double], period: Int) -> [Double] {
        guard period > 1 else { return values }
        var averagedValues: [Double] = []
        for i in 0..<values.count {
            let start = max(0, i - period + 1)
            let slice = values[start...i]
            let average = slice.reduce(0, +) / Double(slice.count)
            averagedValues.append(average)
        }
        return averagedValues
    }

    private func formattedTime(from timeInterval: TimeInterval) -> String {
        let date = Date(timeIntervalSinceReferenceDate: timeInterval)
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct ChartDataPoint {
    let time: Double
    let value: Double
}

extension Color {
    static func lerp(from: Color, to: Color, fraction: Double) -> Color {
        let fraction = min(max(0, fraction), 1) // Clamp fraction between 0 and 1

        let fromComponents = from.cgColorComponents
        let toComponents = to.cgColorComponents

        let r = fromComponents.red + fraction * (toComponents.red - fromComponents.red)
        let g = fromComponents.green + fraction * (toComponents.green - fromComponents.green)
        let b = fromComponents.blue + fraction * (toComponents.blue - fromComponents.blue)
        let a = fromComponents.alpha + fraction * (toComponents.alpha - fromComponents.alpha)

        return Color(red: r, green: g, blue: b, opacity: a)
    }

    var cgColorComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let uiColor = UIColor(self)
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif os(macOS)
        let nsColor = NSColor(self)
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
