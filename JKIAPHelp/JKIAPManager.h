//
//  JKIAPManager.h
//  JKIAPHelp
//
//  Created by kane on 2018/8/7.
//  Copyright © 2018年 kane. All rights reserved.
//

#import <UIKit/UiKit.h>
#import "SAMKeychain.h"
#import "JKIAPPayDelegate.h"
#import "JKIAPTransactionModel.h"
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN
@class SKProduct;
@interface JKIAPManager : NSObject


/** 请求中 */
@property (nonatomic, assign,readonly) BOOL isPaying;
/* 购买代理 */
@property (nonatomic,weak)id<JKIAPPayDelegate> delegate;

/**
 * 单例方法.
 */
+ (instancetype)sharedManager;



/**
 * 是否允许越狱支付,默认NO
 */
- (void)shouldJailbrokenPay:(BOOL)jailbrokenPay;

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
- (BOOL)judgeIsCanPay;


/*!
 @method
 @abstract 隐藏Loading（不建议）
 @discussion 防止用户多次重复购买，特加入loading
 @author bladebao
 */
- (void)hideLoading:(BOOL)hide;



/**
 是否发送Log

 @param isEnable 是否发送Log
 */
- (void)setIsEnLog:(BOOL)isEnable;

/**
 * 注册支付事务监听, 并且开始支付凭证验证队列.
 *
 * @warning ⚠️ 请在用户登录时和用户重新启动 APP 时调用.
 *
 * @param userid 用户 ID.
 */
- (void)registerPayWithUserID:(NSString *)userid;

/**
 注销支付管理
 */
- (void)unRegisterPay;




//withProductType:(AppproductType)productType
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





/**
  购买物品

 @param productIdentifier 产品标识
 @param appproductType 物品类型
 @param orderId 订单号
 */
- (void)buyProductWithProductIdentifier:(NSString *)productIdentifier
                         appproductType:( AppleProductType)appproductType
                                orderId:(NSString *)orderId ;

/**
 购买物品(苹果购买完成后再生成订单)

 @param productIdentifier 物品标识
 @param appproductType 物品类型
 */
- (void)buyProductWithProductIdentifier:(NSString *)productIdentifier appproductType:( AppleProductType)appproductType;



@end

NS_ASSUME_NONNULL_END
