//
//  ARViewContainer.swift
//  Lidar
//
//  Created by IceQwen on 29/04/25.
//

import ARKit
import Combine
import RealityKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    var viewModel: DetectorViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        
        // Set environment settings to show camera feed
        arView.environment.sceneUnderstanding.options = []
        arView.environment.background = .cameraFeed()
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        if let session = viewModel.arSession {
            arView.session = session
        }
                
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if uiView.session !== viewModel.arSession {
            if let arSession = viewModel.arSession {
                uiView.session = arSession
            }
        }
    }
}
