//
//  NSError+JKIAPError.h
//  IPADemo
//
//  Created by Kane on 2019/12/11.
//  Copyright © 2019 kane. All rights reserved.
//


#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    JKIAPError_Paying = 70101,//购买中
    JKIAPError_Jailbroken = 70102,//越狱设备
    JKIAPError_Parameter = 70103,//参数错误
    JKIAPError_Permission= 70104,//无权限
    JKIAPError_ProductId= 70105,//没有购买的物品
    JKIAPError_Receipt = 70106,//凭据错误
    JKIAPError_VerifyInvalid = 70107,//验证订单失败
    JKIAPError_Net = 70108,//网络错误
    JKIAPError_NotRegistered = 70109,//未注册IAP
    JKIAPError_HasUnfinishedTransaction = 70110,//有未验证完的订单
} JKIAPErrorCode;



NS_ASSUME_NONNULL_BEGIN

@interface NSError (JKIAPError)

+ (instancetype)errorWithJKIAPCode:(JKIAPErrorCode)code;

@end

NS_ASSUME_NONNULL_END
