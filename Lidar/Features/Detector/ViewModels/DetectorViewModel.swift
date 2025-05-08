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
    
    private var lastKnownDistance: Float = 0
    private var consecutiveFailedAttempts = 0
    private let maxFailedAttempts = 3
    
    init() {
        checkARSupport()
    }
    
    func checkARSupport() {
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            isARSupported = true
        } else {
            isARSupported = true
            distanceText = "Using limited depth estimation"
        }
    }
    
    func startSession() {
        guard isARSupported else { return }
                
        let arSession = ARSession()
        let configuration = ARWorldTrackingConfiguration()
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if let bestFormat = ARConfiguration.bestAvailableVideoFormat {
            configuration.videoFormat = bestFormat
        } else {
            configuration.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first!
            print("Warning: Using fallback video format")
        }
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        self.arSession = arSession
        
        Timer.publish(every: 0.2, on: .main, in: .common)
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
       guard let frame = arSession?.currentFrame else {
           distanceText = "No Session"
           proximityLevel = .unknown
           return
       }
       
       // LiDAR path
       if let depthData = frame.sceneDepth {
           processLiDARDepth(depthMap: depthData.depthMap)
           consecutiveFailedAttempts = 0
           return
       }
       
       // Non-LiDAR path - improved detection
       processNonLiDARDetection(frame: frame)
   }
    
    private func processLiDARDepth(depthMap: CVPixelBuffer) {
       let width = CVPixelBufferGetWidth(depthMap)
       let height = CVPixelBufferGetHeight(depthMap)
       let centerX = width / 2
       let centerY = height / 2
       
       CVPixelBufferLockBaseAddress(depthMap, .readOnly)
       defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
       
       let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
       let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!
       let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
       let index = centerY * bytesPerRow / 4 + centerX
       let distance = floatBuffer[index]
       
       updateDisplay(distance: distance)
   }
    
    private func processNonLiDARDetection(frame: ARFrame) {
        let offsets: [CGFloat] = [-0.05, 0.0, 0.05]
        let pointsToTest = offsets.flatMap { dx in
            offsets.map { dy in
                CGPoint(x: 0.5 + dx, y: 0.5 + dy)
            }
        }
        
        var bestScore: Float?
        var bestDistance: Float?
        
        let cameraTransform = frame.camera.transform
        let cameraPosition = simd_make_float3(cameraTransform.columns.3)
        let viewDirection = -normalize(simd_make_float3(cameraTransform.columns.2)) // camera looks along -Z
        
        for point in pointsToTest {
            let query = frame.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any)
            
            if let results = arSession?.raycast(query),
               let result = results.first {
                
                let targetPosition = simd_make_float3(result.worldTransform.columns.3)
                let distance = simd_distance(cameraPosition, targetPosition)
                
                guard distance > 0.05 else { continue }
                
                let hitDirection = normalize(targetPosition - cameraPosition)
                let angleDot = simd_dot(hitDirection, viewDirection)
                guard angleDot > 0.75 else { continue } // within ~40°

                if let planeAnchor = result.anchor as? ARPlaneAnchor {
                    if planeAnchor.extent.x < 0.1 && planeAnchor.extent.z < 0.1 {
                        continue
                    }
                }
                
                let centerOffset = abs(point.x - 0.5) + abs(point.y - 0.5)
                let score = distance + Float(centerOffset) * 0.5
                
                if bestScore == nil || score < bestScore! {
                    bestScore = score
                    bestDistance = distance
                }
            }
        }
        
        if let distance = bestDistance {
            consecutiveFailedAttempts = 0
            lastKnownDistance = distance
            updateDisplay(distance: distance)
        } else {
            consecutiveFailedAttempts += 1
            
            if consecutiveFailedAttempts < maxFailedAttempts, lastKnownDistance > 0 {
                updateDisplay(distance: lastKnownDistance)
            } else {
                DispatchQueue.main.async {
                    self.distanceText = "No surface detected"
                    self.proximityLevel = .unknown
                }
            }
        }
    }

    
    private func updateDisplay(distance: Float) {
       guard !distance.isNaN && distance > 0 else {
           DispatchQueue.main.async {
               self.distanceText = "Out of range"
               self.proximityLevel = .unknown
           }
           return
       }
       
       let distanceInMeters = Double(distance)
       let distanceInCm = distanceInMeters * 100
       
       let level: ProximityLevel
       if distanceInMeters < 0.5 {
           level = .near
       } else if distanceInMeters < 2.0 {
           level = .medium
       } else {
           level = .far
       }
       
       DispatchQueue.main.async {
           self.distanceText = String(format: "%.2f m (%.0f cm)", distanceInMeters, distanceInCm)
           self.proximityLevel = level
       }
   }
    
