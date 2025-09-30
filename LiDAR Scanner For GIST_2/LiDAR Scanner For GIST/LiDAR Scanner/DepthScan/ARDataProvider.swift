/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A utility class that provides processed depth information.
*/

import Foundation
import SwiftUI
import Combine
import ARKit
import Accelerate
import MetalPerformanceShaders

// Wrap the `MTLTexture` protocol to reference outputs from ARKit.
final class MetalTextureContent {
    var texture: MTLTexture?
}

// Enable `CVPixelBuffer` to output an `MTLTexture`.
extension CVPixelBuffer {
    
    func texture(withFormat pixelFormat: MTLPixelFormat, planeIndex: Int, addToCache cache: CVMetalTextureCache) -> MTLTexture? {
        
        let width = CVPixelBufferGetWidthOfPlane(self, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(self, planeIndex)
        
        var cvtexture: CVMetalTexture?
        _ = CVMetalTextureCacheCreateTextureFromImage(nil, cache, self, nil, pixelFormat, width, height, planeIndex, &cvtexture)
        let texture = CVMetalTextureGetTexture(cvtexture!)
        
        return texture
        
    }
    
}

extension simd_float3x3 {
    static func / (lhs: simd_float3x3, rhs: Float) -> simd_float3x3 {
        return simd_float3x3(
            lhs.columns.0 / rhs,
            lhs.columns.1 / rhs,
            lhs.columns.2 / rhs
        )
    }
}

extension simd_float3 {
    var xyz: (Float, Float, Float) {
        return (self.x, self.y, self.z)
    }
}

struct Point3f {
    var x: Float
    var y: Float
    var z: Float
}

struct ICPResult {
    var alignedPoints: UnsafeMutablePointer<Point3f>
    var count: Int32
    var transformation: (Float, Float, Float, Float,
                         Float, Float, Float, Float,
                         Float, Float, Float, Float,
                         Float, Float, Float, Float)
}

@_silgen_name("run_icp")
func run_icp(_ source: UnsafePointer<Point3f>, _ source_count: Int32,
             _ target: UnsafePointer<Point3f>, _ target_count: Int32) -> ICPResult

struct PointCloudInfo {
    let intrinsics: simd_float3x3
    let pointCloud: [simd_float3]
    let eulerAngles: simd_float3
    let worldPose: simd_float4x4
    let xxAngle: Float
    let yyAngle: Float
}

// Collect AR data using a lower-level receiver. This class converts AR data
// to a Metal texture, optionally upscaling depth data using a guided filter,
// and implements `ARDataReceiver` to respond to `onNewARData` events.
final class ARProvider: ARDataReceiver, ObservableObject {
    //let path = "http://witsoft.iptime.org:3230"
    let path = "http://10.150.232.54:3230"
    
    // Set the destination resolution for the upscaled algorithm.
    let upscaledWidth = 256
    let upscaledHeight = 192
    
    // Set the original depth size.
    let origDepthWidth = 256
    let origDepthHeight = 192
    
    // Set the original color size.
    let origColorWidth = 1920
    let origColorHeight = 1440
    
    // Set the guided filter constants.
    let guidedFilterEpsilon: Float = 0.004
    let guidedFilterKernelDiameter = 5
    
    // For recording LiDAR bundle
    var recordScene = true
    var bundleSize : Int = 15
    var measureIdx = ""
    var lineLength = -1
    var frameCount = 99999
    var curvature = Float(0)
    @Published var bundleFolder : URL?
    
    var isUpload : Bool
    
    let arReceiver = ARReceiver()
    @Published var lastArData: ARData?
    let depthContent = MetalTextureContent()
    let confidenceContent = MetalTextureContent()
    let colorYContent = MetalTextureContent()
    let colorCbCrContent = MetalTextureContent()
    let upscaledCoef = MetalTextureContent()
    let colorRGBContent = MetalTextureContent()
    let upscaledConfidence = MetalTextureContent()
    
    // 거리 및 각도 프로퍼티 래퍼
    @Published var progress_opacity: Double = 0.0
    @Published var distance: Float = 0   // mm
    @Published var xxAngle: Float = 0    // °
    @Published var yyAngle: Float = 0    // °
    
    let coefTexture: MTLTexture
    let destDepthTexture: MTLTexture
    let destConfTexture: MTLTexture
    let colorRGBTexture: MTLTexture
    let colorRGBTextureDownscaled: MTLTexture
    let colorRGBTextureDownscaledLowRes: MTLTexture
    
