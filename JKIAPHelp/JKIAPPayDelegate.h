//
//  JKIAPPayDelegate.h
//  JKIAPHelp
//
//  Created by kane on 2018/8/7.
//  Copyright © 2018年 kane. All rights reserved.
//


#import <Foundation/Foundation.h>
#ifndef JKIAPPayDelegate_h

@class JKIAPTransactionModel;
@class SKProduct;

typedef enum : NSUInteger {
    JKIAPVerifyFailed = 0,//验证请求网络错误
    JKIAPVerifyValid,//票据有效
    JKIAPVerifyInvalid,//票据无效
    
} JKIAPVerifyResult;

typedef enum : NSUInteger {
    JKIAPLoadingStatus_None = 0,
    JKIAPLoadingStatus_CheckingProduct = 1,
    JKIAPLoadingStatus_Paying,
    JKIAPLoadingStatus_Restoring,
    JKIAPLoadingStatus_Verifying,
} JKIAPLoadingStatus;


typedef void(^VerifyRsultBlock)(JKIAPVerifyResult result);

@protocol JKIAPPayDelegate <NSObject>


/**
 票据验证方法

 @param model 交易模型
 @param resultAction ⚠️需要执行的block(将从自己服务器验证的结果传入执行)
 */
- (void)verifyWithModel:(JKIAPTransactionModel *)model resultAction:(VerifyRsultBlock)resultAction;

@optional

/// 当前的状态
/// @param status 状态
- (void)currentStatus:(JKIAPLoadingStatus)status;

/**
 获取苹果商店信息成功

 @param products 商店物品
 @param error 错误信息
 */
-(void)onLaunProductListFinish:(NSArray<SKProduct *>*)products withError:(NSError*)error;


/**
 苹果支付成功回调

 @param model 交易模型
 */
-(void)onIAPPaymentSucess:(JKIAPTransactionModel*)model;


/**
 苹果支付失败回调

 @param model 交易模型
 @param error 错误信息
 */
-(void)onIAPPayFailue:(JKIAPTransactionModel*)model  withError:(NSError*)error;


/**
 苹果恢复购买结果
 
 @param productIdentifiers 恢复购买结果
 @param error 错误信息
 */
-(void)onIAPRestoreResult:(NSArray*)productIdentifiers  withError:(NSError*)error;

/**
 发货成功回调

 @param model 交易模型
 */
-(void)onDistributeGoodsFinish:(JKIAPTransactionModel*)model;

//发货失败回调
-(void)onDistributeGoodsFailue:(JKIAPTransactionModel*)model withError:(NSError *)error;


/*******************补发回调用********************/

//补发货成功回调
-(void)onRedistributeGoodsFinish:(JKIAPTransactionModel*)model;

//补发货失败回调
-(void)onRedistributeGoodsFailue:(JKIAPTransactionModel*)model withError:(NSError *)error;

/***************************************/



/**
 输出日志

 @param log 日志信息
 */
- (void)JKIAPLog:(NSString *)log;
@end


#define JKIAPPayDelegate_h


#endif /* JKIAPPayDelegate_h */
