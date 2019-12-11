//
//  JKJailbreakDetectTool.swift
//  JKIAPHelper
//
//  Created by Kane on 2019/8/7.
//  Copyright © 2019 kane. All rights reserved.
//

import Foundation



struct  JKJailbreakDetectTool {
    
    
    /// 检查当前设备是否已经越狱。
    ///
    /// - Returns: 是否已经越狱
    static func detectCurrentDeviceIsJailbroken() -> Bool {
        var result = false
        
        
        result =  detectJailBreakByJailBreakFileExisted()
        
        if (!result) {
            result =  detectJailBreakByCydiaPathExisted()
        }
        if (!result) {
            result = detectJailBreakByAppPathExisted()
        }
        
        if (!result) {
            result = detectJailBreakByEnvironmentExisted()
        }
        
        return result;
    }
    
    /**
     * 判定常见的越狱文件
     * /Applications/Cydia.app
     * /Library/MobileSubstrate/MobileSubstrate.dylib
     * /bin/bash
     * /usr/sbin/sshd
     * 这个表可以尽可能的列出来，然后判定是否存在，只要有存在的就可以认为机器是越狱了。
     */
   private static let jailbreak_tool_pathes = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt"]
    
   

 private  static func detectJailBreakByJailBreakFileExisted() -> Bool {
        
        for path in jailbreak_tool_pathes {
            if FileManager.default.fileExists(atPath: path){
                return true
            }
        }
     
        return false;
    }
   
    
    
   
    
    /**
     * 判断cydia的URL scheme.
     * URL scheme是可以用来在应用中呼出另一个应用，这个方法也就是在判定是否存在cydia这个应用。
     */
private  static  func detectJailBreakByCydiaPathExisted() -> Bool {
        if UIApplication.shared.canOpenURL(URL(string: "cydia://")!) {
            return true
        }
        return false
    }
    
    
    /**
     * 读取系统所有应用的名称.
     * 这个是利用不越狱的机器没有这个权限来判定的。
     */

 private  static func detectJailBreakByAppPathExisted() -> Bool {
        let appPath = "/User/Applications/"
        if  FileManager.default.fileExists(atPath: appPath){
            let applist = try? FileManager.default.contentsOfDirectory(atPath: appPath)
            if applist != nil {
                return true
            }
            
        }
        return false
    }
    
    /**
     * 这个DYLD_INSERT_LIBRARIES环境变量，在非越狱的机器上应该是空，越狱的机器上基本都会有Library/MobileSubstrate/MobileSubstrate.dylib.
     */
  private static  func detectJailBreakByEnvironmentExisted() -> Bool {
        if (getenv("DYLD_INSERT_LIBRARIES") != nil){
            return true
        }
        return false
    }
    
}
