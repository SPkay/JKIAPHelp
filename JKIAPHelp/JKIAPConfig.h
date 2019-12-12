//
//  JKIAPConfig.h
//  JKIAPHelp
//
//  Created by kane on 2018/8/8.
//  Copyright © 2018年 kane. All rights reserved.
//

#import <Foundation/Foundation.h>



#define JKIAPVerifyNotification @"JKIAPVerifyNotification"
#define JKIAPVerifyFinishNotification @"JKIAPVerifyFinishNotification"
#define JKIAPLog(...) [JKIAPConfig sendLog:__VA_ARGS__]

@interface JKIAPConfig : NSObject

/// 是否输出log,默认YES
@property (nonatomic,assign,class)BOOL enableLog;

/// 是否允许越狱支付,默认YES
@property (nonatomic,assign,class)BOOL shouldJailbrokenPay;

/// 是否允许默认Loading,默认YES
@property (nonatomic, assign,class) BOOL enableLoading;

+(void)sendLog:(NSString *)format, ... ;



@end
