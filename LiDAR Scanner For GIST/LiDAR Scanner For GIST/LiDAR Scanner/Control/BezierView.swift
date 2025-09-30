//
//  BezierView.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/09/03.
//

import SwiftUI


class BezierLine: UIView {
    private var total_width = 0.0
    private var total_height = 0.0
    private var unit_val = 0.0
    private var current_gap = 0.0
    private var total_val = 100
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadLayers()
    }
    
    override func draw(_ rect: CGRect) {
        //이 곳에서 그리기가 진행됩니다.
        
    }
    
    private lazy var underLayer: CAShapeLayer = {
        let underLayer = CAShapeLayer()
        underLayer.lineWidth = 5
        underLayer.strokeColor = UIColor.red.cgColor
        underLayer.fillColor = UIColor.clear.cgColor
        underLayer.lineCap = .square
        //foregroundLayer.strokeEnd = 0
        return underLayer
    }()
    
    private lazy var upLayer: CAShapeLayer = {
        let upLayer = CAShapeLayer()
        upLayer.lineWidth = 5
        upLayer.strokeColor = UIColor.red.cgColor
        upLayer.fillColor = UIColor.clear.cgColor
        upLayer.lineCap = .square
        
        return upLayer
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        total_height = self.bounds.height
        unit_val = total_height / 100
        
        self.underLayer.frame = self.bounds
        self.upLayer.frame = self.bounds
        
        setLinePath(gap: 0)
    }
    
    func getCurrentVal() -> Int{
        return total_val
    }
    
    func setLinePath(gap: CGFloat){
        total_val = total_val + Int(gap)
        let resize_val = abs(((100 - CGFloat(total_val)) / 2) * unit_val)
        
        let centerPoint = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
        let underPath = UIBezierPath()
        let upPath = UIBezierPath()
        
        underPath.lineWidth = 5
        underPath.lineJoinStyle = .round
        underPath.move(to: CGPoint(x: centerPoint.x, y: centerPoint.y))
        
        upPath.lineWidth = 5
        upPath.lineJoinStyle = .round
        upPath.move(to: CGPoint(x: centerPoint.x, y: centerPoint.y))
        
        if(total_val < 0){
            total_val = 0
            
            underPath.addLine(to: CGPoint(x: centerPoint.x , y: self.bounds.midY))
            upPath.addLine(to: CGPoint(x:  centerPoint.x , y: self.bounds.midY))
            
        }
        else if(total_val > 99){
            total_val = 100

            underPath.addLine(to: CGPoint(x: self.bounds.midX , y: self.bounds.minY))
            upPath.addLine(to: CGPoint(x:  self.bounds.midX , y: self.bounds.maxY))

            current_gap = 0
        }
        else{
            underPath.addLine(to: CGPoint(x: self.bounds.midX , y: self.bounds.minY + resize_val))
            upPath.addLine(to: CGPoint(x:  self.bounds.midX, y: self.bounds.maxY - resize_val))
 
            current_gap = current_gap + (resize_val)
        }
          
        UIColor.red.set() // 색상 변경
        underPath.stroke()
        
        self.underLayer.path = underPath.cgPath
        self.upLayer.path = upPath.cgPath
        print("current_gap ::  \(self.current_gap) , total_val :: \(self.total_val)")
    }
    
    func animateRightLayer() {
        let rightAnimation = CABasicAnimation(keyPath: "strokeEnd")
        rightAnimation.fromValue = 0
        rightAnimation.toValue = 1
        //rightAnimation.duration = 0.1
        rightAnimation.fillMode = .forwards
        rightAnimation.isRemovedOnCompletion = false
        rightAnimation.delegate = self
        
        //rightLayer.add(rightAnimation, forKey: "rightAnimation")
    }
    
    func animateLeftLayer() {
        let leftAnimation = CABasicAnimation(keyPath: "strokeEnd")
        leftAnimation.fromValue = 0
        leftAnimation.toValue = 1
        //leftAnimation.duration = 0.1
        leftAnimation.fillMode = .forwards
        leftAnimation.isRemovedOnCompletion = false
        leftAnimation.delegate = self
        
        //leftLayer.add(leftAnimation, forKey: "leftAnimation")
    }
    
    private func loadLayers() {
        self.layer.addSublayer(self.underLayer)
        self.layer.addSublayer(self.upLayer)
    }
    
}

extension BezierLine: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
//        pulseLayer.removeAllAnimations()
//        timer.invalidate()
    }
}

class BezierViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let bezierView:BezierLine = BezierLine(frame:view.frame)
    }
}

struct BezierLineView: UIViewRepresentable{
    var view = BezierLine()
    
    func makeUIView(context: Context) -> some UIView {
        view.animateRightLayer()
        view.animateLeftLayer()
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
    
    func resizeLine(val: CGFloat){
        view.setLinePath(gap: val)
        
        view.animateRightLayer()
        view.animateLeftLayer()
    }
    
    func getCurrentVal() -> Int{
        return view.getCurrentVal()
    }
    
    
}
