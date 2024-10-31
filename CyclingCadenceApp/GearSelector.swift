//
//  GearSelector.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 21/10/2024.
//


// GearSelector.swift

import SwiftUI

struct GearSelector: View {
    @ObservedObject var viewModel: CyclingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Gear:")
                .font(.headline)
                .padding(.leading, 20)

            let columns = [GridItem(.adaptive(minimum: 80), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                // Include gear 0
                Button(action: {
                    viewModel.currentGear = 0
                }) {
                    Text("0")
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(viewModel.currentGear == 0 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                ForEach(viewModel.gearRatios.indices, id: \.self) { index in
                    Button(action: {
                        viewModel.currentGear = index + 1
                    }) {
                        Text("\(index + 1)")
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(viewModel.currentGear == index + 1 ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding([.leading, .trailing], 20)
        }
    }
}

