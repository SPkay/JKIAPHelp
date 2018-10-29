//
//  JKIAPVerifyManager.m
//  JKIAPHelp
//
//  Created by kane on 2018/8/13.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "JKIAPVerifyManager.h"
#import "SAMKeychain.h"
#import "JKIAPTransactionModel.h"
#import "JKIAPConfig.h"
#import <StoreKit/StoreKit.h>


#define KEYCHAIN_SERVICE @"com.jkiap_keychain_service.www"
#define KEYCHAIN_ACCOUNT @"com.jkiap_keychain_account.www"

@interface JKIAPVerifyManager ()
{
    
    BOOL _isVerifing;
    JKIAPTransactionModel *_currentModel;
    NSMutableArray *_modelArray;
}

@end

@implementation JKIAPVerifyManager
/**
 * 初始化方法.
 */
- (instancetype)initWithUserId:(NSString *)userId{
    self = [super init];
    if (self) {
        _userId = userId;
        _isVerifing = NO;
        _modelArray = [NSMutableArray new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeStatus) name:JKIAPVerifyNotification object:nil];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
/**
 * 添加需要验证的 model.
 */
- (void)appendPaymentTransactionModel:(JKIAPTransactionModel *)transactionModel{
    //取出
    
   NSMutableSet *keychainSet = [self fetchAllPaymentTransactionModel];
    for (JKIAPTransactionModel *model in keychainSet) {
        if ([model isEqual:transactionModel]) {
            return;
        }
    }
    [keychainSet addObject:transactionModel];
    
    [self savePaymentTransactionModels:keychainSet];
    
   
}

/**
 * ⚠️ 开始支付凭证验证队列(开始验证之前, 必须保证收据不为空).
 */
- (void)startPaymentTransactionVerifingModel:(JKIAPTransactionModel *)transactionModel{
    for (JKIAPTransactionModel *model in _modelArray) {
        if ([model.transactionIdentifier isEqualToString:transactionModel.transactionIdentifier]) {
            return;
        }
    }
   __block JKIAPTransactionModel *resultModel= transactionModel;
     NSMutableSet *keychainSet = [self fetchAllPaymentTransactionModel];
    [keychainSet enumerateObjectsUsingBlock:^(JKIAPTransactionModel*  _Nonnull model, BOOL * _Nonnull stop) {
        
        if (transactionModel.seriverOrder) {
            if ([model.seriverOrder isEqualToString:transactionModel.seriverOrder]) {
                model.transactionIdentifier = transactionModel.transactionIdentifier;
                model.transactionStatus = TransactionStatusAppleSucc;
                resultModel = model;
                *stop = YES;
            }
        }else{
            if ([transactionModel.productIdentifier isEqualToString:model.productIdentifier] && [transactionModel.userId isEqualToString:model.userId]) {
                model.transactionIdentifier = transactionModel.transactionIdentifier;
                model.transactionStatus = TransactionStatusAppleSucc;
                  resultModel = model;
                *stop = YES;
            }
        }
      
    }];
    //保存更改
    [self savePaymentTransactionModels:keychainSet];
   
    [_modelArray addObject:transactionModel];
    //开始验证
    [self verifingModel:resultModel];
  
}
-(void)updatePaymentTransactionModelStatus:(JKIAPTransactionModel *)transactionModel{
    
    NSString *transactionIdentifier = transactionModel.transactionIdentifier;
      NSMutableSet *keychainSet = [self fetchAllPaymentTransactionModel];
    [keychainSet enumerateObjectsUsingBlock:^(JKIAPTransactionModel*  _Nonnull model, BOOL * _Nonnull stop) {
        if ([model.transactionIdentifier isEqualToString:transactionIdentifier]) {
            model.transactionStatus= transactionModel.transactionStatus;
            if (transactionModel.error) {
                model.error = transactionModel.error;
            }
            *stop = YES;
        }
    }];
    [self savePaymentTransactionModels:keychainSet];
}

/**
 * 删除失败 model.
 */
- (void)deletePaymentTransactionModel:(JKIAPTransactionModel *)transactionModel{
    NSMutableSet *keychainSet =[self fetchAllPaymentTransactionModel];
   
    NSInteger count = keychainSet.count;
    [keychainSet enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(JKIAPTransactionModel*  _Nonnull model, BOOL * _Nonnull stop) {
        if ([model isEqual:transactionModel]) {
            [keychainSet removeObject:model];
               JKIAPLog(@"完成删除订单:%@",transactionModel.seriverOrder);
        }
    }];
    
    
    if (count == keychainSet.count) {
         JKIAPLog(@"删除订单删除失败:%@",transactionModel.seriverOrder);
    }
    [self savePaymentTransactionModels:keychainSet];
    
}



- (void)verifingModel:(JKIAPTransactionModel *)transactionModel{
  
    if (_isVerifing) {
        JKIAPLog(@"正在验证中....%@",_currentModel.seriverOrder);
        return;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(startPaymentTransactionVerifingModel:)]) {
        _isVerifing = YES;
        _currentModel = transactionModel;
         JKIAPLog(@"开始验证....%@",_currentModel.seriverOrder);
        [self.delegate startPaymentTransactionVerifingModel:transactionModel];
    }
}




/**
 获取所有交易模型

 @return model
 */
- (NSMutableSet <JKIAPTransactionModel *>*)fetchAllPaymentTransactionModel{
    
    @synchronized (self) {
        NSData *keychainData = [SAMKeychain passwordDataForService:KEYCHAIN_SERVICE account:KEYCHAIN_ACCOUNT];
        NSMutableSet *keychainSet= [NSMutableSet new];
        if (keychainData) {
            NSSet *  keychainSetData= (NSSet *)[NSKeyedUnarchiver unarchiveObjectWithData:keychainData];
            for (NSData *data in keychainSetData) {
                JKIAPTransactionModel *model = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                [keychainSet addObject:model];
            }
        }
        JKIAPLog(@"当前获取的存档;%@",keychainSet);
        return keychainSet;
    }
   
    
}

- (void)savePaymentTransactionModels:(NSSet <JKIAPTransactionModel *>*)models{
    
    @synchronized (self) {
        
   
    NSMutableSet *saveSet =[NSMutableSet new];
    for (JKIAPTransactionModel *model in models) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
        [saveSet addObject:data];
    }
    
        NSData *saveData = [NSKeyedArchiver archivedDataWithRootObject:saveSet];
        
     BOOL result=   [SAMKeychain setPasswordData:saveData forService:KEYCHAIN_SERVICE account:KEYCHAIN_ACCOUNT];
        JKIAPLog(@"保存存档%@->%@",models,(result ? @"成功":@"失败"));
     }

}

- (void)cleanAllModels{
    [SAMKeychain deletePasswordForService:KEYCHAIN_SERVICE account:KEYCHAIN_ACCOUNT];
}

- (void)changeStatus{
    if (_modelArray.count>0) {
        [self verifingModel:_modelArray.firstObject];
    }else{
        _isVerifing = NO;
    }
    
}

- (void)checkUnfinishedTransaction{
    
   
   
   
}
@end
