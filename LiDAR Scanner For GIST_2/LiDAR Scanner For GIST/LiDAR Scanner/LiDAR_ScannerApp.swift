//
//  LiDAR_ScannerApp.swift
//  LiDAR Scanner
//
//  Created by swback on 2024/06/14.
//

import SwiftUI

@main
struct LiDAR_ScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().onOpenURL(perform: { url in
                //print("SCHEME :: " + url.scheme!)
                //print("HOST :: " + url.host!)
                
                if(url.scheme!.lowercased() == "witlidarscanner" && url.host!.lowercased() == "measure"){
                    //print("HERE")
                    
                    var ship_no = ""
                    var block_no = ""
                    var process = ""
                    
                    if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true){
                        for item in components.queryItems!{
                            //print("item :: " + item.name)
                            if(item.name.lowercased() == "ship_no"){
                                ship_no = item.value!
                            }
                            else if(item.name.lowercased() == "block_no"){
                                block_no = item.value!
                            }
                            else if(item.name.lowercased() == "process"){
                                process = item.value!
                            }
                        }
                    }
                    
                    if(ship_no.count > 0){
                        DesignInfo.setDesignInfo(ship_no: ship_no, block_no: block_no, process: process)
                        //print(DesignInfo.SHIP_NO + "," + DesignInfo.BLOCK_NO)
                    }
                }
            })
        }
    }
}
