//
//  RangeSliderView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 29/10/2024.
import SwiftUI

struct RangeSlider: View {
    @ObservedObject var viewModel: ViewModel
    @State private var isActive: Bool = false
    let sliderPositionChanged: (ClosedRange<Double>) -> Void

    var body: some View {
        GeometryReader { geometry in
            sliderView(sliderSize: geometry.size, sliderViewYCenter: geometry.size.height / 2)
        }
        .frame(height: 30) // Set the height of the range slider
    }

    @ViewBuilder private func sliderView(sliderSize: CGSize, sliderViewYCenter: CGFloat) -> some View {
        let leftThumbPosition = viewModel.leftThumbLocation(width: sliderSize.width, sliderViewYCenter: sliderViewYCenter)
        let rightThumbPosition = viewModel.rightThumbLocation(width: sliderSize.width, sliderViewYCenter: sliderViewYCenter)

        lineBetweenThumbs(from: leftThumbPosition, to: rightThumbPosition)
            .gesture(DragGesture()
                .onChanged { dragValue in
                    let delta = viewModel.deltaFromDrag(dragValue: dragValue, width: sliderSize.width)
                    viewModel.adjustBothThumbs(by: delta)
                    sliderPositionChanged(viewModel.sliderPosition)
                    isActive = true
                }
                .onEnded { _ in
                    isActive = false
                }
            )

        // Left Thumb
        thumbView(position: leftThumbPosition)
            .highPriorityGesture(DragGesture()
                .onChanged { dragValue in
                    let newValue = viewModel.newThumbLocation(dragLocation: dragValue.location, width: sliderSize.width)
                    if newValue < viewModel.sliderPosition.upperBound {
                        viewModel.sliderPosition = newValue...viewModel.sliderPosition.upperBound
                        sliderPositionChanged(viewModel.sliderPosition)
                        isActive = true
                    }
                }.onEnded { _ in
                    isActive = false
                })

        // Right Thumb
        thumbView(position: rightThumbPosition)
            .highPriorityGesture(DragGesture()
                .onChanged { dragValue in
                    let newValue = viewModel.newThumbLocation(dragLocation: dragValue.location, width: sliderSize.width)
                    if newValue > viewModel.sliderPosition.lowerBound {
                        viewModel.sliderPosition = viewModel.sliderPosition.lowerBound...newValue
                        sliderPositionChanged(viewModel.sliderPosition)
                        isActive = true
                    }
                }.onEnded { _ in
                    isActive = false
                })
    }

    @ViewBuilder func lineBetweenThumbs(from: CGPoint, to: CGPoint) -> some View {
        ZStack {
            // Track
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 4)

            // Selected Range
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(isActive ? Color.blue : Color.blue.opacity(0.8), lineWidth: 4)
        }
    }

    @ViewBuilder func thumbView(position: CGPoint) -> some View {
        Circle()
            .frame(width: 20, height: 20)
            .foregroundColor(isActive ? Color.blue : Color.gray)
            .contentShape(Rectangle())
            .position(x: position.x, y: position.y)
            .animation(.spring(), value: isActive)
    }
}

extension RangeSlider {
    final class ViewModel: ObservableObject {
        @Published var sliderPosition: ClosedRange<Double>
        let sliderBounds: ClosedRange<Double>
        let sliderBoundDifference: Double

        init(sliderPosition: ClosedRange<Double>, sliderBounds: ClosedRange<Double>) {
            self.sliderPosition = sliderPosition
            self.sliderBounds = sliderBounds
            self.sliderBoundDifference = sliderBounds.upperBound - sliderBounds.lowerBound
        }

        func leftThumbLocation(width: CGFloat, sliderViewYCenter: CGFloat = 0) -> CGPoint {
            let ratio = (sliderPosition.lowerBound - sliderBounds.lowerBound) / sliderBoundDifference
            let xPosition = CGFloat(ratio) * width
            return CGPoint(x: xPosition, y: sliderViewYCenter)
        }

        func rightThumbLocation(width: CGFloat, sliderViewYCenter: CGFloat = 0) -> CGPoint {
            let ratio = (sliderPosition.upperBound - sliderBounds.lowerBound) / sliderBoundDifference
            let xPosition = CGFloat(ratio) * width
            return CGPoint(x: xPosition, y: sliderViewYCenter)
        }

        func newThumbLocation(dragLocation: CGPoint, width: CGFloat) -> Double {
            let xPosition = min(max(0, dragLocation.x), width)
            let ratio = xPosition / width
            let value = Double(ratio) * sliderBoundDifference + sliderBounds.lowerBound
            return min(max(sliderBounds.lowerBound, value), sliderBounds.upperBound)
        }

        func deltaFromDrag(dragValue: DragGesture.Value, width: CGFloat) -> Double {
            let translationRatio = Double(dragValue.translation.width / width)
            let deltaValue = translationRatio * sliderBoundDifference
            return deltaValue
        }

        func adjustBothThumbs(by delta: Double) {
            var newLower = sliderPosition.lowerBound + delta
            var newUpper = sliderPosition.upperBound + delta

            // Ensure the new positions are within bounds
            let rangeWidth = sliderPosition.upperBound - sliderPosition.lowerBound
            if newLower < sliderBounds.lowerBound {
                newLower = sliderBounds.lowerBound
                newUpper = newLower + rangeWidth
            } else if newUpper > sliderBounds.upperBound {
                newUpper = sliderBounds.upperBound
                newLower = newUpper - rangeWidth
            }

            sliderPosition = newLower...newUpper
        }
    }
}
