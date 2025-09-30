//
//  MeasureState.swift
//  LiDAR Scanner-ForGIST
//
//  Created by visualai on 6/26/25.
//

import Foundation
import Combine

// 여러 뷰가 함께 쓰는 측정 상태. 값이 바뀌면 연결된 UI가 자동 갱신
class MeasureState: ObservableObject {
    @Published var mode: Int = 0
    @Published var showModeLabel: Bool = false
}
