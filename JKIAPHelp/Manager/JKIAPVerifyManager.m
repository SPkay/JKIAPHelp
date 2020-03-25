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



@interface JKIAPVerifyManager ()
{
    JKIAPTransactionModel *_currentModel;
    NSMutableArray *_modelArray;
    NSString *_keychain_service;
    NSString *_keychain_account;
}

@end

@implementation JKIAPVerifyManager

- (instancetype)initWithKeychainService:(NSString *)keychainService keychainAccount:(NSString *)keychainAccount{
    
    self = [super init];
  if (self) {
      _keychain_service = keychainService;
      _keychain_account = keychainAccount;
      if (!_keychain_account) {
          _keychain_account= @"com.jkiap_keychain_account.www";
      }
      if (!_keychain_service) {
          _keychain_service =@"com.jkiap_keychain_service.www";
      }
      _isVerifing = NO;
      _modelArray = [NSMutableArray new];
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
    
   NSMutableArray *keychainSet = [self fetchAllPaymentTransactionModel];
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
    //防止重复验证
    for (JKIAPTransactionModel *model in _modelArray) {
        if ([model.transactionIdentifier isEqualToString:transactionModel.transactionIdentifier]) {
            return;
        }
    }

   __block JKIAPTransactionModel *resultModel= transactionModel;
     NSMutableArray *keychainSet = [self fetchAllPaymentTransactionModel];
    

    
    [keychainSet enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(JKIAPTransactionModel*  _Nonnull model,NSUInteger idx, BOOL * _Nonnull stop) {
        
       
        
        if (transactionModel.applicationUsername ) {
            if ([model.applicationUsername isEqualToString:transactionModel.applicationUsername]) {
                model.transactionIdentifier = transactionModel.transactionIdentifier;
                model.transactionStatus = TransactionStatusAppleSucc;
                if (transactionModel.appStoreReceipt) {
                    model.appStoreReceipt = transactionModel.appStoreReceipt;
                }
                resultModel = model;
             
                *stop = YES;
            }
        }else if ([transactionModel.productIdentifier isEqualToString:model.productIdentifier]) {
             ///最坏的情况transactionModel只有productIdentifier来对比
                model.transactionIdentifier = transactionModel.transactionIdentifier;
            transactionModel.applicationUsername = model.applicationUsername;
            if (transactionModel.appStoreReceipt) {
                model.appStoreReceipt = transactionModel.appStoreReceipt;
            }
                model.transactionStatus = TransactionStatusAppleSucc;
                  resultModel = model;
                *stop = YES;
            }
        
      
    }];
    
        //保存更改
        [self savePaymentTransactionModels:keychainSet];
        
        [_modelArray addObject:resultModel];
        //开始验证
        [self verifingModel:resultModel];
    
   
  
}
-(void)updatePaymentTransactionCheckCount:(JKIAPTransactionModel *)transactionModel{
    
      NSMutableArray *keychainSet = [self fetchAllPaymentTransactionModel];
    [keychainSet enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(JKIAPTransactionModel*  _Nonnull model,NSUInteger idx, BOOL * _Nonnull stop) {
        if ([model isEqual:transactionModel]) {
            model.cancelStatusCheckCount= transactionModel.cancelStatusCheckCount;
            *stop = YES;
        }
    }];
    [self savePaymentTransactionModels:keychainSet];
}
-(void)updatePaymentTransactionModelStatus:(JKIAPTransactionModel *)transactionModel{
    
      NSMutableArray *keychainSet = [self fetchAllPaymentTransactionModel];
    [keychainSet enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(JKIAPTransactionModel*  _Nonnull model,NSUInteger idx, BOOL * _Nonnull stop) {
        if ([model isEqual:transactionModel]) {
            model.transactionStatus= transactionModel.transactionStatus;
            if (transactionModel.error) {
                model.error = transactionModel.error;
            }
            *stop = YES;
        }
    }];
    [self savePaymentTransactionModels:keychainSet];
}

- (void)finishPaymentTransactionVerifingModel:(JKIAPTransactionModel *)transactionModel{
    for (JKIAPTransactionModel *model in _modelArray) {
        if ([model.transactionIdentifier isEqualToString:transactionModel.transactionIdentifier]) {
            [_modelArray removeObject:model];
            break;
        }
    }
       self.isVerifing = NO;
}

/**
 * 删除失败 model.
 */
- (void)deletePaymentTransactionModel:(JKIAPTransactionModel *)transactionModel{
    NSMutableArray *keychainSet =[self fetchAllPaymentTransactionModel];
   
    NSInteger count = keychainSet.count;
    [keychainSet enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(JKIAPTransactionModel*  _Nonnull model,NSUInteger idx, BOOL * _Nonnull stop) {
        if ([model isEqual:transactionModel]) {
            [keychainSet removeObject:model];
               JKIAPLog(@"完成删除订单:%@",transactionModel);
        }
    }];
    
    
    if (count == keychainSet.count) {
         JKIAPLog(@"删除订单删除失败:%@",transactionModel);
    }
    [self savePaymentTransactionModels:keychainSet];
    
}



- (void)verifingModel:(JKIAPTransactionModel *)transactionModel{
  
    if (_isVerifing) {
        JKIAPLog(@"正在验证中....%@",_currentModel);
        return;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(startPaymentTransactionVerifingModel:)]) {
        _isVerifing = YES;
        _currentModel = transactionModel;
         JKIAPLog(@"开始验证....%@",_currentModel);
        [self.delegate startPaymentTransactionVerifingModel:transactionModel];
    }
}




/**
 获取所有交易模型

 @return model
 */
- (NSMutableArray <JKIAPTransactionModel *>*)fetchAllPaymentTransactionModel{
    
        NSData *keychainData = [SAMKeychain passwordDataForService:_keychain_service account:_keychain_account];
         NSMutableArray *mutableArray =[NSMutableArray new];
        if (keychainData) {
            NSArray *  keychainSetData= (NSArray *)[NSKeyedUnarchiver unarchiveObjectWithData:keychainData];
            for (NSData *data in keychainSetData) {
                JKIAPTransactionModel *model = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                [mutableArray addObject:model];
            }
        }
      
        JKIAPLog(@"当前获取的存档;%@",mutableArray);
        return mutableArray;
}

- (void)savePaymentTransactionModels:(NSArray <JKIAPTransactionModel *>*)models{
    

    NSMutableArray *mutableArray =[NSMutableArray new];
    for (JKIAPTransactionModel *model in models) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
        [mutableArray addObject:data];
    }

        NSData *saveData = [NSKeyedArchiver archivedDataWithRootObject:mutableArray];
    NSError *error = nil;
    BOOL result=  NO;
    
    while (!result) {
      result=  [SAMKeychain setPasswordData:saveData forService:_keychain_service account:_keychain_account error:&error];
          JKIAPLog(@"保存存档%@->%@,error:%@",models,(result ? @"success":@"failure"),error);
    }
}

- (void)cleanAllModels{
    [SAMKeychain deletePasswordForService:_keychain_service account:_keychain_account];
}




@end
