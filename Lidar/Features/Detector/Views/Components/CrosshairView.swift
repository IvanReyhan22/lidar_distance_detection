//
//  CrosshairView.swift
//  Lidar
//
//  Created by IceQwen on 29/04/25.
//

import SwiftUI

struct CrosshairView: View {
    var color: Color
    
    var body: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .frame(width: 20, height: 3)
                .foregroundColor(color)
            
            // Vertical line
            Rectangle()
                .frame(width: 3, height: 20)
                .foregroundColor(color)
            
            // Circle
            Circle()
                .stroke(color, lineWidth: 3)
                .frame(width: 20, height: 20)
        }
    }
}

#Preview {
    CrosshairView(
        color: .blue
    )
}

