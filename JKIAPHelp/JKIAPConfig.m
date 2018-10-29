//
//  JKIAPConfig.m
//  JKIAPHelp
//
//  Created by kane on 2018/8/8.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "JKIAPConfig.h"
#import "JKIAPManager.h"

NSString *const JKIAPErrorDomain = @"com.jkiap_error_domain.www";



static BOOL sendLog;

@implementation JKIAPConfig

+(void)sendLog:(NSString *)format, ... {

    if (sendLog) {
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
    return sendLog;
}
+ (void)setEnableLog:(BOOL)enableLog{
    sendLog = enableLog;
}

@end
