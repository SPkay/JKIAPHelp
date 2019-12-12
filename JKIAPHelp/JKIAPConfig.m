//
//  JKIAPConfig.m
//  JKIAPHelp
//
//  Created by kane on 2018/8/8.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "JKIAPConfig.h"
#import "JKIAPManager.h"


static BOOL _sendLog = YES;
static BOOL _shouldJailbrokenPay = YES;
static BOOL _enableLoading = YES;

@implementation JKIAPConfig

+(void)sendLog:(NSString *)format, ... {

    if (_sendLog) {
        va_list paramList;
        va_start(paramList,format);
        NSString* log = [[NSString alloc]initWithFormat:format arguments:paramList];
        va_end(paramList);
        NSString *result = [@"[JKIAP]:" stringByAppendingString:log];
        NSLog(@"%@",result);
        if ([JKIAPManager sharedManager].delegate && [[JKIAPManager sharedManager].delegate respondsToSelector:@selector(JKIAPLog:)]) {
            [[JKIAPManager sharedManager].delegate JKIAPLog:result];
        }
    }
    
}

+ (BOOL)enableLog{
    return _sendLog;
}
+ (void)setEnableLog:(BOOL)enableLog{
    _sendLog = enableLog;
}

+ (BOOL)shouldJailbrokenPay{
    return _shouldJailbrokenPay;
}
+ (void)setShouldJailbrokenPay:(BOOL)shouldJailbrokenPay{
    _shouldJailbrokenPay = shouldJailbrokenPay;
}

+ (BOOL)enableLoading{
    return _enableLoading;
}

+ (void)setEnableLoading:(BOOL)enableLoading{
    _enableLoading = enableLoading;
}

@end