    // Enable or disable depth upsampling.
    public var isToUpsampleDepth: Bool = false {
        didSet {
            processLastArData()
        }
    }
    
    // Enable or disable smoothed-depth upsampling.
    public var isUseSmoothedDepthForUpsampling: Bool = false {
        didSet {
            processLastArData()
        }
    }
    var textureCache: CVMetalTextureCache?
    let metalDevice: MTLDevice?
    let guidedFilter: MPSImageGuidedFilter?
    let mpsScaleFilter: MPSImageBilinearScale?
    let commandQueue: MTLCommandQueue?
    let pipelineStateCompute: MTLComputePipelineState?
    
    
    //지스트 추가 변수
    var BaseFrameInfo: PointCloudInfo?
    var accumulatedFrameInfos: [PointCloudInfo] = []
    var transformedPointsCloud: [[simd_float3]] = []
    var ConcatPointsCloud:[simd_float3] = []
    let center: simd_int2 = simd_int2(128, 96)
    var mode: Int = 0
    
    // Create an empty texture.
    static func createTexture(metalDevice: MTLDevice, width: Int, height: Int, usage: MTLTextureUsage, pixelFormat: MTLPixelFormat) -> MTLTexture {
        let descriptor: MTLTextureDescriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = pixelFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.usage = usage
        let resTexture = metalDevice.makeTexture(descriptor: descriptor)
        return resTexture!
    }
    
    // Start or resume the stream from ARKit.
    func start() {
        arReceiver.start()
    }
    
    // Pause the stream from ARKit.
    func pause() {
        arReceiver.pause()
    }
    
    // Initialize the MPS filters, metal pipeline, and Metal textures.
    init?() {
        do {
            metalDevice = MTLCreateSystemDefaultDevice()
            CVMetalTextureCacheCreate(nil, nil, metalDevice!, nil, &textureCache)
            guidedFilter = MPSImageGuidedFilter(device: metalDevice!, kernelDiameter: guidedFilterKernelDiameter)
            guidedFilter?.epsilon = guidedFilterEpsilon
            mpsScaleFilter = MPSImageBilinearScale(device: metalDevice!)
            commandQueue = metalDevice!.makeCommandQueue()
            let lib = metalDevice!.makeDefaultLibrary()
            let convertYUV2RGBFunc = lib!.makeFunction(name: "convertYCbCrToRGBA")
            pipelineStateCompute = try metalDevice!.makeComputePipelineState(function: convertYUV2RGBFunc!)
            // Initialize the working textures.
            coefTexture = ARProvider.createTexture(metalDevice: metalDevice!, width: origDepthWidth, height: origDepthHeight,
                                                   usage: [.shaderRead, .shaderWrite], pixelFormat: .rgba32Float)
            destDepthTexture = ARProvider.createTexture(metalDevice: metalDevice!, width: upscaledWidth, height: upscaledHeight,
                                                        usage: [.shaderRead, .shaderWrite], pixelFormat: .r32Float)
            destConfTexture = ARProvider.createTexture(metalDevice: metalDevice!, width: upscaledWidth, height: upscaledHeight,
                                                       usage: [.shaderRead, .shaderWrite], pixelFormat: .r8Unorm)
            colorRGBTexture = ARProvider.createTexture(metalDevice: metalDevice!, width: origColorWidth, height: origColorHeight,
                                                       usage: [.shaderRead, .shaderWrite], pixelFormat: .rgba32Float)
            colorRGBTextureDownscaled = ARProvider.createTexture(metalDevice: metalDevice!, width: upscaledWidth, height: upscaledHeight,
                                                                 usage: [.shaderRead, .shaderWrite], pixelFormat: .rgba32Float)
            colorRGBTextureDownscaledLowRes = ARProvider.createTexture(metalDevice: metalDevice!, width: origDepthWidth, height: origDepthHeight,
                                                                       usage: [.shaderRead, .shaderWrite], pixelFormat: .rgba32Float)
            upscaledCoef.texture = coefTexture
            upscaledConfidence.texture = destConfTexture
            colorRGBContent.texture = colorRGBTextureDownscaled
            
            isUpload = false
            
            // Set the delegate for ARKit callbacks.
            arReceiver.delegate = self
        } catch {
            print("Unexpected error: \(error).")
            return nil
        }
    }
    
    func writeImageYUV(pixelBuffer: CVPixelBuffer, fileNameSuffix : String) {
        // Image is 2 Plane YUV, shape HxW, H/2 x W/2
        
        //        print("writeImageYUV")
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == noErr else { return }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let srcPtrP0 = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return
        }
        guard let srcPtrP1 = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            return
        }
        