//    private func updateDistance() {
//        guard let frame = arSession?.currentFrame
//        else {
//            distanceText = "No Session"
//            proximityLevel = .unknown
//            return
//        }
//        
//        if let depthData = frame.sceneDepth {
//            let depthMap = depthData.depthMap
//            
//            let width = CVPixelBufferGetWidth(depthMap)
//            let height = CVPixelBufferGetHeight(depthMap)
//            
//            /// Get the center point of image
//            let centerX = width / 2
//            let centerY = height / 2
//            
//            /// Lock the base address
//            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
//            
//            /// Get the address of the center pixel
//            let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
//            let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!
//            
//            /// Fetch distance value
//            let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
//            let index = centerY * bytesPerRow / 4 + centerX
//            let distance = floatBuffer[index]
//            
//            /// Unlock the base address when done to prevent memory leak
//            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
//            
//            if distance.isNaN || distance <= 0 {
//                DispatchQueue.main.async {
//                    self.distanceText = "Out of range"
//                    self.proximityLevel = .unknown
//                }
//                return
//            }
//            
//            /// Convert distance to cm and m
//            let distanceInMeters = Double(distance)
//            let distanceInCm = distanceInMeters * 100
//            
//            /// Determine proximity level
//            let level: ProximityLevel
//            if distanceInMeters < 0.5 {
//                level = .near
//            } else if distanceInMeters < 2.0 {
//                level = .medium
//            } else {
//                level = .far
//            }
//            
//            /// Update UI on main thread
//            DispatchQueue.main.async {
//                self.distanceText = String(format: "%.2f m (%.0f cm)", distanceInMeters, distanceInCm)
//                self.proximityLevel = level
//            }
//        } else {
//            /// lidar not suported, detect using raycast
//            print("it comes here")
//            let center = CGPoint(x: 0.5, y: 0.5)
//            if let query = arSession?.currentFrame?.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .any),
//               let result = arSession?.raycast(query).first
//            {
//                let cameraTransform = frame.camera.transform
//                let cameraPosition = simd_make_float3(cameraTransform.columns.3)
//                let targetPosition = simd_make_float3(result.worldTransform.columns.3)
//                let distance = simd_distance(cameraPosition, targetPosition)
//
//                let distanceInCm = distance * 100
//                
//                let level: ProximityLevel
//                if distance < 0.5 {
//                    level = .near
//                } else if distance < 2.0 {
//                    level = .medium
//                } else {
//                    level = .far
//                }
//
//                DispatchQueue.main.async {
//                    self.distanceText = String(format: "%.2f m (%.0f cm)", distance, distanceInCm)
//                    self.proximityLevel = level
//                }
//            } else {
//                DispatchQueue.main.async {
//                    self.distanceText = "No surface detected"
//                    self.proximityLevel = .unknown
//                }
//            }
//        }
        
//        guard let frame = arSession?.currentFrame,
//              let depthData = frame.sceneDepth
//        else {
//            distanceText = "No depth data"
//            proximityLevel = .unknown
//            return
//        }
//
//        let depthMap = depthData.depthMap
//
//        // Get the dimensions of the depth map
//        let width = CVPixelBufferGetWidth(depthMap)
//        let height = CVPixelBufferGetHeight(depthMap)
//
//        // Get the center point
//        let centerX = width / 2
//        let centerY = height / 2
//
//        // Lock the base address
//        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
//
//        // Get the address of the center pixel
//        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
//        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!
//
//        // Depth map contains 32-bit float values
//        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
//        let index = centerY * bytesPerRow / 4 + centerX
//        let distance = floatBuffer[index]
//
//        // Unlock the base address when done
//        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
//
//        if distance.isNaN || distance <= 0 {
//            DispatchQueue.main.async {
//                self.distanceText = "Out of range"
//                self.proximityLevel = .unknown
//            }
//            return
//        }
//
//        // Convert distance to cm and m
//        let distanceInMeters = Double(distance)
//        let distanceInCm = distanceInMeters * 100
//
//        // Determine proximity level
//        let level: ProximityLevel
//        if distanceInMeters < 0.5 {
//            level = .near
//        } else if distanceInMeters < 2.0 {
//            level = .medium
//        } else {
//            level = .far
//        }
//
//        // Update UI on main thread
//        DispatchQueue.main.async {
//            self.distanceText = String(format: "%.2f m (%.0f cm)", distanceInMeters, distanceInCm)
//            self.proximityLevel = level
//        }
    }

