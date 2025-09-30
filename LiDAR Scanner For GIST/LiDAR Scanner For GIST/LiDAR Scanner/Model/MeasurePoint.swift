//
//  MeasurePoint.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/09/06.
//

import Foundation

class MeasurePoint: ObservableObject{
    var _url_path = "http://10.150.232.54:3230/api/Measure"
    //var _url_path = "http://witsoft.iptime.org:3230/api/Measure"
    
    static let measure = MeasurePoint()
    @Published var points : [Any] = []
    var current_idx = ""
    
    init(){
        //LoadRestApi()
    }
    
    func LoadRestApi(){
        //var urlComponents = URLComponents(string: "http://witsoft.iptime.org:3230/api/Measure")!
        //var urlComponents = URLComponents(string: "http://10.150.232.54:3230/api/Measure")!
        //urlComponents.queryItems = [
        //    URLQueryItem(name: "SHIP_NO", value: ""),
        //    URLQueryItem(name: "BLOCK", value: "")
        //]
          
        var restUrl = _url_path
        if(DesignInfo.SHIP_NO.count < 1){
            return
        }
        
        restUrl = _url_path + "?ship_no=" + DesignInfo.SHIP_NO + "&block=" + DesignInfo.BLOCK_NO + "&process="
            + DesignInfo.PROCESS
        
        print(restUrl)
        
        //var urlComponents = URLComponents(string: "http://witsoft.iptime.org:3230/api/Measure")!
        var urlComponents = URLComponents(string: restUrl)!
        
        
        guard let url = urlComponents.url else { // API의 url을 넣어주면 된다
            return
        }
        
        // URLRequest 인스턴스 생성
        var request = URLRequest(url: url)
        request.httpMethod = "GET" // 요청에 사용할 HTTP 메서드 설정
        
        // HTTP 헤더 설정
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var jsonArr : [Any] = []
        
        // URLSession을 사용하여 요청 수행
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data,
                  let str = String(data: data, encoding:.utf8) else { return }

            DispatchQueue.main.async {
                self.points = self.getJsonArray(jsonString: str)
            }
            
        }.resume()
    }
    
    ///RestApi 서버에서, DB 에 등록된 측정 포인트 정보를 가져온다.
    func LoadRestApiAsync(isWait: Bool) async {
        var restUrl = _url_path
        if(DesignInfo.SHIP_NO.count < 1){
            return
        }
        
        if(isWait){
            Thread.sleep(forTimeInterval: 1)
        }
        
        restUrl = _url_path + "?ship_no=" + DesignInfo.SHIP_NO + "&block=" + DesignInfo.BLOCK_NO + "&process="
            + DesignInfo.PROCESS
        
        print(restUrl)
        
        //var urlComponents = URLComponents(string: "http://witsoft.iptime.org:3230/api/Measure")!
        var urlComponents = URLComponents(string: restUrl)!
        
        
        guard let url = urlComponents.url else { // API의 url을 넣어주면 된다
            return
        }
        
        // URLRequest 인스턴스 생성
        var request = URLRequest(url: url)
        request.httpMethod = "GET" // 요청에 사용할 HTTP 메서드 설정
        
        // HTTP 헤더 설정
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var jsonArr : [Any] = []
        
        // URLSession을 사용하여 요청 수행
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data,
                  let str = String(data: data, encoding:.utf8) else { return }

            DispatchQueue.main.async {
                self.points = self.getJsonArray(jsonString: str)
            }
            
        }.resume()
    }

    func setJsonResult(array: [Any]){
        points = array
        //print(points.count)
    }

    
    
    func getJsonObject(jsonString: String) -> Any? {
        if let data = jsonString.data(using: .utf8) {
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
                return jsonObject
            }
        }
        return nil
    }
        
    func getJsonArray(jsonString: String) -> [Any] {
        if let data = jsonString.data(using: .utf8) {
            if let jsonAaray = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any] {
                return jsonAaray
            }
        }
        return []
    }

    func getJsonDictionary(jsonString: String) -> [String: String] {
        if let data = jsonString.data(using: .utf8) {
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                return jsonObject
            }
        }
        return [:]
    }

    func getJsonString(jsonObject: Any ) -> String {
        if let json = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
            if let jsonString = String(data:json, encoding: .utf8) {
                return jsonString
            }
        }
        return ""
    }
}

