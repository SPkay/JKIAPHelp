//
//  JKIAPTransactionModel.swift
//  JKIAPHelper
//
//  Created by Kane on 2019/8/6.
//  Copyright © 2019 kane. All rights reserved.
//

import UIKit
//苹果商品的几种类型
enum JKHelperAppleProductType {
    case AppleProductType_Unknow
    case AppleProductType_Consumable //消费类产品(单笔,游戏币)
    case AppleProductType_NonConsumable //非消费类产品
}


enum JKHelperTransactionStatus {
    case  TransactionStatusWaitApple
   case TransactionStatusAppleFailed
    case TransactionStatusAppleSucc
    case TransactionStatusSeriverError
   case TransactionStatusSeriverFailed
    case TransactionStatusSeriverSucc
}




class JKIAPTransactionModel : NSObject, NSCoding{
   


  /// 用户 id.
    var userId = ""
    
 /// 事务 id.
 var transactionIdentifier = ""
    /// 交易时间(添加到交易队列时的时间).
    var transactionDate : Date
    /// 物品类型
    var appleProductType : JKHelperAppleProductType
    ///商品 id.
     var productIdentifier = ""
    /// 后台配置的订单号.
     var seriverOrder = ""
    /// 价格字符.
     var priceString = ""
    /// 订单状态
    var transactionStatus : JKHelperTransactionStatus?
    /// 票据
    var appStoreReceipt = ""
    /// 错误信息
    var error : Error?


/**
 * 初始化方法(没有收据的).
 *
 * @warning: 所有数据都必须有值, 否则会报错, 并返回 nil.
 *
 * @param productIdentifier       商品 id.
 * @param appproductType   物品类型
 * @param price   商品价格
 * @param orderId         服务器订单号
 * @param userId         用户名
 
 */
init(productIdentifier:String,appproductType:JKHelperAppleProductType,price:String,orderId:String,userId:String) {
   
    
    self.productIdentifier = productIdentifier;
    self.priceString = price;
    self.appleProductType = appproductType;
    self.seriverOrder = orderId;
    self.transactionStatus = nil;
    self.transactionDate = Date.init();
    self.userId = userId;

    }
    
    
    
    
//
//    - (BOOL)isEqual:(id)object {
//    if (!object) {
//    return NO;
//    }
//
//    if (self == object) {
//    return YES;
//    }
//
//    if (![object isKindOfClass:[JKIAPTransactionModel class]]) {
//    return NO;
//    }
//
//    return [self isEqualToModel:((JKIAPTransactionModel *)object)];
//    }
//
//    - (BOOL)isEqualToModel:(JKIAPTransactionModel *)object {
//
//    BOOL isProductIdentifierMatch = [self.productIdentifier isEqualToString:object.productIdentifier];
//
//    BOOL isTransactionIdentifierMatch= YES;
//    if (self.transactionIdentifier) {
//    isTransactionIdentifierMatch =[self.transactionIdentifier isEqualToString:object.transactionIdentifier];
//    }
//    BOOL isSeriverOrderMatch = YES;
//    if (object.seriverOrder) {
//    isSeriverOrderMatch=  [self.seriverOrder isEqualToString:object.seriverOrder];
//    }
//
//
//
//    return isTransactionIdentifierMatch && isProductIdentifierMatch&&isSeriverOrderMatch ;
//    }
//    - (NSString *)description {
//    NSDateFormatter *formatter = [NSDateFormatter new];
//    formatter.dateFormat = @"yyyy-MM-dd hh:mm:ss";
//    NSString *dateString = [formatter stringFromDate:self.transactionDate];
//    return [NSString stringWithFormat:@"productIdentifier: %@, transactionIdentifier: %@, transactionDate: %@, orderNo:%@,  priceTagString: %@, transactionStatus: %lu,userId:%@", self.productIdentifier, self.transactionIdentifier, dateString, self.seriverOrder, self.priceString, (unsigned long)self.transactionStatus,self.userId];
//    }

    
    
    
    
    
    

    func encode(with aCoder: NSCoder) {
        aCoder.encode(productIdentifier, forKey: "productIdentifier")
        aCoder.encode(transactionIdentifier, forKey: "transactionIdentifier")
        aCoder.encode(transactionDate, forKey: "transactionDate")
        aCoder.encode(seriverOrder, forKey: "seriverOrder")
        aCoder.encode(priceString, forKey: "priceString")
        
        aCoder.encode(appleProductType, forKey: "appleProductType")
        aCoder.encode(userId, forKey: "userId")
        aCoder.encode(appStoreReceipt, forKey: "appStoreReceipt")
        
        aCoder.encode(transactionStatus, forKey: "transactionStatus")
        aCoder.encode(error, forKey: "error")
    }
    
    required init?(coder aDecoder: NSCoder) {
      
        productIdentifier = aDecoder.decodeObject(forKey: "productIdentifier") as! String
        transactionIdentifier = aDecoder.decodeObject(forKey: "transactionIdentifier") as! String
        transactionDate = aDecoder.decodeObject(forKey: "transactionDate") as! Date
        seriverOrder = aDecoder.decodeObject(forKey: "seriverOrder") as! String
        priceString = aDecoder.decodeObject(forKey: "priceString") as! String
        appleProductType = aDecoder.decodeObject(forKey: "appleProductType") as! JKHelperAppleProductType
        userId = aDecoder.decodeObject(forKey: "userId") as! String
        transactionStatus = aDecoder.decodeObject(forKey: "transactionStatus") as? JKHelperTransactionStatus
        appStoreReceipt = aDecoder.decodeObject(forKey: "appStoreReceipt") as! String
        if let decode = aDecoder.decodeObject(forKey: "error") as? Error {
            error = decode
        }
    }

}









