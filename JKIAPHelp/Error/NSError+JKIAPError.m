//
//  NSError+JKIAPError.m
//  IPADemo
//
//  Created by Kane on 2019/12/11.
//  Copyright © 2019 kane. All rights reserved.
//

#import "NSError+JKIAPError.h"

NSString *const JKIAPErrorDomain = @"JKIAPErrorDomain";


@implementation NSError (JKIAPError)
+ (instancetype)errorWithJKIAPCode:(JKIAPErrorCode)code{
    NSString *msg = @"";
    switch (code) {
        case JKIAPError_Paying:
            msg = @"正在购买中";
            break;
            case JKIAPError_Jailbroken:
            msg = @"越狱设备";
            break;
            case JKIAPError_Parameter:
            msg = @"参数错误";
            break;
            case JKIAPError_Permission:
            msg = @"没有购买权限";
            break;
            case JKIAPError_ProductId:
            msg = @"未找到购买的物品";
            break;
            case JKIAPError_Receipt:
            msg = @"凭据错误";
            break;
            case JKIAPError_VerifyInvalid:
            msg = @"服务器验证失败";
            break;
            case JKIAPError_Net:
            msg = @"网络异常";
            break;
            case JKIAPError_NotRegistered:
            msg = @"请先注册JKIAP";
            break;
            case JKIAPError_HasUnfinishedTransaction:
            msg = @"您还有物品未发货成功";
        default:
            break;
    }
    
     NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : msg}];
    return  error;
}
@end
