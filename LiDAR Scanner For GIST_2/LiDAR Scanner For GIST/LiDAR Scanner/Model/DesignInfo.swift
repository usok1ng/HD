//
//  DesignInfo.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/11/11.
//

import Foundation

class DesignInfo{
    static var SHIP_NO = ""
    static var BLOCK_NO = ""
    static var PROCESS = ""
    
    static func setDesignInfo(ship_no: String, block_no: String, process: String){
        SHIP_NO = ship_no
        BLOCK_NO = block_no
        PROCESS = process
    }
    
    static func updateStatus(idx: String, status: String) {
        let path = "http://10.150.232.54:3230"
        
//        var parameters = [
//            [
//                "key": "updateStatus",
//                "idx": idx,
//                "value": status,
//                "type": "text"
//            ]] as [[String: Any]]
        var parameters = [
            [
                "key": "mode",
                "value": "updateStatus",
                "type": "text"
            ],
            [
                "key": "idx",
                "value": idx,
                "type": "text"
            ],
            [
                "key": "status",
                "value": status,
                "type": "text"
            ]] as [[String: Any]]

        print(parameters)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        var error: Error? = nil
        for param in parameters {
            if param["disabled"] != nil { continue }
            let paramName = param["key"]!
            body += Data("--\(boundary)\r\n".utf8)
            body += Data("Content-Disposition:form-data; name=\"\(paramName)\"".utf8)
            if param["contentType"] != nil {
                body += Data("\r\nContent-Type: \(param["contentType"] as! String)".utf8)
            }
            let paramType = param["type"] as! String
            if paramType == "text" {
                let paramValue = param["value"] as! String
                body += Data("\r\n\r\n\(paramValue)\r\n".utf8)
            }
            else {
                let paramSrc = param["src"] as! String
                let fileURL = URL(fileURLWithPath: paramSrc)
                let file_name = param["name"] as! String
                if let fileContent = try? Data(contentsOf: fileURL) {
                    //body += Data("; filename=\"\(paramSrc)\"\r\n".utf8)
                    body += Data("; filename=\"\(file_name)\"\r\n".utf8)
                    body += Data("Content-Type: \"content-type header\"\r\n".utf8)
                    body += Data("\r\n".utf8)
                    body += fileContent
                    body += Data("\r\n".utf8)
                }
            }
        }
        body += Data("--\(boundary)--\r\n".utf8);
        let postData = body
        
        
        //var request = URLRequest(url: URL(string: "http://witsoft.iptime.org:3230/api/Values")!,timeoutInterval: Double.infinity)
        //var request = URLRequest(url: URL(string: "http://10.150.232.54:3230/api/Values")!, timeoutInterval: Double.infinity)
        var request = URLRequest(url: URL(string: path + "/api/Measure")!, timeoutInterval: Double.infinity)
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        request.httpMethod = "POST"
        request.httpBody = postData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                print(String(describing: error))
                return
            }
            print(String(data: data, encoding: .utf8)!)
        }
        
        task.resume()
    
    }
}
