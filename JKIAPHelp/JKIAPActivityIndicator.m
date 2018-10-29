//
//  JKIAPActivityIndicatorView.m
//  JKIAPHelp
//
//  Created by kane on 2018/8/17.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "JKIAPActivityIndicator.h"


@interface   JKIAPActivityIndicator()
{
    UIActivityIndicatorView *_actIndicatorView;
    UIView *_activitybackView;
    UIView *_backView;
    UILabel *_label;
}
@end

@implementation JKIAPActivityIndicator

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self creatViews];
    }
    return self;
}
/**
 * 活动指示器弹出框开始
 */
- (void)start{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_actIndicatorView.isAnimating == YES) {
            [self stop];
        }
        self->_backView.alpha = 0;
        [self layoutViews];
        [self->_actIndicatorView startAnimating];
        [UIView animateWithDuration:0.5 animations:^{
            self->_backView.alpha = 1;
        }];
       
    });

}

/**
 * 活动指示器弹出框结束
 */
- (void)stop{
    dispatch_async(dispatch_get_main_queue(), ^{

        [UIView animateWithDuration:0.5 animations:^{
            self->_backView.alpha = 0;
        } completion:^(BOOL finished) {
            [self->_backView removeFromSuperview];
            [self->_actIndicatorView stopAnimating];
        }];
    
    });
  
}
- (void)setLableMessage:(NSString *)msg{
    _label.text = msg;
}

- (void)creatViews{
    if (!_backView) {
        _backView = [UIView new];
        
        _backView.userInteractionEnabled = YES;
        _backView.backgroundColor = [UIColor colorWithWhite:1 alpha:.5];
        _actIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _actIndicatorView.color = [UIColor blackColor];
        _activitybackView = [UIView new];
        _activitybackView.backgroundColor = [UIColor lightGrayColor];
        _activitybackView.layer.cornerRadius = 5;
        _label = [UILabel new];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.font = [UIFont systemFontOfSize:14];
        [_backView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_activitybackView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_label setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_actIndicatorView setTranslatesAutoresizingMaskIntoConstraints:NO];
    }
  
}

- (void)layoutViews{
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (![keyWindow.subviews containsObject:_backView]) {

        [keyWindow addSubview:_backView];
         NSLayoutConstraint *constrant11 = [NSLayoutConstraint constraintWithItem:_backView
                                                                        attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:keyWindow attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
          NSLayoutConstraint *constrant12 = [NSLayoutConstraint constraintWithItem:_backView
                                                                         attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:keyWindow attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0];
          NSLayoutConstraint *constrant13 = [NSLayoutConstraint constraintWithItem:_backView
                                                                         attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:keyWindow attribute:NSLayoutAttributeRight multiplier:1.0 constant:0];
          NSLayoutConstraint *constrant14 = [NSLayoutConstraint     constraintWithItem:_backView
                                                    attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:keyWindow attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
        [keyWindow addConstraints:@[constrant11,constrant12,constrant13,constrant14]];
        
        
        
        [_backView addSubview:_activitybackView];
        NSLayoutConstraint *constrant21 = [NSLayoutConstraint constraintWithItem:_activitybackView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_backView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
        
        NSLayoutConstraint *constrant22 = [NSLayoutConstraint constraintWithItem:_activitybackView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_backView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0];
        
       NSLayoutConstraint *constrant23 = [NSLayoutConstraint constraintWithItem:_activitybackView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:95];
        
        NSLayoutConstraint *constrant24 = [NSLayoutConstraint constraintWithItem:_activitybackView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:130];
        [_backView addConstraints:@[constrant21,constrant22,constrant23,constrant24]];
        
        
          [_activitybackView addSubview:_label];
        NSLayoutConstraint *constrant31 = [NSLayoutConstraint constraintWithItem:_label attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:25];
        
        NSLayoutConstraint *constrant32 = [NSLayoutConstraint constraintWithItem:_label attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_activitybackView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:5];
        NSLayoutConstraint *constrant33 = [NSLayoutConstraint constraintWithItem:_label attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_activitybackView attribute:NSLayoutAttributeRight multiplier:1.0 constant:-5];
        NSLayoutConstraint *constrant34 = [NSLayoutConstraint constraintWithItem:_label attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_activitybackView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:20];
        [_activitybackView addConstraints:@[constrant31,constrant32,constrant33,constrant34]];
        
        
        [_activitybackView addSubview:_actIndicatorView];
        NSLayoutConstraint *constrant41 = [NSLayoutConstraint constraintWithItem:_actIndicatorView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_activitybackView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
        
      NSLayoutConstraint *constrant42 = [NSLayoutConstraint constraintWithItem:_actIndicatorView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_activitybackView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:-10];
        
        [_activitybackView addConstraints:@[constrant41,constrant42]];
        
    }
}



@end
