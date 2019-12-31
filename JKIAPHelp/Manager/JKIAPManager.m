//
//  JKIAPManager.m
//  JKIAPHelp
//
//  Created by kane on 2018/8/7.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "JKIAPManager.h"
#import "JKJailbreakDetectTool.h"
#import "JKReachability.h"
#import "JKIAPConfig.h"
#import "JKIAPVerifyManager.h"
#import "JKIAPActivityIndicator.h"
#import "NSError+JKIAPError.h"
#import "SAMKeychain.h"


typedef void(^ReceiptBlock)(NSString *receipt);
@interface JKIAPManager()<SKPaymentTransactionObserver,SKProductsRequestDelegate,JKIAPVerifyManagerDelegate>
{
    NSString *_appOrderID;
    NSString *_productIdentifier;
    NSString * _userId;
    JKIAPTransactionModel *_currentModel;//StatePurchasing后才有
    BOOL _isBuyProdutTofetchList;
    SKReceiptRefreshRequest *_refreshRequest;
    ReceiptBlock _receiptBlock;
    JKReachability *_reachability;
    BOOL _isUserAction;//主动触发检测订单
}



/// 当前loading状态
@property (nonatomic, assign) JKIAPLoadingStatus currentStatus;

/**
 * 获取商品列表请求.
 */
@property(nonatomic, weak) SKProductsRequest *currentProductRequest;




/* 验证管理 */
@property (nonatomic,strong)JKIAPVerifyManager *verifyManager;
@end

static  JKIAPManager *manager = nil;
@implementation JKIAPManager

/**
 * 单例方法.
 */
+ (instancetype)sharedManager{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [JKIAPManager new];
        [manager addNotificationObserver];
    });
    
    return manager;
}



- (BOOL)currentDeviceIsJailbroken{
    return  [JKJailbreakDetectTool detectCurrentDeviceIsJailbroken];
}
/*!
 @method
 @brief 判断当前iOS设备是否支持IAP支付
 @return YES:支持 NO:不支持
 @note 家长控制关闭iap，不允许越狱机器购买时 返回NO
 */
- (BOOL)checkCanPay{
    if ([self judgeJailbrokenCanPay]) {
        return [SKPaymentQueue canMakePayments];
    }
    return NO;
}


/**
 检测是否可以进行支付

 @return 不允许越狱机器购买时 返回NO
 */
- (BOOL)judgeJailbrokenCanPay{
    if (!JKIAPConfig.shouldJailbrokenPay && [JKJailbreakDetectTool detectCurrentDeviceIsJailbroken]) {
        JKIAPLog(@"越狱机器无法购买");
        return NO;
    }
    return YES;
}

/// 将本地模型转换成JKIAPTransactionModel
/// @param model JKIAPTransactionModel
- (void)resetKeychainService:( NSString * _Nullable )keychainService
             keychainAccount:( NSString * _Nullable )keychainAccount JKIAPTransactionModels:(NSArray<JKIAPTransactionModel *>*)models{
    if (!self.verifyManager) {
           self.verifyManager = [[JKIAPVerifyManager alloc] initWithKeychainService:keychainService keychainAccount:keychainAccount];
           self.verifyManager.delegate = self;
       }
    [self.verifyManager savePaymentTransactionModels:models];
 
    
}

/**
 * 注册支付事务监听, 并且开始支付凭证验证队列.
 *
 * @warning ⚠️ 请在用户登录时和用户重新启动 APP 时调用.
 */
