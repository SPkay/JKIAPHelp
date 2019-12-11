//
//  JKIAPVerifyManager.swift
//  JKIAPHelper
//
//  Created by Kane on 2019/8/7.
//  Copyright © 2019 kane. All rights reserved.
//

import UIKit

class JKIAPVerifyManager: NSObject {
    /* 代理 */
    @property (nonatomic,weak)id<JKIAPVerifyManagerDelegate> delegate;
    
    @property (nonatomic, copy) NSString *userId;
    
    
    @property (nonatomic, assign) BOOL isVerifing;
    
    JKIAPTransactionModel *_currentModel;
    NSMutableArray *_modelArray;
    NSString *_keychain_service;
    NSString *_keychain_account;
    /**
     * 初始化方法.
     */
    - (instancetype)initWithUserId:(NSString *)userId{
    self = [super init];
    if (self) {
    if (!_keychain_account) {
    _keychain_account= @"com.jkiap_keychain_account.www";
    }
    if (!_keychain_service) {
    _keychain_service =@"com.jkiap_keychain_service.www";
    }
    _userId = userId;
    _isVerifing = NO;
    _modelArray = [NSMutableArray new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeStatus:) name:JKIAPVerifyNotification object:nil];
    }
    return self;
    }
    
    - (instancetype)initWithUserId:(NSString *)userId keychainService:(NSString *)keychainService keychainAccount:(NSString *)keychainAccount{
    _keychain_service = keychainService;
    _keychain_account = keychainAccount;
    return   [self initWithUserId:userId];
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
    //防止重复验证
    for (JKIAPTransactionModel *model in _modelArray) {
    if ([model.transactionIdentifier isEqualToString:transactionModel.transactionIdentifier]) {
    return;
    }
    }
    __block   BOOL hasModel = NO;
    __block JKIAPTransactionModel *resultModel= transactionModel;
    NSMutableSet *keychainSet = [self fetchAllPaymentTransactionModel];
    [keychainSet enumerateObjectsUsingBlock:^(JKIAPTransactionModel*  _Nonnull model, BOOL * _Nonnull stop) {
    
    if (transactionModel.seriverOrder ) {
    if ([model.seriverOrder isEqualToString:transactionModel.seriverOrder]) {
    model.transactionIdentifier = transactionModel.transactionIdentifier;
    model.transactionStatus = TransactionStatusAppleSucc;
    if (transactionModel.appStoreReceipt) {
    model.appStoreReceipt = transactionModel.appStoreReceipt;
    }
    resultModel = model;
    hasModel = YES;
    *stop = YES;
    }
    }else if ([transactionModel.productIdentifier isEqualToString:model.productIdentifier]) {
    model.transactionIdentifier = transactionModel.transactionIdentifier;
    [transactionModel setValue:model.seriverOrder forKey:@"seriverOrder"];
    [transactionModel setValue:model.userId forKey:@"userId"];
    if (transactionModel.appStoreReceipt) {
    model.appStoreReceipt = transactionModel.appStoreReceipt;
    }
    model.transactionStatus = TransactionStatusAppleSucc;
    resultModel = model;
    hasModel = YES;
    *stop = YES;
    }
    
    
    }];
    if (hasModel) {
    //保存更改
    [self savePaymentTransactionModels:keychainSet];
    
    [_modelArray addObject:transactionModel];
    //开始验证
    [self verifingModel:resultModel];
    }
    
    
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
    
    NSData *keychainData = [SAMKeychain passwordDataForService:_keychain_service account:_keychain_account];
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
    
    - (void)savePaymentTransactionModels:(NSSet <JKIAPTransactionModel *>*)models{
    
    NSMutableSet *saveSet =[NSMutableSet new];
    for (JKIAPTransactionModel *model in models) {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
    [saveSet addObject:data];
    }
    
    NSData *saveData = [NSKeyedArchiver archivedDataWithRootObject:saveSet];
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
    
    - (void)changeStatus:(NSNotification*)notification{
    
    [_modelArray removeObject: notification.object];
    if (_modelArray.count>0) {
    [self verifingModel:_modelArray.firstObject];
    }else{
    _isVerifing = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:JKIAPVerifyFinishNotification object:nil];
    }
    
    }
    

}
