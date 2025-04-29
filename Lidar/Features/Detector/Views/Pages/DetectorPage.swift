//
//  DetectorPage.swift
//  Lidar
//
//  Created by IceQwen on 29/04/25.
//

import SwiftUI

struct DetectorPage: View {
    @StateObject private var viewModel = DetectorViewModel()

    var body: some View {
        ZStack {
            if viewModel.isARSupported {
                if viewModel.arSession != nil {
                    ARViewContainer(viewModel: viewModel)
                        .edgesIgnoringSafeArea(.all)
                }

                // Crosshair at center
                CrosshairView(color: viewModel.proximityLevel.color)

                // Distance display at bottom
                VStack {
                    Spacer()
                    DistanceDisplayView(viewModel: viewModel)
                        .padding(.bottom, 60)
                }
            } else {
                UnsupportedDeviceView()
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

#Preview {
    DetectorPage()
}