- (void)registerPay{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [self registerPayWithKeychainService:nil keychainAccount:nil];
#pragma clang diagnostic pop
}
- (void)registerPayWithKeychainService:(NSString *)keychainService
              keychainAccount:(NSString *)keychainAccount{
    if (![self judgeJailbrokenCanPay]) {
        return ;
    }
    if (!self.verifyManager) {
        self.verifyManager = [[JKIAPVerifyManager alloc] initWithKeychainService:keychainService keychainAccount:keychainAccount];
        self.verifyManager.delegate = self;
    }
 
    if (!_reachability) {
        _reachability = [JKReachability reachabilityForInternetConnection];
        [_reachability startNotifier];
    }else{
        return;
    }
    
    
    SKPaymentQueue *defaultQueue = [SKPaymentQueue defaultQueue];
  
    BOOL processExistingTransactions = false;
       if (defaultQueue != nil && defaultQueue.transactions != nil)
       {
           if ([[defaultQueue transactions] count] > 0) {
               processExistingTransactions = true;
           }
       }

       [defaultQueue addTransactionObserver:self];
       if (processExistingTransactions) {
           [self paymentQueue:defaultQueue updatedTransactions:defaultQueue.transactions];
       }
        [self checkUnfinishedTransaction:NO];
    
}





#pragma mark - IAP

/**
 * 获取产品信息.
 *
 * @param productIdentifier 产品标识.
 */
- (void)fetchProductInfoWithProductIdentifier:(NSString *)productIdentifier{
    NSError *error = nil;
    if (!_verifyManager) {
        error = [NSError errorWithJKIAPCode:JKIAPError_NotRegistered];
    
    }else if ([self hasUnfinishedTransaction]) {
        error = [NSError errorWithJKIAPCode:JKIAPError_HasUnfinishedTransaction];
        
    }else if (self.currentStatus != JKIAPLoadingStatus_None) {
        error = [NSError errorWithJKIAPCode:JKIAPError_Paying];
  
    }else if (![self judgeJailbrokenCanPay]) {
        error = [NSError errorWithJKIAPCode:JKIAPError_Jailbroken];
       
    }else if (!productIdentifier) {
        error = [NSError errorWithJKIAPCode:JKIAPError_ProductId];
    }
    
   
    if (error) {
       if (_isBuyProdutTofetchList) {
           [self sendDelegateErrorMethod:@selector(onIAPPayFailue:withError:) error:error];
        }else{
           [self sendDelegateErrorMethod:@selector(onLaunProductListFinish:withError:) error:error];
            }
        return;
       }
    
    if (self.currentProductRequest) {
        [self.currentProductRequest cancel];
        self.currentProductRequest = nil;
    }
    
    _productIdentifier = productIdentifier;
    _isUserAction = YES;
        self.currentStatus = JKIAPLoadingStatus_CheckingProduct;
        
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:productIdentifier]];
        self.currentProductRequest = request;
        request.delegate = self;
        [request start];
    
  
}


/**
 恢复购买
 */