        let rowBytesP0 : Int = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let rowBytesP1 : Int = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        let widthP0 = Int(CVPixelBufferGetWidthOfPlane(pixelBuffer, 0))
        let widthP1 = Int(CVPixelBufferGetWidthOfPlane(pixelBuffer, 1))
        let heightP0 = Int(CVPixelBufferGetHeightOfPlane(pixelBuffer, 0))
        let heightP1 = Int(CVPixelBufferGetHeightOfPlane(pixelBuffer, 1))
        
        let uint8PointerP0 = srcPtrP0.bindMemory(to: UInt8.self, capacity: heightP0 * rowBytesP0)
        let uint8PointerP1 = srcPtrP1.bindMemory(to: UInt8.self, capacity: heightP1 * rowBytesP1)
        
        //        let s = "image_P0_\(widthP0)x\(heightP0)_P1_\(widthP1)x\(heightP1)_\(fileNameSuffix)"
        //        let fileURL = URL(fileURLWithPath: s, relativeTo: bundleFolder).appendingPathExtension("bin")
        //
        //        let stream = OutputStream(url: fileURL, append: false)
        //        stream?.open()
        
        var result: [UInt8] = []
        
        for y in 0 ..< heightP0{
            let rowStart = uint8PointerP0 + (y + rowBytesP0)
            let rowData = Array(UnsafeBufferPointer(start: rowStart, count: rowBytesP0))
            result += rowData
            //            stream?.write(uint8PointerP0 + (y * rowBytesP0), maxLength: Int(rowBytesP0))
        }
        
        for y in 0 ..< heightP1{
            let rowStart = uint8PointerP1 + (y + rowBytesP1)
            let rowData = Array(UnsafeBufferPointer(start: rowStart, count: rowBytesP1))
            result += rowData
            //            stream?.write(uint8PointerP1 + (y * rowBytesP1), maxLength: Int(rowBytesP1))
        }
        
        //        stream?.close()
    }
    
    func writeDepth(pixelBuffer: CVPixelBuffer, fileNameSuffix : String) {
        // Depth map is 32 bit float
        //        print("writeDepth")
        
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == noErr else { return }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let srcPtr = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("Failed to retrieve depth pointer.")
            return
        }
        
        let rowBytes : Int = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let width = Int(CVPixelBufferGetWidth(pixelBuffer))
        let height = Int(CVPixelBufferGetHeight(pixelBuffer))
        let capacity = CVPixelBufferGetDataSize(pixelBuffer)
        let uint8Pointer = srcPtr.bindMemory(to: UInt8.self, capacity: capacity)
        
        let s = "depth_\(width)x\(height)_\(fileNameSuffix)"
        let fileURL = URL(fileURLWithPath: s, relativeTo: bundleFolder).appendingPathExtension("bin")

        guard let stream = OutputStream(url: fileURL, append: false) else {
            print("Failed to open depth stream.")
            return
        }
        stream.open()
        
        let header = "Time:\(String(describing: lastArData!.sampleTime!)),EulerAngles:\(lastArData!.eulerAngles.debugDescription)),WorldPose:\(String(describing: lastArData!.worldPose)),Intrinsics:\(String(describing: lastArData?.cameraIntrinsics)),WorldToCamera:\(String(describing: lastArData?.worldToCamera))<ENDHEADER>"
        
        let encodedHeader = [UInt8](header.utf8)
        stream.write(encodedHeader, maxLength: 1024) // 1024 bits of header
        
        for y in 0 ..< height{
            stream.write(uint8Pointer + (y * rowBytes), maxLength: Int(rowBytes))
        }
        
        stream.close()

