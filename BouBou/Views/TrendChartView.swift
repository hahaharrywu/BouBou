//
//  TrendChartView.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/6/25.
//

import SwiftUI
import Charts

struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let grade: Double
}

struct TrendChartView: View {
    let data: [DataPoint]

    var body: some View {
        let sortedData = data.sorted { $0.date < $1.date }

        
        Chart {
            ForEach(sortedData) { point in
                LineMark(
                    x: .value("Week", point.date),
                    y: .value("Grade", point.grade)
                )
            }
            
            
            // y axis
            RuleMark(x: .value("Start", sortedData.map { $0.date }.min() ?? Date()))
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 2))

            // x axis
            RuleMark(y: .value("Zero", 0.0))
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 2))
        
        }
        
        

        
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .stride(by: .weekOfYear)) { _ in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick()
                AxisValueLabel()
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }



        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.zero)

    }
}
