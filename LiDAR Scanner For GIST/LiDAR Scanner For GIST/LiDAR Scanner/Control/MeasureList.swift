//
//  MeasureList.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/09/05.
//

import SwiftUI

struct Point: Identifiable, Hashable{
    let id: UUID = UUID()
    var check: Bool
    var idx: String
    var measure_idx: String
    var ship_no: String
    var block: String
    var panel: String
    var process: String
    var am_ref: String
    var transform: String
    var x_pos: String
    var y_pos: String
    var z_pos: String
    var frame: String
    var longi: String
}

struct ListRow: View {
    let check: Bool
    let idx: String
    let measure_idx:String
    let ship_no: String
    let block: String
    let panel: String
    let process: String
    let am_ref: String
    var transform: String
    let x_pos: String
    let y_pos: String
    let z_pos: String
    var frame: String
    let longi: String
    
    
    
    var body: some View {
        var header = "[\(measure_idx)] \(process)"
        //var text = "   X \(x_pos) Y \(y_pos) Z \(z_pos)"
        var text = "PANEL  [\(panel)]"
        var text2 = "FRMAE [\(frame)]"
        var text3 = "LONGI [\(longi)]"
        var text4 = "\(transform)"
        var text5 = "\(measure_idx) [\(frame) \(longi)]"
        
        HStack(){
            VStack(alignment: HorizontalAlignment.leading) {
                HStack{
                    if check {
                        Text("✔︎").bold()
                            .foregroundColor(.green)
                            
                    } else {
                        Text(" ").bold()
                    }
                    
                    Text(text5)
                        .font(.system(size: 14))
                    
//                    if(process.contains("PE")){
//                        Text(header).bold()
//                            .font(.system(size: 14))
//                            .foregroundColor(Color(red: 235/255, green: 131/255, blue: 23/255))
//                    }
//                    else if(process.contains("탑재")){
//                        Text(header).bold()
//                            .font(.system(size: 14))
//                            .foregroundColor(Color(red: 94/255, green: 195/255, blue: 222/255))
//                    }
//                    else if(process.contains("내업")){
//                        Text(header).bold()
//                            .font(.system(size: 14))
//                            .foregroundColor(Color(red: 255/255, green: 241/255, blue: 0/255))
//                    }
//                    else if(process.contains("선행의장")){
//                        Text(header).bold()
//                            .font(.system(size: 14))
//                            .foregroundColor(Color(red: 216/255, green: 100/255, blue: 162/255))
//                    }
                    
                }
//                VStack(alignment: HorizontalAlignment.leading){
//                    Text(text)
//                        .font(.system(size: 14))
//            
//                    Text(text2)
//                        .font(.system(size: 14))
//                    
//                    Text(text3)
//                        .font(.system(size: 14))
//                }
            }
            
            
            if(transform.count > 0){
                HStack(alignment: VerticalAlignment.center){
                    Divider()
                        .frame(width: 15)
                    VStack(){
                        Text("측정값")
                            .font(.system(size: 16))
                        
                        Text(text4)
                            .font(.system(size: 14))
                            .bold()
                    }
                    
                }
            }
        }
        
    }
}


struct MeasureListView: View {
    @State private var isInit: Bool = false
    @State private var points : [Point] = []
    @State private var current_idx = -1
    @ObservedObject var measure: MeasurePoint = MeasurePoint.measure
    
    init(){
        measure.LoadRestApi()
        setPoint(done_idx: "")
    }
    
    func setPoint(done_idx: String){
        var cnt = 0
        
        for objJson in measure.points{
            let jsonStr = measure.getJsonString(jsonObject: objJson)
            let jsonDic = measure.getJsonDictionary(jsonString: jsonStr)
            
            var m_pt: Point
            var frame = jsonDic["FRAME"]!
            var longi = jsonDic["LONGI"]!
            
            if(frame.contains("+")){
                var idx: Int = frame.distance(from: frame.startIndex, to: frame.firstIndex(of: "+")!)
                
                let startIndex = frame.index(frame.startIndex, offsetBy: 0)// 사용자지정 시작인덱스
                let endIndex = frame.index(frame.startIndex, offsetBy: idx)// 사용자지정 끝인덱스
                frame = String(frame[startIndex ..< endIndex])
                
            }
            
            if(longi.contains("+")){
                var idx: Int = longi.distance(from: longi.startIndex, to: longi.firstIndex(of: "+")!)
                
                let startIndex = longi.index(longi.startIndex, offsetBy: 0)// 사용자지정 시작인덱스
                let endIndex = longi.index(longi.startIndex, offsetBy: idx)// 사용자지정 끝인덱스
                longi = String(longi[startIndex ..< endIndex])
            }
            
            if(current_idx > -1){
                if(cnt == current_idx){
                    m_pt = Point(check: true, idx: jsonDic["IDX"]!, measure_idx: jsonDic["MEASURE_IDX"]!, ship_no: jsonDic["SHIP_NO"]!, block: jsonDic["BLOCK"]!, panel: jsonDic["PANEL"]!,
                                 process: jsonDic["PROCESS"]!, am_ref: jsonDic["AM_REF"]!, transform: jsonDic["TRANSFORM"]!, x_pos: jsonDic["X_POS"]!, y_pos: jsonDic["Y_POS"]!, z_pos: jsonDic["Z_POS"]!,
                                frame: frame, longi: longi)
                    measure.current_idx = jsonDic["IDX"]!
                }
                else{
                    m_pt = Point(check: false, idx: jsonDic["IDX"]!, measure_idx: jsonDic["MEASURE_IDX"]!, ship_no: jsonDic["SHIP_NO"]!, block: jsonDic["BLOCK"]!, panel: jsonDic["PANEL"]!,
                                 process: jsonDic["PROCESS"]!, am_ref: jsonDic["AM_REF"]!, transform: jsonDic["TRANSFORM"]!, x_pos: jsonDic["X_POS"]!, y_pos: jsonDic["Y_POS"]!, z_pos: jsonDic["Z_POS"]!,
                                 frame: frame, longi: longi)
                }
            }
            else{
                if(cnt == 0){
                    m_pt = Point(check: true, idx: jsonDic["IDX"]!, measure_idx: jsonDic["MEASURE_IDX"]!, ship_no: jsonDic["SHIP_NO"]!, block: jsonDic["BLOCK"]!, panel: jsonDic["PANEL"]!,
                                 process: jsonDic["PROCESS"]!, am_ref: jsonDic["AM_REF"]!, transform: jsonDic["TRANSFORM"]!, x_pos: jsonDic["X_POS"]!, y_pos: jsonDic["Y_POS"]!, z_pos: jsonDic["Z_POS"]!,
                                frame: frame, longi: longi)
                    measure.current_idx = jsonDic["IDX"]!
                }
                else{
                    m_pt = Point(check: false, idx: jsonDic["IDX"]!, measure_idx: jsonDic["MEASURE_IDX"]!, ship_no: jsonDic["SHIP_NO"]!, block: jsonDic["BLOCK"]!, panel: jsonDic["PANEL"]!,
                                 process: jsonDic["PROCESS"]!, am_ref: jsonDic["AM_REF"]!, transform: jsonDic["TRANSFORM"]!, x_pos: jsonDic["X_POS"]!, y_pos: jsonDic["Y_POS"]!, z_pos: jsonDic["Z_POS"]!,
                                 frame: frame, longi: longi)
                }
            }
            
            
            if(m_pt.idx != done_idx){
                points.append(m_pt)
            }
            
            cnt+=1
        }
    }
    
