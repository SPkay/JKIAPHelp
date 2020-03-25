//
//  JKIAPTransactionModel.h
//  JKIAPHelp
//
//  Created by kane on 2018/8/8.
//  Copyright © 2018年 kane. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, TransactionStatus) {
    TransactionStatusWaitApple,
    TransactionStatusAppleCancel,
    TransactionStatusAppleFailed,
    TransactionStatusAppleSucc,
    TransactionStatusSeriverError,
    TransactionStatusSeriverFailed,
    TransactionStatusSeriverSucc,
};


@interface JKIAPTransactionModel : NSObject<NSCoding>

#pragma mark - Properties


/**
 * 事务 id.
 */
@property(nonatomic, copy) NSString *transactionIdentifier;

/**
 * 交易时间(添加到交易队列时的时间).
 */
@property(nonatomic, strong, readonly) NSDate *transactionDate;

/**
 * 商品 id.
 */
@property(nonatomic, copy, readonly) NSString *productIdentifier;




/// 请求里的applicationUsername
@property (nonatomic, copy) NSString *applicationUsername;


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


/// 检测次数,如果在
@property (nonatomic, assign) NSInteger cancelStatusCheckCount;

/* 以下属性,只有使用订单号参数购买方式:
 - (void)buyProductWithUserID:(NSString *)userid
 productIdentifier:(NSString *)productIdentifier
                      orderId:(NSString *)orderId; 才有值 */

/**
 * 用户 id.
 */
@property(nonatomic, copy, readonly) NSString *userId;

/**
 * 后台配置的订单号.
 */
@property(nonatomic, copy,readonly) NSString *seriverOrder;

/**
 * 价格字符.
 */
@property(nonatomic, copy) NSString *priceString;


#pragma mark - Method

/**
 * 初始化方法(没有收据的).
 *
 * @warning: 所有数据都必须有值, 否则会报错, 并返回 nil.
 *
 * @param productIdentifier       商品 id.
 * @param applicationUsername   applicationUsername
 */
+ (instancetype)modelWithProductIdentifier:(NSString *)productIdentifier
                       applicationUsername:(NSString *)applicationUsername;


@end