- (void)restoreProducts{

    NSError *error = nil;
    if (!_verifyManager) {
     error = [NSError errorWithJKIAPCode:JKIAPError_NotRegistered];
    }else  if ([self hasUnfinishedTransaction]) {
              error = [NSError errorWithJKIAPCode:JKIAPError_HasUnfinishedTransaction];
    }else if (self.currentStatus != JKIAPLoadingStatus_None) {
         error = [NSError errorWithJKIAPCode:JKIAPError_Paying];
    }
    
    if (error) {
        [self sendDelegateErrorMethod:@selector(onIAPRestoreResult:withError:) error:error];
        return;
    }
    _isUserAction = YES;
        self.currentStatus = JKIAPLoadingStatus_Restoring;
         [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    
}




- (void)buyProductWithUserID:(NSString *)userid
           productIdentifier:(NSString *)productIdentifier
                     orderId:(NSString *)orderId{
    
      NSError *error = nil;
   
    
      if (!_verifyManager) {
       error = [NSError errorWithJKIAPCode:JKIAPError_NotRegistered];
         
      }else  if ([self hasUnfinishedTransaction]) {
              error = [NSError errorWithJKIAPCode:JKIAPError_HasUnfinishedTransaction];
              
          }else  if (self.currentStatus != JKIAPLoadingStatus_None) {
           error = [NSError errorWithJKIAPCode:JKIAPError_Paying];
          }else if (!productIdentifier || ! orderId) {
        error = [NSError errorWithJKIAPCode:JKIAPError_Parameter];
       
    }else  if (![_reachability currentReachable]) {
         error = [NSError errorWithJKIAPCode:JKIAPError_Net];
    }

    if (error) {
        [self sendDelegateErrorMethod:@selector(onIAPPayFailue:withError:) error:error];
        return;
    }
    _userId = userid;
    _productIdentifier =productIdentifier;
    _appOrderID = orderId;
    _isBuyProdutTofetchList = YES;
    _isUserAction = YES;
    [self fetchProductInfoWithProductIdentifier:productIdentifier];
    
   
}

/**
 购买物品
@param payment SKPayment
 */
- (void)buyProductWithSKPayment:(SKPayment  *)payment{
    NSError *error = nil;
      if (!_verifyManager) {
       error = [NSError errorWithJKIAPCode:JKIAPError_NotRegistered];
          goto checkError;
      }
    if ([self hasUnfinishedTransaction]) {
              error = [NSError errorWithJKIAPCode:JKIAPError_HasUnfinishedTransaction];
              goto checkError;
          }
    
     if (self.currentStatus != JKIAPLoadingStatus_None) {
           error = [NSError errorWithJKIAPCode:JKIAPError_Paying];
         goto checkError;
     }
    
    if (![_reachability currentReachable]) {
         error = [NSError errorWithJKIAPCode:JKIAPError_Net];
    }
    checkError :
    if (error) {
        [self sendDelegateErrorMethod:@selector(onIAPPayFailue:withError:) error:error];
        return;
    }
     _isUserAction = YES;
    self.currentStatus = JKIAPLoadingStatus_Paying;
   
        [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (BOOL)hasUnfinishedTransaction{
      NSMutableArray *keychainSet =[self.verifyManager fetchAllPaymentTransactionModel];
    if (keychainSet.count > 0) {
        return  YES;
    }else{
        return NO;
    }
    
}

-(void)checkUnfinishTransaction{
    [self checkUnfinishedTransaction:YES];
}
-(void)checkUnfinishedTransaction:(BOOL)userAction{
   
    if (self.verifyManager.isVerifing) {
        self.currentStatus = JKIAPLoadingStatus_Verifying;
        return ;
    }
     _isUserAction = userAction;
    NSMutableArray *keychainSet =[self.verifyManager fetchAllPaymentTransactionModel];
  
    for (JKIAPTransactionModel *model in keychainSet) {
        if (model.transactionStatus == TransactionStatusSeriverSucc) {
            if (self.delegate &&[self.delegate respondsToSelector:@selector(onRedistributeGoodsFinish:)]) {
                    [self.delegate onRedistributeGoodsFinish:model];
                 [self finishTransationWithModel:model];
            }
        }else if (model.transactionStatus == TransactionStatusSeriverError || model.transactionStatus == TransactionStatusAppleSucc){
            //验证订单
                self.currentStatus = JKIAPLoadingStatus_Verifying;
            
            if (!model.appStoreReceipt) {
                __weak  __typeof(self)  weakSelf = self;
                [self fetchTransactionReceiptData:^(NSString *receipt) {
                    model.appStoreReceipt = receipt;
                    [weakSelf.verifyManager startPaymentTransactionVerifingModel:model];
                }];
            }else{
                    [self.verifyManager startPaymentTransactionVerifingModel :model];
            }
            
        }else if (model.transactionStatus == TransactionStatusSeriverFailed){
            if (self.delegate &&[self.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
                [self.delegate onRedistributeGoodsFailue:model withError:model.error];
                [self.verifyManager deletePaymentTransactionModel:model];
            }
        }else if (model.transactionStatus == TransactionStatusAppleFailed){
            if (self.delegate &&[self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
                [self.delegate onIAPPayFailue:model withError:model.error];
                [self.verifyManager deletePaymentTransactionModel:model];
            }
        }
    }
    
   
}

#pragma mark - SKProductsRequestDelegate
-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    JKIAPLog(@"-----------收到产品反馈信息--------------");
    NSArray *products =response.products;
   
    JKIAPLog(@"产品付费数量: %d", (int)[products count]);
    
    SKMutablePayment *payment = nil;
    NSString * price = nil;
    SKProduct *product = nil;
    for (SKProduct *p in products) {
        JKIAPLog(@"product info");
        JKIAPLog(@"产品标题 %@" , p.localizedTitle);
        JKIAPLog(@"产品描述信息: %@" , p.localizedDescription);
        JKIAPLog(@"价格: %@" , p.price);
        JKIAPLog(@"Product id: %@" , p.productIdentifier);
        price =p.price.stringValue;
        if ([p.productIdentifier isEqualToString:_productIdentifier]) {
            payment = [SKMutablePayment paymentWithProduct:p];
            product = p;
        }
    }
    
    if (!_isBuyProdutTofetchList) {
        NSError *error = nil;
        self.currentStatus = JKIAPLoadingStatus_None;
        if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
               if (!product) {
                     error = [NSError errorWithJKIAPCode:JKIAPError_ProductId];
                     
                      }
              [self.delegate onLaunProductListFinish:product withError:error];
        }

        return;
    }

    
    if (payment) {
       
        NSDictionary *JKIAPInfo = @{@"JKIAP_OrderID":_appOrderID,
                                    @"JKIAP_Price":price,
                                    @"JKIAP_UserId":_userId
        };
        payment.applicationUsername = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:JKIAPInfo options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
          JKIAPLog(@"开始进行购买: %@,%@" , payment.productIdentifier,payment.applicationUsername);
       
        self.currentStatus = JKIAPLoadingStatus_Paying;
       [[SKPaymentQueue defaultQueue] addPayment:payment];
        
    }else{
       NSError *error = [NSError errorWithJKIAPCode:JKIAPError_ProductId];
        [self sendDelegateErrorMethod:@selector(onIAPPayFailue:withError:) error:error];
        self.currentStatus = JKIAPLoadingStatus_None;
    }
    
 
}
#pragma mark - SKPaymentTransactionObserver



//监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction{
    for(SKPaymentTransaction *tran in transaction){
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:{
                
                [self verifyTransaction:tran];
             
            }
                break;
            case SKPaymentTransactionStatePurchasing:{
              
                   [self saveTransaction:tran];
            }
                break;
            case SKPaymentTransactionStateRestored:{
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            }
                break;
            case SKPaymentTransactionStateFailed:{
            
                    [self endFailedTransaction:tran];
                
            }
                break;

            case SKPaymentTransactionStateDeferred:
            {
                JKIAPLog(@"IAP_SKPaymentTransactionStateDeferred");
            }

                break;
            default:
                break;
        }
    }
}


- (void)verifyTransaction:(SKPaymentTransaction *)tran{
    
    NSString *order = tran.payment.applicationUsername;
    

    NSString *transactionIdentifier = tran.transactionIdentifier;
    if (!transactionIdentifier) {
        JKIAPLog(@"IAP_Lost transactionIdentifier!!!");
        transactionIdentifier = [NSUUID UUID].UUIDString;
    }
    JKIAPLog(@"IAP_购买完成,向自己的服务器验证 ---- %@,%@,paying:%d",tran.payment.productIdentifier, order,self.currentStatus);
  __weak  __typeof(self)  weakSelf = self;
       if (_currentModel ) {
           [self fetchTransactionReceiptData:^(NSString *receipt) {
               __strong  __typeof(self)  strongSelf = weakSelf;
               if (receipt == nil) {
                   if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
                                        [strongSelf.delegate onIAPPayFailue:strongSelf->_currentModel withError:tran.error];
                                 }
                   return ;
               }
              
            
               strongSelf->_currentModel.appStoreReceipt = receipt;
               strongSelf->_currentModel.transactionIdentifier =transactionIdentifier;
               [strongSelf.verifyManager startPaymentTransactionVerifingModel:strongSelf->_currentModel];
           }];
           
        }else{
            ///以前未结束订单苹果返回处理
            JKIAPTransactionModel *model = [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier applicationUsername:order];
            [self fetchTransactionReceiptData:^(NSString *receipt) {
                    __strong  __typeof(self)  strongSelf = weakSelf;
                model.appStoreReceipt = receipt;
                model.transactionIdentifier = transactionIdentifier;
                [strongSelf.verifyManager startPaymentTransactionVerifingModel:model];
            }];
        
    }
}



