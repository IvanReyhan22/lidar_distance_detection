//
//  UnsupportedDeviceView.swift
//  Lidar
//
//  Created by IceQwen on 29/04/25.
//

import SwiftUI

struct UnsupportedDeviceView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .frame(height: 100)

            Text("LiDAR Not Supported")
                .font(.title)
                .fontWeight(.bold)

            Text("This feature requires a device with a LiDAR sensor, such as iPhone 12 Pro/Pro Max or newer, or iPad Pro 2020 or newer.")
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}

#Preview {
    UnsupportedDeviceView()
}
