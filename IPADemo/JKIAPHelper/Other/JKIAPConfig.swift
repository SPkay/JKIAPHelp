//
//  JKIAPConfig.swift
//  JKIAPHelper
//
//  Created by Kane on 2019/8/7.
//  Copyright © 2019 kane. All rights reserved.
//

import Foundation



func JKIAPPrint(string : String) {
    if JKIAPManager.logEnable {
        print("[JKIAP]:"+string)
    }
}
