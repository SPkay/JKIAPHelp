//
//  JKIAPConfig.h
//  JKIAPHelp
//
//  Created by kane on 2018/8/8.
//  Copyright © 2018年 kane. All rights reserved.
//

#import <Foundation/Foundation.h>



FOUNDATION_EXTERN NSString *const JKIAPErrorDomain;
#define JKIAPVerifyNotification @"JKIAPVerifyNotification"


#define JKIAPLog(...) [JKIAPConfig sendLog:__VA_ARGS__]
@interface JKIAPConfig : NSObject

/* 是否输出log */
@property (nonatomic,assign,class)BOOL enableLog;


+(void)sendLog:(NSString *)format, ... ;

@end