- (void)saveTransaction:(SKPaymentTransaction *)tran{
    
    
    NSString *order = tran.payment.applicationUsername;
    JKIAPLog(@"IAP_商品添加进列表,%@,username:%@",tran.payment.productIdentifier,order);
    
    _currentModel =  [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier applicationUsername:order];
    
    [self.verifyManager appendPaymentTransactionModel:_currentModel];
    
}

- (void)endFailedTransaction:(SKPaymentTransaction *)tran{
    NSString *order = tran.payment.applicationUsername;
    JKIAPLog(@"IAP_交易失败,%@,order:%@,error:%@", tran.payment.productIdentifier,order,tran.error);
    
    JKIAPTransactionModel *currentModel= _currentModel;
    if (!_currentModel) {
        currentModel = [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier applicationUsername:order];
    }
   
  
    if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
        [self.delegate onIAPPayFailue:currentModel withError:tran.error];
         [self.verifyManager deletePaymentTransactionModel:currentModel];
    }else{
        currentModel.error = tran.error;
        currentModel.transactionStatus = TransactionStatusSeriverFailed;
        [self.verifyManager updatePaymentTransactionModelStatus:currentModel];
    }
       [[SKPaymentQueue defaultQueue] finishTransaction:tran];
    
    if (self.currentStatus != JKIAPLoadingStatus_None && _currentModel) {
       
        self.currentStatus = JKIAPLoadingStatus_None;
        _currentModel = nil;
    }
   
}
#pragma mark - IAPRestore

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    
        JKIAPLog(@"IAP_received restored transactions: %lu", (unsigned long)queue.transactions.count);
    
        NSMutableArray *storeResult= [NSMutableArray new];
    
    
        [queue.transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction * _Nonnull transaction, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *productID = transaction.payment.productIdentifier;
            [storeResult addObject:productID];
            JKIAPLog(@"RestoreProductID %@",productID);
        }];
    self.currentStatus = JKIAPLoadingStatus_None;
    if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPRestoreResult:withError:)]) {
        [self.delegate onIAPRestoreResult:storeResult withError:nil];
    }
    
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error{
     JKIAPLog(@"RestoreError%@",error);
    self.currentStatus = JKIAPLoadingStatus_None;
    if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPRestoreResult:withError:)]) {
       [ self.delegate onIAPRestoreResult:nil withError:error];
    }
}



