//
//  JKIAPManager.swift
//  JKIAPHelper
//
//  Created by Kane on 2019/8/6.
//  Copyright © 2019 kane. All rights reserved.
//

import UIKit
import StoreKit

typealias ReceiptBlock = (_ receipt:String)->()

class JKIAPManager : NSObject{
    
    
   /// 获取单例
   public static let `default` = JKIAPManager()
    
    /// 是否允许越狱支付,默认NO
  static public var shouldJailbrokenPay = false
    
    /// 是否有Loading
  static public var hasLoading = true
    
    /// 是否发送Log
  static public var logEnable: Bool = true
    
    //* 请求中
    private(set) var isLoading = false
    
    
    // MARK: -  Private Property
    
    private var appOrderID : String?
    private var productIdentifier : String?
    private var productType: JKHelperAppleProductType?
    private var userId : String?
    private var currentModel: JKIAPTransactionModel? = nil ///StatePurchasing后才有
    ///获取商品列表请求.
      private var currentProductRequest: SKProductsRequest? = nil
    private var isBuyProdutTofetchList: Bool = false
    private var refreshRequest: SKReceiptRefreshRequest? = nil
    private var currentPayment: SKMutablePayment? = nil ///已获取到订单信息,还未开始购买
    private var reachability = JKReachability(host: "www.baidu.com")
    private var receiptBlock: ReceiptBlock?
    /// 活动指示器
     private lazy var activityView = JKIAPActivityIndicator()
    /// 验证管理
      private var verifyManager: JKIAPVerifyManager?
 
    // 购买代理
    private weak var delegate: JKIAPPayDelegate?


    
    // MARK: -  Method
    
    /// 判断当前iOS设备是否支持IAP支付
    ///
    /// - Returns: 家长控制关闭iap，不允许越狱机器购买时 返回NO
    func judgeIsCanPay() -> Bool {
        if  judgeJailbrokenCanPay() {
            return SKPaymentQueue.canMakePayments()
        }
        return false;
    }

    
    /// 检测是否可以进行支付
    ///
    /// - Returns: 不允许越狱机器购买时 返回NO
    func judgeJailbrokenCanPay() -> Bool {
        if JKIAPManager.shouldJailbrokenPay,currentDeviceIsJailbroken(){
            return false
        }
        return true
    }
    

    
    
///  注册支付事务监听, 并且开始支付凭证验证队列.
///@warning ⚠️ 请在用户登录时和用户重新启动 APP 时调用.
/// - Parameters:
///   - userid: 用户 ID.
///   - keychainService: 钥匙串账号
///   - keychainAccount: 服务区
func registerPay(_ userid: String, keychainService: String?, keychainAccount: String?) {
    if !judgeJailbrokenCanPay() {return}
    
    if (verifyManager != nil) {
        JKIAPPrint(string: "已经注册过用户ID")
        return;
    }
    userId = userid
    
    //verifyManager = JKIAPVerifyManager.
    
//    self.verifyManager = [[JKIAPVerifyManager alloc] initWithUserId:userid keychainService:keychainService keychainAccount:keychainAccount];
//    self.verifyManager.delegate = self;
//    [self checkUnfinishedTransaction];
    
    
    SKPaymentQueue.default().add(self)
  
}
    /**
     注销支付管理
     */
    func unRegisterPay() {
        if !judgeJailbrokenCanPay() {
            return
        }
        
        
        if currentProductRequest != nil{
            self.currentProductRequest!.cancel()
            self.currentProductRequest = nil;
        }
        self.verifyManager = nil;
        
        
        appOrderID = nil;
        productIdentifier = nil;
        userId = nil;
        currentModel = nil;//StatePurchasing后才有
        currentPayment = nil;//已获取到订单信息,还未开始购买
        SKPaymentQueue.default().remove(self)
        
    }
    
    // MARK: -  IAPMethod
/**
 购买物品

 @param productIdentifier 物品id
 @param appproductType 类型
 @param orderId 订单号
 */
func buyProduct(withProductIdentifier productIdentifier: String, appproductType: JKHelperAppleProductType, orderId: String?) {
    if  appOrderID != nil, (orderId == appOrderID) {
        JKIAPPrint(string: "购买失败,与当前订单号相同" + (appOrderID ?? ""))
        return
    }

    checkUnfinishedTransaction()

if isLoading {
    
    
    if delegate != nil,  delegate.responds(to: Selector("onIAPPayFailue(_:withError:))") {
        delegate.onIAPPayFailue(nil, withError: NSError(domain: JKIAPErrorDomain, code: JKIAPError_Paying, userInfo: [
        NSLocalizedDescriptionKey: "正在购买或者请求商品中...."
        ]))
    }
    return
}
if !productIdentifier || !orderId {
    if delegate && delegate.responds(to: #selector(onIAPPayFailue(_:withError:))) {
        delegate.onIAPPayFailue(nil, withError: NSError(domain: JKIAPErrorDomain, code: JKIAPError_Parameter, userInfo: [
        NSLocalizedDescriptionKey: "购买失败,参数错误...."
        ]))
    }
    return
}
if !reachability.currentReachable() {
    if delegate && delegate.responds(to: #selector(onIAPPayFailue(_:withError:))) {
        delegate.onIAPPayFailue(nil, withError: NSError(domain: JKIAPErrorDomain, code: JKIAPError_Net, userInfo: [
        NSLocalizedDescriptionKey: "无法连接网络...."
        ]))
    }
    return
}

//productIdentifier = productIdentifier    // Skipping redundant initializing to itself
appOrderID = orderId
productType = appproductType
isBuyProdutTofetchList = true

fetchProductInfo(withProductIdentifiers: Set<AnyHashable>([productIdentifier]))

}





/**
 恢复购买
 */
func restoreProducts() {
}

    // MARK: -  PrivateMethod
    
    private  override init() {
        reachability?.startListening()
    }
    
    /// 当前设备是否是越狱设备.
    ///
    /// - Returns: bool
    private  func currentDeviceIsJailbroken() -> Bool {
        return  JKJailbreakDetectTool.detectCurrentDeviceIsJailbroken()
    }
    
    private func checkUnfinishedTransaction(){
        
    }
    
    
}


extension JKIAPManager : SKPaymentTransactionObserver{
   
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
   
    
    
}
