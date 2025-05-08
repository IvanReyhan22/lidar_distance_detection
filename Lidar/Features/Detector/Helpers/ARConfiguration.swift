//
//  ARConfiguration.swift
//  Lidar
//
//  Created by Akhmad Ramadani on 08/05/25.
//
import ARKit

extension ARConfiguration {
    /// Provides the best available video format for AR configurations
    /// - Returns: The recommended 4K format on iOS 16+, or highest resolution format otherwise
    /// - Note: Returns nil if no formats are available (unlikely on supported devices)
    static var bestAvailableVideoFormat: ARConfiguration.VideoFormat? {
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        guard !formats.isEmpty else { return nil }
        
        if #available(iOS 16.0, *) {
            return ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution ?? formats.first
        } else {
            return formats.max(by: {
                ($0.imageResolution.width * $0.imageResolution.height) <
                ($1.imageResolution.width * $1.imageResolution.height)
            }) ?? formats.first
        }
    }
}
