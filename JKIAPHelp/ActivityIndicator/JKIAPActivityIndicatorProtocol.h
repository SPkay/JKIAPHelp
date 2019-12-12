//
//  Header.h
//  JKIAPHelper
//
//  Created by Kane on 2019/12/10.
//  Copyright © 2019 kane. All rights reserved.
//

#ifndef Header_h
#define Header_h

#import <UIKit/UIKit.h>
@protocol JKIAPActivityIndicatorProtocol <NSObject>

/**
 * 活动指示器弹出框开始
 */
- (void)showActivityWithMessage:(NSString *)msg;

/**
 * 活动指示器弹出框结束
 */
- (void)stop;

@end
#endif /* Header_h */
