//
//  SimpleLabel.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/09/04.
//

import SwiftUI

class SimpleLabel: UIView{
    private var displayText = "";
    
    private lazy var label: UILabel = {
        let remainingLabel = UILabel(frame: CGRect(x: 0,
                                                   y: 0,
                                                   width: 100,
                                                   height: 80))
        remainingLabel.font = UIFont.boldSystemFont(ofSize: 32)
        remainingLabel.textAlignment = .center
        return remainingLabel
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadLayers()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadLayers()
    }
    
    private func loadLayers() {
        self.addSubview(self.label)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.label.frame = self.bounds
    }
    
    func setText(text: String){
        displayText = text
        self.label.text = "\(text)"
    }
    
    func getText() -> String{
        return displayText
    }
}

class SimpleLabelController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let SimpleLabelView:SimpleLabel = SimpleLabel(frame:view.frame)
    }
}


struct SimpleLabelView: UIViewRepresentable {
    var view = SimpleLabel()
    var displayText = ""
    
    init(text: String) {
        self.displayText = text
    }
    
    func makeUIView(context: Context) -> some UIView {
        view.setText(text: self.displayText)
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
    
    func setText(text: String){
        let current = CGFloat((view.getText() as NSString).floatValue)
        let val = CGFloat((text as NSString).floatValue)
        print("current ::  \(current) , val :: \(val)")
        var result = current + val
        if(result < 1){
            result = 0
        }
        else if(result > 99){
            result = 100
        }
        
        view.setText(text: String(describing: result))
    }
    
    func getText() -> String{
        return view.getText()
    }
}

#Preview {
    SimpleLabel()
}
