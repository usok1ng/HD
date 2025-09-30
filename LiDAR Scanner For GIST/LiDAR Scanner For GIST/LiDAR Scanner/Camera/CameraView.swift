//
//  CameraView.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/06/14.
//

import Foundation
import SwiftUI
import MetalKit
import ARKit

struct CameraView: View {
    @ObservedObject var viewModel = CameraViewModel()
    
    // Manage the AR session and AR data processing.
    //- Tag: ARProvider
    @ObservedObject var arProvider: ARProvider = ARProvider()!
    
    let ciContext: CIContext = CIContext()
    
    // Save the user's confidence selection.
    @State private var selectedConfidence = 15
    // Set the depth view's state data.
    @State var isToUpsampleDepth = true
    @State var isShowSmoothDepth = true
    @State var isArPaused = false
    @State private var scaleMovement: Float = 1.5
    @State var saveSuffix: String = ""
    @State var numRecordedSceneBundles = 0
    @State var numRecordedPoseBundles = 0
    @State var opacity = Float(0.2)
    @State private var multySelection = Set<UUID>()
    @State private var singleSelection: UUID?
    

    let frames = [15, 30, 60, 120]
    let baseLine = BezierLineView()
    let percent = SimpleLabelView(text: "100.0")
    let progressBar = CountdownProgressView()
    let measureView = MeasureListView()    
    let progressView = ProgressView()

    var body: some View {
        let bounds: CGRect = UIScreen.main.bounds
        @State var bundleSize = 15
        
        if !ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
            Text("Unsupported Device: This app requires the LiDAR Scanner to access the scene's depth.")
        } else {
            VStack() {

                // bundle size selector
                //HStack {
                    //Spacer(minLength: 100)
                    //Text("Bundle Size: 15")
//                    Picker(selection: $arProvider.bundleSize, label: Text("생성 파일 수 :")) {
//                        ForEach(0..<frames.count, id:\.self){idx in
//                            Text(String(frames[idx])).tag(frames[idx])
//                        }
//                    }
//                    .pickerStyle(SegmentedPickerStyle())
                //}
                //.frame(width: 350, height:50)
                
                HStack{
                    RoundButton(color: .white, text: "-5", fontSize: 16, icon:nil, action: { baseLine.resizeLine(val: -5); percent.setText(text: "-5"); })
                    RoundButton(color: .white, text: "-1", fontSize: 16, icon:nil, action: { baseLine.resizeLine(val: -1);  percent.setText(text: "-1") })
                    RoundButton(color: .white, text: "+1", fontSize: 16, icon:nil, action: { baseLine.resizeLine(val: 1);  percent.setText(text: "1") })
                    RoundButton(color: .white, text: "+5", fontSize: 16, icon:nil, action: { baseLine.resizeLine(val: 5);  percent.setText(text: "5") })
                }
                
                percent
                    .frame(width: 100, height: 25)                    
                    
                HStack(){
                    VStack(){
//                        Text("아래로 당겨 새로고침 하세요!")
//                            .bold()
                            
                        
                        measureView
                            .frame(width: 280)
                            .offset(x: 5)
                        
                        
                    }
                    
                    ZStack(){
                        ZStack(alignment: .bottomLeading){
                            
                            MetalTextureView(mtkView: MTKView(), content: arProvider.colorRGBContent)
                            ZStack(){
                                MetalTextureViewDepth(mtkView: MTKView(), content: arProvider.depthContent, confSelection: $selectedConfidence)
                                    .frame(width: 100, height: 150)
                            }
                            baseLine
                        }
                        
                        progressView
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .controlSize(.extraLarge)
                            .opacity(arProvider.progress_opacity)
                            
                    }
                    
                    //.offset(x: 125)
                    
                }
                
                
                
                VStack{
                    // 측정버튼
                    Button(action: {
                        arProvider.bundleSize = bundleSize
                        arProvider.progress_opacity = 1.0
                        arProvider.isUpload = true
                        arProvider.measureIdx = measureView.getCheckPoint()
                        arProvider.lineLength = baseLine.getCurrentVal()
                        
                        if arProvider.frameCount == 99999 {
                            arProvider.recordBundle(saveSuffix: saveSuffix)
                            numRecordedSceneBundles += 1
                        }
                    }) {
                        Circle()
                            .stroke(lineWidth: 5)
                            .frame(width: 55, height: 55)
                            .padding()
                    }
                    
                    
                }
            }
            .foregroundColor(.white)
            
            
        }
    }
}



#Preview {
    CameraView()
}
