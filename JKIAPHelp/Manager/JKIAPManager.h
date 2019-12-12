//
//  JKIAPManager.h
//  JKIAPHelp
//
//  Created by kane on 2018/8/7.
//  Copyright © 2018年 kane. All rights reserved.
//

#import <UIKit/UiKit.h>
#import "JKIAPPayDelegate.h"
#import "JKIAPTransactionModel.h"
#import <StoreKit/StoreKit.h>
#import "JKIAPActivityIndicatorProtocol.h"



NS_ASSUME_NONNULL_BEGIN
@class SKProduct;
@interface JKIAPManager : NSObject



/* 购买代理 */
@property (nonatomic,weak)id<JKIAPPayDelegate> delegate;

/* 活动指示器,如果没有就使用默认的 */
@property (nonatomic,strong)id<JKIAPActivityIndicatorProtocol> activityIndicatorController;
/**
 * 单例方法.
 */
+ (instancetype)sharedManager;



/**
 * 当前设备是否是越狱设备.
 */
- (BOOL)currentDeviceIsJailbroken;


/*!
@method
@brief 判断当前iOS设备是否支持IAP支付
@return YES:支持 NO:不支持
@note 家长控制关闭iap，不允许越狱机器购买时 返回NO
*/
- (BOOL)checkCanPay;


/**
 注册支付事务监听, 并且开始支付凭证验证队列.
@warning ⚠️ 请在用户登录时和用户重新启动 APP 时调用.
 @param userid 用户 ID.
 */
- (void)registerPayWithUserID:(NSString *)userid;



/**
 注册支付事务监听, 并且开始支付凭证验证队列.(指定钥匙串账号和服务区)

 @param userid 用户 ID.
 @param keychainService keychainService
 @param keychainAccount keychainAccount
 */
- (void)registerPayWithUserID:(NSString *)userid
              keychainService:(NSString *)keychainService
              keychainAccount:(NSString *)keychainAccount;



/**
 购买物品

 @param productIdentifier 物品id
 @param appproductType 类型
 @param orderId 订单号
 */
- (void)buyProductWithProductIdentifier:(NSString *)productIdentifier
                         appproductType:( AppleProductType)appproductType
                                orderId:(NSString *)orderId;
/**
 注销支付管理
 */
- (void)unRegisterPay;


/**
 * 获取产品信息.
 *
 * @param productIdentifiers 产品标识.
 */
- (void)fetchProductInfoWithProductIdentifiers:(NSSet<NSString *> *)productIdentifiers;


/**
 恢复购买
 */
- (void)restoreProducts;




@end

NS_ASSUME_NONNULL_END
