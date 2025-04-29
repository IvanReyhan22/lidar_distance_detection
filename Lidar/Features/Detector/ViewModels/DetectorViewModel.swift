//
//  DetectorViewModel.swift
//  Lidar
//
//  Created by IceQwen on 29/04/25.
//
import ARKit
import Combine
import Foundation
import SwiftUI

class DetectorViewModel: ObservableObject {
    @Published var distanceText = "Measuring..."
    @Published var proximityLevel = ProximityLevel.unknown
    @Published var isARSupported = false
    
    var arSession: ARSession?
    private var cancellables = Set<AnyCancellable>()
    
    enum ProximityLevel: String {
        case near = "NEAR"
        case medium = "MEDIUM"
        case far = "FAR"
        case unknown = "UNKNOWN"
        
        var color: Color {
            switch self {
            case .near:
                return .red
            case .medium:
                return .yellow
            case .far:
                return .green
            case .unknown:
                return .gray
            }
        }
    }
    
    init() {
        checkARSupport()
    }
    
    func checkARSupport() {
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            isARSupported = true
        } else {
            isARSupported = false
            distanceText = "LiDAR not supported on this device"
        }
    }
    
    func startSession() {
        guard isARSupported else { return }
                
        let arSession = ARSession()
        
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        configuration.environmentTexturing = .automatic
        configuration.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first!
        configuration.frameSemantics = .sceneDepth
        
        arSession.run(configuration)
        self.arSession = arSession
        
        // Set up a timer to update distance every 0.5 seconds
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateDistance()
            }
            .store(in: &cancellables)
    }
    
    func stopSession() {
        arSession?.pause()
        cancellables.removeAll()
    }
    
    private func updateDistance() {
        guard let frame = arSession?.currentFrame,
              let depthData = frame.sceneDepth
        else {
            print("DetectorViewModel -> No depth data \(arSession?.currentFrame) : \(arSession?.currentFrame?.sceneDepth)")
            distanceText = "No depth data"
            proximityLevel = .unknown
            return
        }
        
        let depthMap = depthData.depthMap
        
        // Get the dimensions of the depth map
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        // Get the center point
        let centerX = width / 2
        let centerY = height / 2
        
        // Lock the base address
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        
        // Get the address of the center pixel
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!
        
        // Depth map contains 32-bit float values
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let index = centerY * bytesPerRow / 4 + centerX
        let distance = floatBuffer[index]
        
        // Unlock the base address when done
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        
        if distance.isNaN || distance <= 0 {
            DispatchQueue.main.async {
                self.distanceText = "Out of range"
                self.proximityLevel = .unknown
            }
            return
        }
        
        // Convert distance to cm and m
        let distanceInMeters = Double(distance)
        let distanceInCm = distanceInMeters * 100
        
        // Determine proximity level
        let level: ProximityLevel
        if distanceInMeters < 0.5 {
            level = .near
        } else if distanceInMeters < 2.0 {
            level = .medium
        } else {
            level = .far
        }
        
        // Update UI on main thread
        DispatchQueue.main.async {
            self.distanceText = String(format: "%.2f m (%.0f cm)", distanceInMeters, distanceInCm)
            self.proximityLevel = level
        }
    }
}