#pragma mark - Transation related

- (void)finishTransationWithModel:(JKIAPTransactionModel *)model {
    
    NSString *transactionIdentifier = model.transactionIdentifier;
    if (!transactionIdentifier) {
           [self.verifyManager deletePaymentTransactionModel:model];
        return;
    }
    // 未完成的列表.
    NSArray<SKPaymentTransaction *> *transactionsWaitingForVerifing = [[SKPaymentQueue defaultQueue] transactions];
    SKPaymentTransaction *targetTransaction = nil;
    for (SKPaymentTransaction *transaction in transactionsWaitingForVerifing) {
        if ([transactionIdentifier isEqualToString:transaction.transactionIdentifier]) {
            targetTransaction = transaction;
            break;
        }
    }
    
    ///如果没有找到对应的单据,并且只有一个未完成物品的productIdentifier与之匹配就能肯定是这个订单.
    if (transactionsWaitingForVerifing.count == 1) {
        SKPaymentTransaction *firstTransaction = transactionsWaitingForVerifing.firstObject;
        if ([firstTransaction.payment.productIdentifier isEqualToString:model.productIdentifier]) {
            targetTransaction = firstTransaction;
        }
    }
    
    // 可能会出现明明有未成功的交易, 但是 transactionsWaitingForVerifing 就是没有值.
    // 此时应该将这笔已经完成的订单状态存起来, 等待之后苹果返回这笔订单的时候在进行处理.
    if (!targetTransaction) {

        NSString *errorString = [NSString stringWithFormat:@"订单在后台验证成功, 但是从 IAP 的未完成订单里取不到这比交易的错误 transactionIdentifier: %@", transactionIdentifier];
        JKIAPLog(errorString);
        [self.verifyManager updatePaymentTransactionModelStatus:model];
    }else {
        JKIAPLog(@"准备删除储存订单:%@",model);
        [[SKPaymentQueue defaultQueue] finishTransaction:targetTransaction];
         [self.verifyManager deletePaymentTransactionModel:model];
        
    }
}