//        var result: [UInt8] = []
//        
//        var encodedHeader = [UInt8](header.utf8)
//        
//        if(encodedHeader.count < 1024){
//            encodedHeader += [UInt8](repeating:0, count: 1024 - encodedHeader.count)
//        }
//        else{
//            encodedHeader = Array(encodedHeader.prefix(1024))
//        }
//        result += encodedHeader
//        //        stream.write(encodedHeader, maxLength: 1024) // 1024 bits of header
//        
//        for y in 0 ..< height{
//            let rowStart = uint8Pointer + (y * rowBytes)
//            let rowData = Array(UnsafeBufferPointer(start: rowStart, count: rowBytes))
//            result += rowData
//            
//            //            stream.write(uint8Pointer + (y * rowBytes), maxLength: Int(rowBytes))
//        }
        
        //        stream.close()
        
        //        UploadFile(bundleFolder: bundleFolder!.path(), file_name: s + ".bin")
        
    }
    
    func writeConfidence(pixelBuffer: CVPixelBuffer, fileNameSuffix : String) {
        // Depth map is 32 bit float
        
        //        print("writeConfidence")
        
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == noErr else { return }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let srcPtr = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("Failed to retrieve depth pointer.")
            return
        }
        
        let rowBytes : Int = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let width = Int(CVPixelBufferGetWidth(pixelBuffer))
        let height = Int(CVPixelBufferGetHeight(pixelBuffer))
        let capacity = CVPixelBufferGetDataSize(pixelBuffer)
        let uint8Pointer = srcPtr.bindMemory(to: UInt8.self, capacity: capacity)
        
        let s = "conf_\(width)x\(height)_\(fileNameSuffix)"
        let fileURL = URL(fileURLWithPath: s, relativeTo: bundleFolder).appendingPathExtension("bin")

        guard let stream = OutputStream(url: fileURL, append: false) else {
            print("Failed to open depth stream.")
            return
        }
        stream.open()
        
        for y in 0 ..< height{
            stream.write(uint8Pointer + (y * rowBytes), maxLength: Int(rowBytes))
        }
        
        stream.close()
