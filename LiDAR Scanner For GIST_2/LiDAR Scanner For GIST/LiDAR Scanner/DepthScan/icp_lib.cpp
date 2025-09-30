//
//  icp_lib.cpp
//  LiDAR Scanner-ForGIST
//
//  Created by visualai on 5/26/25.
//

#include "icp_lib.hpp"
#include <Eigen/Dense>
#include <open3d/Open3D.h>

// run_icp c++ 구현 코드 (c++의 open3D와 Eigen lib을 받아 구현하였기에 필요한 코드입니다.)
// .h 파일은 swift에서 호출하기 위한 공개 헤더입니다.
// .hpp 파일은 c++ 선언용입니다.

using namespace open3d;
using namespace std;

ICPResult run_icp(Point3f* source, int source_count, Point3f* target, int target_count) {
    geometry::PointCloud src, tgt;
    for (int i = 0; i < source_count; ++i)
        src.points_.emplace_back(source[i].x, source[i].y, source[i].z);
    for (int i = 0; i < target_count; ++i)
        tgt.points_.emplace_back(target[i].x, target[i].y, target[i].z);

    auto result = pipelines::registration::RegistrationICP(
        src, tgt, 0.05, Eigen::Matrix4d::Identity(),
        pipelines::registration::TransformationEstimationPointToPoint()
    );

    ICPResult res;
    res.count = (int)result.transformation_.rows();
    auto aligned = std::make_unique<Point3f[]>(src.points_.size());

    geometry::PointCloud transformed = src.Transform(result.transformation_);

    for (size_t i = 0; i < transformed.points_.size(); ++i) {
        const auto& p = transformed.points_[i];
        aligned[i] = { (float)p(0), (float)p(1), (float)p(2) };
    }

    memcpy(res.transformation, result.transformation_.data(), sizeof(float) * 16);
    res.alignedPoints = aligned.release();  // Ownership to caller
    return res;
}
