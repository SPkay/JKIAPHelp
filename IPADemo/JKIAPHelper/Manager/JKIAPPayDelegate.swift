//
//  JKIAPPayDelegate.swift
//  JKIAPHelper
//
//  Created by Kane on 2019/8/6.
//  Copyright © 2019 kane. All rights reserved.
//

import StoreKit

enum JKIAPVerifyResult : String {
    case JKIAPVerifyFailed = "验证请求网络错误"
    case JKIAPVerifyValid = "票据有效"
    case JKIAPVerifyInvalid = "票据无效"
}

typealias VerifyRsultBlock = (JKIAPVerifyResult) -> Void

protocol JKIAPPayDelegate : NSObjectProtocol {
    /**
     票据验证方法

     @param model 交易模型
     @param resultAction ⚠️需要执行的block(将从自己服务器验证的结果传入执行)
     */
   func verify(_ model: JKIAPTransactionModel?,_ resultAction: VerifyRsultBlock)

    /**
     获取苹果商店信息成功

     @param products 商店物品
     @param error 错误信息
     */
    func onLaunProductListFinish(_ products: [SKProduct]?, withError error: Error?)
    /**
     苹果支付成功回调

     @param model 交易模型
     */
    func onIAPPaymentSucess(_ model: JKIAPTransactionModel?)
    /**
     苹果支付失败回调

     @param model 交易模型
     @param error 错误信息
     */
   func onIAPPayFailue(_ model: JKIAPTransactionModel?, withError error: Error?)
    /**
     苹果恢复购买结果

     @param productIdentifiers 恢复购买结果
     @param error 错误信息
     */
     func onIAPRestoreResult(_ productIdentifiers: [Any]?, withError error: Error?)
    /**
     发货成功回调

     @param model 交易模型
     */
     func onDistributeGoodsFinish(_ model: JKIAPTransactionModel?)
    //发货失败回调
     func onDistributeGoodsFailue(_ model: JKIAPTransactionModel?, withError error: Error?)
    //******************补发回调用*******************

    //补发货成功回调
    func onRedistributeGoodsFinish(_ model: JKIAPTransactionModel?)
    //补发货失败回调
     func onRedistributeGoodsFailue(_ model: JKIAPTransactionModel?, withError error: Error?)
}


