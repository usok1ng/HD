//
//  RoundButton.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/09/03.
//

import SwiftUI

struct RoundButton: View {
    let color: Color
    let text: String
    let fontSize: CGFloat
    let icon: String?
    let action: () -> Void

    init(color: Color,
         text: String,
         fontSize: CGFloat,
         icon: String?,
         action: @escaping () -> Void){
        self.color = color
        self.text = text
        self.fontSize = fontSize
        self.icon = icon ?? nil
        self.action = action
    }
    
    var body: some View {
        Button(action: { action() }){
            if let icon = icon {
            Image(systemName: icon)
                .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(color)
        }
        .padding(8)
        .padding(.horizontal, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 50)
                .stroke(Color(.white), lineWidth: 1))
    }
}