#pragma mark - JKIAPVerifyManagerDelegate

- (void)startPaymentTransactionVerifingModel:(JKIAPTransactionModel *)transactionModel{
    
      self.currentStatus = JKIAPLoadingStatus_Verifying;
    // 发送到苹果服务器验证凭证
    __weak typeof(self) weakSelf = self;
    if (self.delegate && [self.delegate respondsToSelector:@selector(verifyWithModel:resultAction:)]) {
        [self.delegate verifyWithModel:transactionModel resultAction:^(JKIAPVerifyResult result) {
            __strong  __typeof(self)  strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
            
            JKIAPLog(@"验证回调:product:%@",transactionModel);
             
            switch (result) {
                case JKIAPVerifyValid:
                {
                    transactionModel.transactionStatus = TransactionStatusSeriverSucc;
                    [strongSelf finishTransationWithModel:transactionModel];
                    strongSelf.currentStatus = JKIAPLoadingStatus_None;
                    
                    if (strongSelf->_currentModel && [strongSelf.delegate respondsToSelector:@selector(onDistributeGoodsFinish:)]) {
                 
                            
                            strongSelf->_currentModel = nil;
                        
                        [strongSelf.delegate onDistributeGoodsFinish:transactionModel];
                         
                    }else if ([strongSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFinish:)]) {
                        
                              [strongSelf.delegate onRedistributeGoodsFinish:transactionModel];
                        
                    }
                    
                   
                }
                    break;
                case JKIAPVerifyInvalid:
                {
                    transactionModel.transactionStatus = TransactionStatusSeriverFailed;
                     [strongSelf finishTransationWithModel:transactionModel];
                    NSError *error = [NSError errorWithJKIAPCode:JKIAPError_VerifyInvalid];
                    
                    if (strongSelf->_currentModel && [strongSelf.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
                      
                            strongSelf.currentStatus = JKIAPLoadingStatus_None;
                            strongSelf->_currentModel = nil;
                            [strongSelf.delegate onDistributeGoodsFailue:transactionModel withError:error];
                    }else  if ([strongSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
                        
                                [strongSelf.delegate onRedistributeGoodsFailue:transactionModel withError:error];
                    }
                }
                    break;
                    case JKIAPVerifyNeedRefreshReceipt:
                    {
                        transactionModel.transactionStatus = TransactionStatusSeriverError;
                        NSError *error = [NSError errorWithJKIAPCode:JKIAPError_VerifyInvalid];
                        transactionModel.appStoreReceipt = nil;
                        [self.verifyManager updatePaymentTransactionModelStatus:transactionModel];
                        if (strongSelf->_currentModel && [strongSelf.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
                          
                                strongSelf.currentStatus = JKIAPLoadingStatus_None;
                                strongSelf->_currentModel = nil;
                                [strongSelf.delegate onDistributeGoodsFailue:transactionModel withError:error];
                        }else  if ([strongSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
                            
                                    [strongSelf.delegate onRedistributeGoodsFailue:transactionModel withError:error];
                        }
                    }
                        break;
        
                default:
                {
                    transactionModel.transactionStatus = TransactionStatusSeriverError;
                    NSError *error = [NSError errorWithJKIAPCode:JKIAPError_VerifyInvalid];
                    if (strongSelf->_currentModel  && [strongSelf.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
                            strongSelf->_currentModel = nil;
                              [strongSelf.delegate onDistributeGoodsFailue:transactionModel withError:error];

                    }else  if ( [strongSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
                                [strongSelf.delegate onRedistributeGoodsFailue:transactionModel withError:error];
                    }
                }
            }
                [self.verifyManager finishPaymentTransactionVerifingModel:transactionModel];
             
                   self.currentStatus = JKIAPLoadingStatus_None;
                self->_isUserAction = NO;
            });
        }];
    }
}


#pragma mark -  FetchTransactionReceipt

/**
 获取当前票据
 
 */
- (void)fetchTransactionReceiptData:(ReceiptBlock)result{
    
    NSURL *appStoreReceiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:appStoreReceiptURL];
    NSString *receiptString=[receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    if(!receiptString){
        _refreshRequest= [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:nil];
        _refreshRequest.delegate = self;
        _receiptBlock = result;
        [self->_refreshRequest start];
    }else{
        result(receiptString);
        if (_receiptBlock) {
            _receiptBlock = nil;
        }
    }
    
    
}


#pragma mark -  SKRequestDelegate
- (void)requestDidFinish:(SKRequest *)request {
    
        if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
            JKIAPLog(@"IAP_SKReceiptRefreshRequest_Success");
            if (_receiptBlock) {
                [self fetchTransactionReceiptData:_receiptBlock];
            }
        }
  
    
}
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        JKIAPLog(@"IAP_SKReceiptRefreshRequest_Error:%@",error.localizedDescription);
        
       
        if (_receiptBlock) {
            if (_currentModel && error.code == 16) {
                _receiptBlock(nil);
                _receiptBlock = nil;
            }else{
                [self fetchTransactionReceiptData:_receiptBlock];
            }
            
        }
    }else if ([request isKindOfClass:[SKProductsRequest class]]){
        NSError *errorr = [NSError errorWithJKIAPCode:JKIAPError_Net];
               [self sendDelegateErrorMethod:@selector(onIAPPayFailue:withError:) error:errorr];
               self.currentStatus = JKIAPLoadingStatus_None;
    }
}