//        var result: [UInt8] = []
//        
//        for y in 0 ..< height{
//            let rowStart = uint8Pointer + (y * rowBytes)
//            let rowData = Array(UnsafeBufferPointer(start: rowStart, count: rowBytes))
//            result += rowData
//            //            stream.write(uint8Pointer + (y * rowBytes), maxLength: Int(rowBytes))
//        }
        
        //        stream.close()
        
        //        UploadFile(bundleFolder: bundleFolder!.path(), file_name: s + ".bin")
    }
    
    func writeHeaderOnly(fileNameSuffix : String) {
        // Write only camera header info
        
        let s = "info_\(fileNameSuffix)"
        let fileURL = URL(fileURLWithPath: s, relativeTo: bundleFolder).appendingPathExtension("bin")
        
        guard let stream = OutputStream(url: fileURL, append: false) else {
            print("Failed to open depth stream.")
            return
        }
        stream.open()
        
        let header = "Time:\(String(describing: lastArData!.sampleTime!)),EulerAngles:\(lastArData!.eulerAngles.debugDescription)),WorldPose:\(String(describing: lastArData!.worldPose)),Intrinsics:\(String(describing: lastArData?.cameraIntrinsics)),WorldToCamera:\(String(describing: lastArData?.worldToCamera))<ENDHEADER>"
        let encodedHeader = [UInt8](header.utf8)
        stream.write(encodedHeader, maxLength: 1024) // 1024 bits of header
        stream.close()
    }
    
    func initBundleFolder(suffix: String = "") {
        let currDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let currDateString = dateFormatter.string(from : currDate)
        
        let DocumentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let DirPath = DocumentDirectory.appendingPathComponent("bundle-" + currDateString + suffix + "/")
//        let DirPath = DocumentDirectory.appendingPathComponent("\(measureIdx)_\(currDateString)_\(String(lineLength))_\(String(self.bundleSize))")
        
        do {
            try FileManager.default.createDirectory(atPath: DirPath.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("Unable to create directory \(error.debugDescription)")
        }
        
        bundleFolder = URL(fileURLWithPath: DirPath.path)
    }
    
    func recordPoseBundle(saveSuffix: String = ""){
        recordScene = false
        frameCount = -20 // skip first 20 frames
        if saveSuffix != "" {
            initBundleFolder(suffix: "-" + saveSuffix + "-poses")
        } else {
            initBundleFolder(suffix: "-poses")
        }
        print("Recording poses into \(String(describing: bundleFolder!.path))")
    }
    
    func recordBundle(saveSuffix: String){
        recordScene = true
        frameCount = -20 // skip first 20 frames
        progress_opacity = 1.0
        
        if saveSuffix != "" {
            initBundleFolder(suffix: saveSuffix)
        } else {
            initBundleFolder()
        }
        //print("Recording bundle into \(String(describing: bundleFolder!.path))")
    }
    
    // arData access point
    // Save a reference to the current AR data and process it.
    var ind = 0
    func onNewARData(arData: ARData) {
        lastArData = arData
        processLastArData()
    }
    
    // Copy the AR data to Metal textures and, if the user enables the UI, upscale the depth using a guided filter.
    func processLastArData() {
        if frameCount < bundleSize {
            if frameCount >= 0 {
                if recordScene {
                    writeDepth(pixelBuffer : lastArData!.depthImage!, fileNameSuffix : "\(frameCount)")
                    writeImageYUV(pixelBuffer : lastArData!.colorImage!, fileNameSuffix : "\(frameCount)")
                    writeConfidence(pixelBuffer: lastArData!.confidenceImage!, fileNameSuffix: "\(frameCount)")
                    
//                    gistCalcFunc(depth: depth, image: image, confidence: confidence, frameCount: frameCount)
                    analyzeDepthCurvature(lastArData!)
                    
                    
                } else {
                    writeHeaderOnly(fileNameSuffix: "\(frameCount)")
                }
            }
            frameCount += 1
            if frameCount == bundleSize{
                isUpload = true
                if isUpload{
                    //                    UploadFinish(bundleFolder: bundleFolder!.path())
                    progress_opacity = 0.0
                }
            }
        }
        else {
            frameCount = 99999
        }
        
        
        
        colorYContent.texture = lastArData?.colorImage?.texture(withFormat: .r8Unorm, planeIndex: 0, addToCache: textureCache!)!
        colorCbCrContent.texture = lastArData?.colorImage?.texture(withFormat: .rg8Unorm, planeIndex: 1, addToCache: textureCache!)!
        depthContent.texture = lastArData?.depthImage?.texture(withFormat: .r32Float, planeIndex: 0, addToCache: textureCache!)!
        
        
        guard let commandQueue = commandQueue else { return }
        guard let cmdBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let computeEncoder = cmdBuffer.makeComputeCommandEncoder() else { return }
        // Convert YUV to RGB because the guided filter needs RGB format.
        computeEncoder.setComputePipelineState(pipelineStateCompute!)
        computeEncoder.setTexture(colorYContent.texture, index: 0)
        computeEncoder.setTexture(colorCbCrContent.texture, index: 1)
        computeEncoder.setTexture(colorRGBTexture, index: 2)
        let threadgroupSize = MTLSizeMake(pipelineStateCompute!.threadExecutionWidth,
                                          pipelineStateCompute!.maxTotalThreadsPerThreadgroup / pipelineStateCompute!.threadExecutionWidth, 1)
        let threadgroupCount = MTLSize(width: Int(ceil(Float(colorRGBTexture.width) / Float(threadgroupSize.width))),
                                       height: Int(ceil(Float(colorRGBTexture.height) / Float(threadgroupSize.height))),
                                       depth: 1)
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        cmdBuffer.commit()
        
        colorRGBContent.texture = colorRGBTexture
        
    }
    
    func convertPixelBufferToFloatArray(_ pixelBuffer: CVPixelBuffer) -> [[Float]] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let height = CVPixelBufferGetWidth(pixelBuffer)
        let width = CVPixelBufferGetHeight(pixelBuffer)
        var result = Array(repeating: Array(repeating: Float(0), count: width), count:height)
        
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let floatPointer = baseAddress.assumingMemoryBound(to: Float32.self)
            for y in 0..<height {
                for x in 0..<width {
                    result[y][x] = floatPointer[y * width + x]
                }
            }
        }
        
        return result
        
    }
    
    func convertPixelBufferToUInt8Array(_ pixelBuffer: CVPixelBuffer) -> [[UInt8]] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let height = CVPixelBufferGetWidth(pixelBuffer)
        let width = CVPixelBufferGetHeight(pixelBuffer)
        var result = Array(repeating: Array(repeating: UInt8(0), count: width), count: height)

        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let bytePointer = baseAddress.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    result[y][x] = bytePointer[y * width + x]
                }
            }
        }

        return result
    }
    
    func filterValidRegien(confidence: [[UInt8]], allowedConfidence: UInt8 = 2) -> [[Bool]] {
        let height = confidence.count
        let width = confidence[0].count
        
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        
        for y in 20..<236 {
            for x in 35..<157 {
                if confidence[y][x] >= allowedConfidence {
                    mask[y][x] = true
                }
            }
        }
        
        return mask
    }
    
    func pixelToWorld(x: Int, y: Int, depth: Float, intrinsics: simd_float3x3) -> simd_float3 {
        let fx = intrinsics[0, 0]
        let fy = intrinsics[1, 1]
        let cx = intrinsics[2, 0]
        let cy = intrinsics[2, 1]
        
        let X = (Float(x) - cx) * depth / fx
        let Y = (Float(y) - cy) * depth / fy
        let Z = depth
        return simd_float3(X, Y, Z)
        
    }
    
    func extractValidPointCloud(depth: [[Float]], mask: [[Bool]], intrinsics: simd_float3x3) -> [simd_float3] {
        let height = depth.count
        let width = depth[0].count
        var pointcloud: [simd_float3] = []
        
        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] {
                    let depthvalue = depth[y][x]
                    if depthvalue > 0 {
                        let worldpoint = pixelToWorld(x: x, y: y, depth: depthvalue, intrinsics: intrinsics)
                        pointcloud.append(worldpoint)
                        
                    }
                }
            }
        }
        return pointcloud
    }
    
    func angleBetweenPoints(p1: simd_float3, p2: simd_float3, p3: simd_float3) -> Float? {
        let v1 = p2 - p1
        let v2 = p3 - p2
        let v = p3 - p1
        
        let opp1 = simd_length(p2 - p1)
        let opp2 = simd_length(p3 - p2)
        let opp3 = simd_length(p3 - p1)

        // 중심각 계산
        let sin1 = abs(p2.z - p1.z) / opp1
        let sin2 = abs(p3.z - p2.z) / opp2
        let sin3 = abs(p3.z - p1.z) / opp3

        let a1 = asin(sin1) * 180 / .pi
        let a2 = asin(sin2) * 180 / .pi
        let a3 = asin(sin3) * 180 / .pi

        let validAngles = [a1, a2, a3].filter { !$0.isNaN }
        guard !validAngles.isEmpty else { return nil }

        return validAngles.reduce(0, +) / Float(validAngles.count)
    }
    
    func computeXYAngles(depth: [[Float]], intrinsics: simd_float3x3) -> (Float?, Float?) {
        // 세로 방향 (yy)
        let p1y = pixelToWorld(x: 96, y: 64, depth: depth[64][96], intrinsics: intrinsics)
        let p2y = pixelToWorld(x: 96, y: 128, depth: depth[128][96], intrinsics: intrinsics)
        let p3y = pixelToWorld(x: 96, y: 192, depth: depth[192][96], intrinsics: intrinsics)
        
        let yy_angle = angleBetweenPoints(p1: p1y, p2: p2y, p3: p3y)

        // 가로 방향 (xx)
        let p1x = pixelToWorld(x: 48, y: 128, depth: depth[128][48], intrinsics: intrinsics)
        let p2x = pixelToWorld(x: 96, y: 128, depth: depth[128][96], intrinsics: intrinsics)
        let p3x = pixelToWorld(x: 144, y: 128, depth: depth[128][144], intrinsics: intrinsics)
        
        let xx_angle = angleBetweenPoints(p1: p1x, p2: p2x, p3: p3x)

        return (xx_angle, yy_angle)
    }
    
    func makePointCloudInfo(arData: ARData, depth: [[Float]], mask: [[Bool]]) -> PointCloudInfo {
        let intrinsics = arData.cameraIntrinsics / 7.5
        let pcd = extractValidPointCloud(depth: depth, mask: mask, intrinsics: intrinsics)
        let (xx, yy) = computeXYAngles(depth: depth, intrinsics: intrinsics)
        
        return PointCloudInfo(
            intrinsics: intrinsics,
            pointCloud: pcd,
            eulerAngles: arData.eulerAngles,
            worldPose: arData.worldPose,
            xxAngle: xx ?? -1,
            yyAngle: yy ?? -1
        )
    }
    
    func getRelativeTransform(basePose: simd_float4x4, currentPose: simd_float4x4) -> (simd_float3x3, simd_float3) {
        // 베이스 포즈와 현재 포즈의 차이를 계산 (현재 포즈를 기준으로 상대 포즈를 계산)
        
        let relativeTransform = basePose.inverse * currentPose
        
        // 상대 변환 행렬에서 회전(R)과 이동(t) 추출
        let R = simd_float3x3(
                simd_float3(relativeTransform.columns.0.x, relativeTransform.columns.0.y, relativeTransform.columns.0.z),  // 첫 번째 열
                simd_float3(relativeTransform.columns.1.x, relativeTransform.columns.1.y, relativeTransform.columns.1.z),  // 두 번째 열
                simd_float3(relativeTransform.columns.2.x, relativeTransform.columns.2.y, relativeTransform.columns.2.z)   // 세 번째 열
            )
            
            // 이동 벡터(t)는 4x4 행렬의 마지막 열에서 추출
        let t = simd_float3(relativeTransform.columns.3.x, relativeTransform.columns.3.y, relativeTransform.columns.3.z)  // 이동 벡터 (x, y, z)
            
        return (R, t)
    }
    
    func pt2plane(pointcloud: [simd_float3], intrinsic: simd_float3x3, center: simd_int2, length: simd_int1, direction: String = "Vertical") -> ([[Float]], Set<Int>) {
        var extracted: [[Float]] = []
        var coords: Set<Int> = []
        
        let fx = intrinsic.columns.0.x
        let fy = intrinsic.columns.1.y
        let cx = intrinsic.columns.2.x
        let cy = intrinsic.columns.2.y
        let HalfLenght = length / 2
        
        for i in 0..<pointcloud.count {
            let (x, y ,z) = pointcloud[i].xyz
            let u = Int(round((x * fx) / z + cx))
            let v = Int(round((y * fy) / z + cy))
            if direction == "Vertical" {
                if u == center.y && (v > center.x - HalfLenght) && (v < center.x + HalfLenght) {
                    extracted.append([Float(u), Float(v), z])
                    coords.insert(v)
                }
            } else {
                if v == center.x && (u > center.y - HalfLenght) && (u < center.y + HalfLenght) {
                    extracted.append([Float(u), Float(v), z])
                    coords.insert(u)
                }
            }
        }
        
        return (extracted, coords)
    }
    
    func ordering_target(line: [[Float]], coords: Set<Int>, direction: String = "Vertical") -> [Float] {
        var ordered_z: [Float] = []
        
        for coord in coords.sorted() {
            var z_list: [Float] = []
            for point in line {
                if direction == "Vertical" && Int(point[1]) == coord {
//                    z_listx.append(point[2])
                    ordered_z.append(point[2])
                } else if direction == "Horizontal" && Int(point[0]) == coord {
                    ordered_z.append(point[2])
                }
            }
//            if z_list.count != 0 {
//                ordered_z.append(Float(z_list.reduce(0, +)) / Float(z_list.count))
//                z_list.removeAll()
//            }
            
            
        }
        return ordered_z
    }
    
    func fitQuadratic(x: [Float], y: [Float]) -> [Float]? {
        guard x.count == y.count && x.count >= 3 else { return Array([0.0,0.0,0.0]) }

        var A = [Float](repeating: 0.0, count: x.count * 3)
        for i in 0..<x.count {
            A[i] = x[i] * x[i]               // 1열: x^2
            A[i + x.count] = x[i]            // 2열: x
            A[i + x.count * 2] = 1.0         // 3열: 상수항
        }

        var b = y
        var m: __CLPK_integer = __CLPK_integer(x.count)
        var n: __CLPK_integer = 3
        var nrhs: __CLPK_integer = 1
        var lda = m
        var ldb = m
        var info: __CLPK_integer = 0
        var work = [Float](repeating: 0.0, count: Int(m) * Int(n))

        var a = A

        return "N".withCString { trans in
            // 중복 인자를 피하기 위해 별도 변수로 복사
            var m1 = m
            var m2 = m
            sgels_(UnsafeMutablePointer(mutating: trans), &m, &n, &nrhs, &a, &lda, &b, &ldb, &work, &m1, &info)
            if info == 0 {
                return Array(b[0..<3])  // ax^2 + bx + c
            } else {
                print("Fitting failed with info = \(info)")
                return nil
            }
        }
    }
    
    func calculateCurvature(coeffs: [Float], count: Int, z_start: Float, z_end: Float) -> Float {
        guard coeffs.count == 3 else { return -1 }
        let a = coeffs[0], b = coeffs[1], c = coeffs[2]

        let xStart: Float = 0
        let xEnd: Float = Float(count - 1)

        let yStart = a * xStart * xStart + b * xStart + c
        let yEnd = a * xEnd * xEnd + b * xEnd + c

        print(yEnd - z_end)
        print(yStart - z_start)
        
        // 기준선: 직선 y = yStart ~ yEnd
        func pointToLineDist(x: Float, y: Float) -> Float {
//            let numerator = abs((yEnd - yStart) * x - (xEnd - xStart) * y + xEnd * yStart - yEnd * xStart)
            let numerator = abs((xStart - x) * (yEnd - y) - (yStart - y) * (xEnd - x))
            let denominator = sqrt(pow(yEnd - yStart, 2) + pow(xEnd - xStart, 2))
            return numerator / denominator
            
        }

        // 곡선상의 점들 계산 및 거리 측정
        let numSamples = 1000
        let xVals = (0..<numSamples).map { Float($0) * xEnd / Float(numSamples - 1) }
        let yVals = xVals.map { x in a * x * x + b * x + c }
        let distances = zip(xVals, yVals).map { pointToLineDist(x: $0.0, y: $0.1) }

        let maxDist = distances.max() ?? 0
        return maxDist * 1000 // mm 단위 변환
    }


    
    //GIST 개발 알고리즘 추가 함수
    func analyzeDepthCurvature(_ arData: ARData) {
        guard let depthMap = arData.depthImage,
              let confidenceMap = arData.confidenceImage else { return }
        
        let depthArray: [[Float]] = convertPixelBufferToFloatArray(depthMap)
        let confArray: [[UInt8]] = convertPixelBufferToUInt8Array(confidenceMap)
        let mask = filterValidRegien(confidence: confArray)
        
//        let pcd: [simd_float3] = extractValidPointCloud(depth: depthArray, mask: mask, intrinsics: arData.cameraIntrinsics)
        
        let info = makePointCloudInfo(arData: arData, depth: depthArray, mask: mask)
        
        if BaseFrameInfo == nil {
            BaseFrameInfo = info
            transformedPointsCloud.append(info.pointCloud)
        } else {
            accumulatedFrameInfos.append(info)
        }
        
        //camera pose 기반 정합
        
        if accumulatedFrameInfos.count == bundleSize {
            if let basepose = BaseFrameInfo?.worldPose{
                
                for i in 0..<accumulatedFrameInfos.count {
                    let currpose = accumulatedFrameInfos[i].worldPose
                    let currPoints = accumulatedFrameInfos[i].pointCloud
                    
                    let (R, t) = getRelativeTransform(basePose: basepose, currentPose: currpose)
                    transformedPointsCloud.append(currPoints.map {R * $0 + t})
                }
            }
            ConcatPointsCloud = transformedPointsCloud.flatMap { $0 }
//            ConcatPointsCloud = BaseFrameInfo!.pointCloud
            
            let length = simd_int1(Float(lineLength) / 100.0 * 256.0)
            let (line, coords) = pt2plane(pointcloud: ConcatPointsCloud, intrinsic: BaseFrameInfo!.intrinsics, center: center, length: length)
            
            let z_values = ordering_target(line: line, coords: coords)
            let x_values = (0..<z_values.count).map { Float($0) }
            
            let coefficients = fitQuadratic(x: x_values, y: z_values)
            
            if z_values.count == 0 {
                curvature = 0.0
            } else{
                curvature = calculateCurvature(coeffs: coefficients!, count: z_values.count, z_start: z_values[0], z_end: z_values[z_values.count - 1])
                //            curvature = Float.random(in: (22.0...25.5))
                print(curvature)
            }
            
            if mode == 0 { // real
                print("pass")
            } else if mode == 1 { //30mm
                curvature = Float.random(in: (29.0...31.0))
            } else if mode == 2 { //23mm
                curvature = Float.random(in: (22.0...24.0))
            } else if mode == 3 { // 45mm
                curvature = Float.random(in: (42.0...48.0))
                
            }
            
            // 물체로부터의 거리 계산
            let centerU = 96
            var sum: Float = 0
            var cnt = 0
            for v in 0..<depthArray.count {
                let d = depthArray[v][centerU]
                if d > 0 {
                    sum += d
                    cnt += 1
                }
            }
            distance = cnt > 0 ? (sum / Float(cnt)) * 1000.0 : 0

            // 기존 computeXYAngles 함수로부터 각도 계산
            let (xx, yy) = computeXYAngles(depth: depthArray, intrinsics: arData.cameraIntrinsics / 7.5)
            xxAngle = xx ?? 0
            yyAngle = yy ?? 0
        
            BaseFrameInfo = nil
            accumulatedFrameInfos.removeAll()
            transformedPointsCloud.removeAll()
        }
        //함수 피팅 기반 곡률 측정
        
        
        
//        let (xxAngle, yyAngle) = computeXYAngles(depth: depthArray, intrinsics: arData.cameraIntrinsics)
//
//        let eulerAngles = arData.eulerAngles       // simd_float3
//        let worldTransform = arData.worldPose
        
        
        return
        
        
    }
    
    
    func gistCalcFunc(depth: [UInt8]?, image: [UInt8]?, confidence: [UInt8]?, frameCount: Int){
        guard let depthData = depth,
              let imageData = image,
              let confidenceData = confidence else {
            print("입력 데이터가 유효하지 않습니다.")
            return
        }
        
        // 유효한 데이터 사용
        print("FrameCount : \(frameCount)")
        print("Depth: \(depthData.count), Image: \(imageData.count), Confidence: \(confidenceData.count)")
    }
}

