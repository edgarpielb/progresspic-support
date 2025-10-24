//
//  TimeRangeSelector.swift
//  ProgressPic
//
//  Reusable time range selector component
//  Extracted from MeasurementDetailView and BodyCompositionDetailView
//

import SwiftUI

/// Reusable horizontal scrolling time range selector
struct TimeRangeSelector<T>: View where T: RawRepresentable & CaseIterable & Identifiable, T.RawValue == String, T.AllCases: RandomAccessCollection {
    @Binding var selectedRange: T

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(T.allCases), id: \.id) { range in
                    Button(action: {
                        selectedRange = range
                    }) {
                        Text(range.rawValue)
                            .font(.subheadline)
                            .foregroundColor(selectedRange.id == range.id ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedRange.id == range.id ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// Note: This component works with any enum that conforms to:
// - RawRepresentable with String
// - CaseIterable
// - Identifiable
//
// Example usage:
// TimeRangeSelector(selectedRange: $selectedTimeRange)
// where selectedTimeRange is of type MeasurementTimeRange or TimeRange