    func getCheckPoint() -> String{
        return measure.current_idx
    }
    
    func getCheckTransform() -> String{
        let current = Int(measure.current_idx)
        let transform =  self.points[current!].transform
        
        
        return transform
    }
    
    func refreshAct(){
        points.removeAll()
        
    }
    
    var body: some View {
        let refreshable = CustomRefresher()
        
        if(!DesignInfo.SHIP_NO.isEmpty){
            Text("[\(DesignInfo.SHIP_NO)] [\(DesignInfo.BLOCK_NO)] [\(DesignInfo.PROCESS)]")
                .frame(alignment: .leading)
                .bold()
        }
        List {
            Section("계측목록"){
                ForEach(0..<self.points.count, id:\.self){ idx in
                    var m_pt = self.points[idx]
                    Button(action:{
                        var i = 0
                        while i < self.points.count{
                            self.points[i].check = false
                            i+=1
                        }
                        
                        current_idx = idx
                        self.points[idx].check.toggle();
                        measure.current_idx = self.points[idx].idx
                    })
                    {
                        ListRow(
                            check: self.points[idx].check,
                            idx: self.points[idx].idx,
                            measure_idx: self.points[idx].measure_idx,
                            ship_no: self.points[idx].ship_no,
                            block: self.points[idx].block,
                            panel: self.points[idx].panel,
                            process: self.points[idx].process,
                            am_ref: self.points[idx].am_ref,
                            transform: self.points[idx].transform,
                            x_pos: self.points[idx].x_pos,
                            y_pos: self.points[idx].y_pos,
                            z_pos: self.points[idx].z_pos,
                            frame: self.points[idx].frame,
                            longi: self.points[idx].longi
                        )
                    }
                }
            }
        }
        .task({
            points.removeAll()
            await measure.LoadRestApiAsync(isWait: false)
            setPoint(done_idx: "")
        })
        .onAppear{
            Task{
                await measure.LoadRestApiAsync(isWait: false)
                setPoint(done_idx: "")
            }
        }
        .edgesIgnoringSafeArea([.bottom])
        .refreshable {
            points.removeAll()
            await measure.LoadRestApiAsync(isWait: false)
            setPoint(done_idx: "")
        }
        
        HStack(){
            refreshable
                .refreshable {
                    points.removeAll()
                    await measure.LoadRestApiAsync(isWait: false)
                    setPoint(done_idx: "")
                    print(current_idx)
                }
            
            CustomRefresher2()
                .refreshable {
                    Task{
                        if(getCheckPoint() == nil || getCheckPoint().count < 1){
                            return
                        }
                        
                        DesignInfo.updateStatus(idx: getCheckPoint(), status: "done")
                        current_idx = -1
                        await measure.LoadRestApiAsync(isWait: true)
                        self.points.removeAll()
                        setPoint(done_idx: getCheckPoint())
                    }
                }
        }
    }
}

struct CustomRefresher: View{
    @Environment(\.refresh) private var refresh
    
    var body: some View{
        Group{
            if let refresh = refresh{
                RoundButton(color: .white, text: "새로고침", fontSize: 16, icon:nil, action: {
                    Task{
                        await refresh()
                    }
                })
            }
        }
    }
}

struct CustomRefresher2: View{
    @Environment(\.refresh) private var refresh
    
    var body: some View{
        Group{
            if let refresh = refresh{
                RoundButton(color: .white, text: "DONE", fontSize: 16, icon:nil, action: {
                    Task{
                        await refresh()
                    }
                })
            }
        }
    }
}
