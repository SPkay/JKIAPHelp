//
//  JKIAPTransactionModel.h
//  JKIAPHelp
//
//  Created by kane on 2018/8/8.
//  Copyright © 2018年 kane. All rights reserved.
//

#import <Foundation/Foundation.h>
//苹果商品的几种类型
typedef enum : NSUInteger {
    AppleProductType_Unknow=0,
    AppleProductType_Consumable,//消费类产品(单笔,游戏币)
    AppleProductType_NonConsumable,//非消费类产品
    //Auto_Renewable_Subscriptions,//包月＋自动续费
   // Free_Subscription,//免费
    //Non_Renewing_Subscription,//包月+非自动续费
} AppleProductType;

typedef NS_ENUM(NSUInteger, TransactionStatus) {
    TransactionStatusWaitApple,
    TransactionStatusAppleFailed,
    TransactionStatusAppleSucc,
    TransactionStatusSeriverError,
    TransactionStatusSeriverFailed,
    TransactionStatusSeriverSucc,
};


@interface JKIAPTransactionModel : NSObject<NSCoding>

#pragma mark - Properties

/**
 * 用户 id.
 */
@property(nonatomic, copy, readonly) NSString *userId;

/**
 * 事务 id.
 */
@property(nonatomic, copy) NSString *transactionIdentifier;

/**
 * 交易时间(添加到交易队列时的时间).
 */
@property(nonatomic, strong, readonly) NSDate *transactionDate;

/* 物品类型 */
@property (nonatomic,assign)AppleProductType appleProductType;

/**
 * 商品 id.
 */
@property(nonatomic, copy, readonly) NSString *productIdentifier;



/**
 * 后台配置的订单号.
 */
@property(nonatomic, copy, readonly) NSString *seriverOrder;

/**
 * 价格字符.
 */
@property(nonatomic, copy) NSString *priceString;



/**
 订单状态
 */
@property(nonatomic, assign) TransactionStatus transactionStatus;



/* 票据 */
@property (nonatomic,copy)NSString * appStoreReceipt;


/**
 错误信息
 */
@property (nonatomic, strong) NSError *error;

#pragma mark - Method

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
+ (instancetype)modelWithProductIdentifier:(NSString *)productIdentifier
                            appproductType:( AppleProductType)appproductType
                                     price:(NSString *)price
                                   orderId:(NSString *)orderId
                                    userId:(NSString *)userId;


@end
