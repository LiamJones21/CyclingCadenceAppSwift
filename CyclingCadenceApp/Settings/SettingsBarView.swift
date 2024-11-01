//
//  SettingsBarView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 26/10/2024.
// SettingsBarView.swift

import SwiftUI

struct SettingsBarView: View {
    let segments: [GraphView.Segment]
    let totalDuration: TimeInterval
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.black)
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        let width = widthForSegment(segment, totalWidth: totalWidth)
                        ZStack {
                            Rectangle()
                                .fill(segment.color)
                                .frame(width: width)
                            Text(segment.value)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(width: width)
                        }
                    }
                }
            }
        }
        .frame(height: 40).cornerRadius(10)
    }

    func widthForSegment(_ segment: GraphView.Segment, totalWidth: CGFloat) -> CGFloat {
        let duration = segment.endTime - segment.startTime
        let ratio = CGFloat(duration / totalDuration)
        return max(ratio * totalWidth, 0)
    }
}
//
//
//
//// SettingsBarView.swift
//
//import SwiftUI
//
//struct SettingsBarView: View {
//    let segments: [GraphView.Segment]
//    let totalDuration: TimeInterval
//    let label: String
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 2) {
//            Text(label)
//                .font(.caption)
//                .foregroundColor(.black)
//            GeometryReader { geometry in
//                let totalWidth = geometry.size.width
//                HStack(spacing: 0) {
//                    ForEach(segments) { segment in
//                        let width = widthForSegment(segment, totalWidth: totalWidth)
//                        Text(segment.value)
//                            .frame(width: width, height: 20)
//                            .background(segment.color)
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//        .frame(height: 30)
//    }
//
//    func widthForSegment(_ segment: GraphView.Segment, totalWidth: CGFloat) -> CGFloat {
//        let duration = segment.endTime - segment.startTime
//        let ratio = CGFloat(duration / totalDuration)
//        return max(ratio * totalWidth, 0)
//    }
//}
