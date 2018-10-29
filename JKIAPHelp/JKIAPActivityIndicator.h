//
//  JKIAPActivityIndicator.h
//  JKIAPHelp
//
//  Created by kane on 2018/8/17.
//  Copyright © 2018年 kane. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface JKIAPActivityIndicator : NSObject





/**
 * 活动指示器弹出框开始
 */
- (void)start;

/**
 * 活动指示器弹出框结束
 */
- (void)stop;

- (void)setLableMessage:(NSString *)msg;
@end

NS_ASSUME_NONNULL_END
