//
//  CurvatureTest.swift
//  LiDAR Scanner-ForGIST
//
//  Created by visualai on 6/2/25.
//

// 오프라인 테스트용으로 "존재만 하는" 파일입니다. 기기없이 오프라인에서 Test하는 코드라고 생각하시면 됩니다. (맨 아래 코드 주석 처리되어있습니다.)

import Foundation
import simd
import CoreVideo

struct DepthData {
    var depthMap: [[Float]]
    var confidenceMap: [[UInt8]]
    var cameraIntrinsics: simd_float3x3
    var worldPose: simd_float4x4
    var eulerAngles: simd_float3
}

func readHeader(from data: Data) -> (simd_float3x3, simd_float4x4, simd_float3) {
    guard let headerStr = String(data: data.prefix(1024), encoding: .utf8) else {
        fatalError("Failed to parse header string")
    }

    func extract<T: LosslessStringConvertible>(_ key: String, count: Int) -> [T] {
        guard let range = headerStr.range(of: key) else { return [] }
        let values = headerStr[range.upperBound...]
            .split(separator: "<")[0]
            .split(separator: ",")
            .prefix(count)
            .compactMap { T($0.trimmingCharacters(in: .whitespaces)) }
        return Array(values)
    }

    let euler: [Float] = extract("EulerAngles:SIMD3<Float>", count: 3)
    let pose: [Float] = extract("WorldPose:simd_float4x4", count: 16)
    let intr: [Float] = extract("Intrinsics:Optionalsimd_float3x3", count: 9)

    return (
        simd_float3x3(rows: [
            SIMD3(intr[0], intr[1], intr[2]),
            SIMD3(intr[3], intr[4], intr[5]),
            SIMD3(intr[6], intr[7], intr[8])
        ]),
        simd_float4x4(columns: (
            SIMD4(pose[0], pose[1], pose[2], pose[3]),
            SIMD4(pose[4], pose[5], pose[6], pose[7]),
            SIMD4(pose[8], pose[9], pose[10], pose[11]),
            SIMD4(pose[12], pose[13], pose[14], pose[15])
        )),
        SIMD3(euler[0], euler[1], euler[2])
    )
}

func loadFloat32Image(from url: URL) -> [[Float]] {
    let data = try! Data(contentsOf: url)
    let floats = data.dropFirst(1024).withUnsafeBytes {
        Array(UnsafeBufferPointer<Float>(start: $0.baseAddress!.assumingMemoryBound(to: Float.self),
                                         count: 256 * 192))
    }
    var image = Array(repeating: Array(repeating: Float(0), count: 192), count: 256)
    for y in 0..<192 {
        for x in 0..<256 {
            image[x][191 - y] = floats[y * 256 + x]  // flip vertically
        }
    }
    return image
}

func loadUInt8Image(from url: URL) -> [[UInt8]] {
    let data = try! Data(contentsOf: url)
    let bytes = Array(data.dropFirst(1024))
    var image = Array(repeating: Array(repeating: UInt8(0), count: 192), count: 256)
    for y in 0..<192 {
        for x in 0..<256 {
            image[x][191 - y] = bytes[y * 256 + x]
        }
    }
    return image
}

func loadBinFiles(from folder: URL) -> [DepthData] {
    let fileManager = FileManager.default
    let contents = try! fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)

    let depthFiles = contents.filter { $0.lastPathComponent.hasPrefix("depth") && $0.pathExtension == "bin" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    let confFiles  = contents.filter { $0.lastPathComponent.hasPrefix("conf") && $0.pathExtension == "bin" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    let infoFiles  = contents.filter { $0.lastPathComponent.hasPrefix("info") && $0.pathExtension == "bin" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

    var frames: [DepthData] = []
    for i in 0..<min(depthFiles.count, confFiles.count, infoFiles.count) {
        let headerData = try! Data(contentsOf: infoFiles[i])
        let (intrinsics, worldPose, eulerAngles) = readHeader(from: headerData)
        let depth = loadFloat32Image(from: depthFiles[i])
        let conf  = loadUInt8Image(from: confFiles[i])
        frames.append(DepthData(
            depthMap: depth,
            confidenceMap: conf,
            cameraIntrinsics: intrinsics,
            worldPose: worldPose,
            eulerAngles: eulerAngles
        ))
    }
    return frames

    // depth_*.bin, conf_*.bin, info_*.bin 파일을 정렬하여 로드
    // header 파싱 및 데이터 변환 기능 구현 필요 (Python의 load_depth 함수와 유사)

}
func analyzeDepthCurvature(data: DepthData) {
    print("hello")
}


func TestCurvature() {
    
    let bundlePath = URL(fileURLWithPath: "/Users/visualai/Desktop/data/_20241014150159_60_15")
    
    let frames = loadBinFiles(from: bundlePath)
    
    for frame in frames {
        print("hello")
        analyzeDepthCurvature(data: frame)
    }
}



//TestCurvature()