#pragma mark - privateMethods


- (void)sendDelegateErrorMethod:(SEL)sel error:(NSError *)error{
    if (self.delegate && [self.delegate respondsToSelector:sel]) {
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.delegate performSelector:sel withObject:nil withObject:error];
        #pragma clang diagnostic pop
     
    }
 
}


- (void)changLoadingStatus:(JKIAPLoadingStatus)status{
    if (JKIAPConfig.enableLoading && _isUserAction) {
          NSString *msg = nil;
             switch (status) {
                 case JKIAPLoadingStatus_CheckingProduct:
                     msg = @"查询商品中....";
                     break;
                     case JKIAPLoadingStatus_Paying:
                      msg = @"正在购买中....";
                     break;
                     case JKIAPLoadingStatus_Restoring:
                      msg = @"恢复购买中....";
                     break;
                     case JKIAPLoadingStatus_Verifying:
                      msg = @"验证订单中....";
                     break;
                 default:
                     break;
             }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (msg) {
                        [self.activityIndicatorController showActivityWithMessage:msg];
                   }else{
                       [self.activityIndicatorController stop];
                   }
        });
       
               
      }
}





#pragma mark - Notification

- (void)addNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didReceiveApplicationWillTerminateNotification) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)applicationWillEnterForegroundNotification:(NSNotification *)note {
    // 检查沙盒中没有持久化的交易.
    
      [self checkUnfinishedTransaction:NO];
}

- (void)didReceiveApplicationWillTerminateNotification {

    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
  
}


#pragma mark -  Getter && Setter

- (id<JKIAPActivityIndicatorProtocol>)activityIndicatorController{
    if (!_activityIndicatorController) {
        _activityIndicatorController = [JKIAPActivityIndicator new];
    }
    
    if (JKIAPConfig.enableLoading) {
        return _activityIndicatorController;
    }
    return nil;
}


- (void)setCurrentStatus:(JKIAPLoadingStatus)currentStatus{
    _currentStatus = currentStatus;
    if (_delegate && [_delegate respondsToSelector:@selector(currentStatus:)]) {
        [_delegate currentStatus:currentStatus];
    }
    [self changLoadingStatus:currentStatus];
}

@end
