//
//  ContentView.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/06/14.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            CameraView()
        }
        .padding()
    }
}

struct MeasureView: View {
    var body: some View{
        VStack{
            CameraView()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
