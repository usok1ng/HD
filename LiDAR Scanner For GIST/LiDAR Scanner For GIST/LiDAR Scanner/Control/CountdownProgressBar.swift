//
//  ProgressBar.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/09/04.
//

import SwiftUI

class CountdownProgressBar: UIView {
    private var timer = Timer()
    private var remainingTime = 0.0
    private var duration = 10.0
    
    private lazy var remainingTimeLabel: UILabel = {
        let remainingLabel = UILabel(frame: CGRect(x: 0,
                                                   y: 0,
                                                   width: bounds.width,
                                                   height: bounds.height))
        remainingLabel.font = UIFont.boldSystemFont(ofSize: 32)
        remainingLabel.textAlignment = .center
        return remainingLabel
    }()
    
    private lazy var foregroundLayer: CAShapeLayer = {
        let foregroundLayer = CAShapeLayer()
        foregroundLayer.lineWidth = 10
        foregroundLayer.strokeColor = UIColor.blue.cgColor
        foregroundLayer.fillColor = UIColor.clear.cgColor
        foregroundLayer.lineCap = .round
        foregroundLayer.strokeEnd = 0
        return foregroundLayer
    }()

    private lazy var backgroundLayer: CAShapeLayer = {
        let backgroundLayer = CAShapeLayer()
        backgroundLayer.lineWidth = 10
        backgroundLayer.strokeColor = UIColor.lightGray.cgColor
        backgroundLayer.lineCap = .round
        backgroundLayer.fillColor = UIColor.clear.cgColor
        return backgroundLayer
    }()
    
    private lazy var pulseLayer: CAShapeLayer = {
        let pulseLayer = CAShapeLayer()
        pulseLayer.lineWidth = 10
        pulseLayer.strokeColor = UIColor.lightGray.cgColor
        pulseLayer.lineCap = .round
        pulseLayer.fillColor = UIColor.clear.cgColor
        return pulseLayer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadLayers()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadLayers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.pulseLayer.frame = self.bounds
        self.backgroundLayer.frame = self.bounds
        self.foregroundLayer.frame = self.bounds
        self.remainingTimeLabel.frame = self.bounds
        
        let centerPoint = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
        let circularPath = UIBezierPath(arcCenter: centerPoint,
                                        radius: self.bounds.width / 2,
                                        startAngle: -CGFloat.pi / 2,
                                        endAngle: (2 * CGFloat.pi) - (CGFloat.pi / 2),
                                        clockwise: true)
        self.pulseLayer.path = circularPath.cgPath
        self.backgroundLayer.path = circularPath.cgPath
        self.foregroundLayer.path = circularPath.cgPath
    }
    
    private func loadLayers() {
        self.layer.addSublayer(self.pulseLayer)
        self.layer.addSublayer(self.backgroundLayer)
        self.layer.addSublayer(self.foregroundLayer)
        self.addSubview(self.remainingTimeLabel)
    }
    
    private func animateForegroundLayer() {
        let foregroundAnimation = CABasicAnimation(keyPath: "strokeEnd")
        foregroundAnimation.fromValue = 0
        foregroundAnimation.toValue = 1
        foregroundAnimation.duration = duration
        foregroundAnimation.fillMode = .forwards
        foregroundAnimation.isRemovedOnCompletion = false
        foregroundAnimation.delegate = self
        
        foregroundLayer.add(foregroundAnimation, forKey: "foregroundAnimation")
    }
    
    private func animatePulseLayer() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.2
        
        let pulseOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        pulseOpacityAnimation.fromValue = 0.8
        pulseOpacityAnimation.toValue = 0.0
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [pulseAnimation, pulseOpacityAnimation]
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animationGroup.duration = 1.0
        animationGroup.repeatCount = Float.infinity
        
        pulseLayer.add(animationGroup, forKey: "pulseAnimation")
    }
    
    private func beginAnimation() {
        animateForegroundLayer()
        animatePulseLayer()
    }
    
    @objc
    func handleTimerTick() {
        remainingTime -= 1

        if remainingTime < 0 {
            remainingTime = 0
            pulseLayer.removeAllAnimations()
            timer.invalidate()
        }
        
        self.remainingTimeLabel.text = "\(self.remainingTime)"
        print("remainingTime ::  \(self.remainingTime) ")
        
//        DispatchQueue.main.async() {
//            self.remainingTimeLabel.text = "\(self.remainingTime)"
//            print("remainingTime ::  \(self.remainingTime) ")
//        }
    }
    
    func startCountDown(duration: Double) {
        
        self.duration = duration
        remainingTime = duration
        remainingTimeLabel.text = "\(remainingTime)"
        timer.invalidate()
        timer = Timer()
        timer = Timer.scheduledTimer(timeInterval: 1,
                                     target: self,
                                     selector: #selector(handleTimerTick),
                                     userInfo: nil,
                                     repeats: true)
        
        beginAnimation()
    }
    
}

extension CountdownProgressBar: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        pulseLayer.removeAllAnimations()
        timer.invalidate()
    }
}

struct CountdownProgressView: UIViewRepresentable{
    var view = CountdownProgressBar()
    
    func makeUIView(context: Context) -> some UIView {
        view.startCountDown(duration: 100)
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
    
    func run(){
//        view.animationDidStop(CAAnimation(), finished: true)
//        view.layer.removeAllAnimations()
        view.startCountDown(duration: 1)
    }
}

#Preview {
    CountdownProgressBar()
}
