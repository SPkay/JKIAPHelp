//
//  JKJailbreakDetectTool.h
//  test
//
//  Created by kane on 2018/8/6.
//  Copyright © 2018年 yangjingkai. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JKJailbreakDetectTool : NSObject
/**
 * 检查当前设备是否已经越狱。
 */
+ (BOOL)detectCurrentDeviceIsJailbroken;

@end

NS_ASSUME_NONNULL_END
