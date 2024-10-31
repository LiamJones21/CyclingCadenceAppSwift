//
//  TimelineSliderView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 26/10/2024.
// TimelineSliderView.swift

import SwiftUI

struct TimelineSliderView: View {
    @Binding var timeWindowStart: TimeInterval
    @Binding var timeWindowEnd: TimeInterval
    let totalDuration: TimeInterval

    @State private var isDraggingStartHandle = false
    @State private var isDraggingEndHandle = false
    @State private var isDraggingMiddle = false
    @State private var lastDragValue: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let handleWidth: CGFloat = 20
            let width = geometry.size.width
            let height: CGFloat = 50

            let startRatio = CGFloat(timeWindowStart / totalDuration)
            let endRatio = CGFloat(timeWindowEnd / totalDuration)
            let startX = startRatio * width
            let endX = endRatio * width
            let selectedWidth = endX - startX

            ZStack(alignment: .leading) {
                // Full Timeline Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                    .cornerRadius(10)

                // Selected Timeline Area
                Rectangle()
                    .fill(Color.yellow.opacity(0.5))
                    .frame(width: selectedWidth, height: height)
                    .offset(x: startX)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingMiddle = true
                                let deltaX = value.translation.width - lastDragValue
                                let deltaRatio = deltaX / width
                                let deltaTime = deltaRatio * totalDuration

                                var newStart = timeWindowStart + TimeInterval(deltaTime)
                                var newEnd = timeWindowEnd + TimeInterval(deltaTime)

                                // Ensure the window stays within total duration
                                if newStart < 0 {
                                    newEnd -= newStart
                                    newStart = 0
                                }
                                if newEnd > totalDuration {
                                    newStart -= newEnd - totalDuration
                                    newEnd = totalDuration
                                }
                                timeWindowStart = newStart
                                timeWindowEnd = newEnd
                                lastDragValue = value.translation.width
                            }
                            .onEnded { _ in
                                isDraggingMiddle = false
                                lastDragValue = 0
                            }
                    )

                // Start Handle
                VStack {
                    if isDraggingStartHandle {
                        Text("\(String(format: "%.2f", timeWindowStart - timeWindowStart)) s")
                            .font(.caption)
                            .padding(5)
                            .background(Color.white)
                            .cornerRadius(5)
                            .offset(y: -30)
                    }
                    Rectangle()
                        .fill(isDraggingStartHandle ? Color.orange : Color.blue)
                        .frame(width: handleWidth, height: height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingStartHandle = true
                                    let deltaX = value.translation.width
                                    let deltaRatio = deltaX / width
                                    let deltaTime = deltaRatio * totalDuration
                                    var newStart = timeWindowStart + TimeInterval(deltaTime)
                                    newStart = max(0, min(newStart, timeWindowEnd - 1))
                                    timeWindowStart = newStart
                                }
                                .onEnded { _ in
                                    isDraggingStartHandle = false
                                }
                        )
                }
                .position(x: startX + handleWidth / 2, y: height / 2)

                // End Handle
                VStack {
                    if isDraggingEndHandle {
                        Text("\(String(format: "%.2f", timeWindowEnd - timeWindowStart)) s")
                            .font(.caption)
                            .padding(5)
                            .background(Color.white)
                            .cornerRadius(5)
                            .offset(y: -30)
                    }
                    Rectangle()
                        .fill(isDraggingEndHandle ? Color.orange : Color.blue)
                        .frame(width: handleWidth, height: height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingEndHandle = true
                                    let deltaX = value.translation.width
                                    let deltaRatio = deltaX / width
                                    let deltaTime = deltaRatio * totalDuration
                                    var newEnd = timeWindowEnd + TimeInterval(deltaTime)
                                    newEnd = min(totalDuration, max(newEnd, timeWindowStart + 1))
                                    timeWindowEnd = newEnd
                                }
                                .onEnded { _ in
                                    isDraggingEndHandle = false
                                }
                        )
                }
                .position(x: endX - handleWidth / 2, y: height / 2)
            }
        }
        .frame(height: 50)
        .padding()
    }
}
