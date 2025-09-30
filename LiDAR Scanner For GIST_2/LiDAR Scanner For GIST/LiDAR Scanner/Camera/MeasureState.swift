//
//  MeasureState.swift
//  LiDAR Scanner-ForGIST
//
//  Created by visualai on 6/26/25.
//

import Foundation
import Combine

// ���� �䰡 �Բ� ���� ���� ����. ���� �ٲ�� ����� UI�� �ڵ� ����
class MeasureState: ObservableObject {
    @Published var mode: Int = 0
    @Published var showModeLabel: Bool = false
}
