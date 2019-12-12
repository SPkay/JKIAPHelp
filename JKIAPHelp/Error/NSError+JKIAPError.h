//
//  NSError+JKIAPError.h
//  IPADemo
//
//  Created by Kane on 2019/12/11.
//  Copyright © 2019 kane. All rights reserved.
//


#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    JKIAPError_Paying = 101,//购买中
    JKIAPError_Jailbroken = 102,//越狱设备
    JKIAPError_Parameter = 103,//参数错误
    JKIAPError_Permission= 104,//无权限
    JKIAPError_ProductId= 105,//没有购买的物品
    JKIAPError_Receipt = 106,//凭据错误
    JKIAPError_VerifyInvalid = 107,//验证订单失效
    JKIAPError_Net = 108,//网络错误
    JKIAPError_NotRegistered = 109,//未注册IAP
} JKIAPErrorCode;



NS_ASSUME_NONNULL_BEGIN

@interface NSError (JKIAPError)

+ (instancetype)errorWithJKIAPCode:(JKIAPErrorCode)code;

@end

NS_ASSUME_NONNULL_END
