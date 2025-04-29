//
//  DistanceDisplayView.swift
//  Lidar
//
//  Created by IceQwen on 29/04/25.
//

import SwiftUI

struct DistanceDisplayView: View {
    @ObservedObject var viewModel: DetectorViewModel
    
    var body: some View {
        VStack {
            Text(viewModel.distanceText)
                .font(.headline)
                .padding()
                .background(Color.black.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(10)
            
            Text(viewModel.proximityLevel.rawValue)
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .background(viewModel.proximityLevel.color.opacity(0.3))
                .foregroundColor(viewModel.proximityLevel.color)
                .cornerRadius(10)
                .padding(.top, 5)
        }
    }
}
