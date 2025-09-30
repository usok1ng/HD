//
//  icp_lib.hpp
//  LiDAR Scanner-ForGIST
//
//  Created by visualai on 5/26/25.
//

#ifndef icp_lib_hpp
#define icp_lib_hpp

#include <stdio.h>

#pragma once
#include <vector>
#include <array>

extern "C" {
    struct Point3f {
        float x, y, z;
    };

    struct ICPResult {
        Point3f* alignedPoints;
        int count;
        float transformation[16]; // 4x4 row-major
    };

    ICPResult run_icp(Point3f* source, int source_count,
                      Point3f* target, int target_count);
}

#endif /* icp_lib_hpp */
