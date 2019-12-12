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


typedef void(^ReceiptBlock)(NSString *receipt);
@interface JKIAPManager()<SKPaymentTransactionObserver,SKProductsRequestDelegate,JKIAPVerifyManagerDelegate>
{
    NSString *_appOrderID;
    NSString *_productIdentifier;
    AppleProductType _productType;
    NSString * _userId;
    JKIAPTransactionModel *_currentModel;//StatePurchasing后才有
    BOOL _isBuyProdutTofetchList;
    SKReceiptRefreshRequest *_refreshRequest;
    SKMutablePayment *_currentPayment;//已获取到订单信息,还未开始购买
    ReceiptBlock _receiptBlock;
    JKReachability *_reachability;
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



/**
 * 注册支付事务监听, 并且开始支付凭证验证队列.
 *
 * @warning ⚠️ 请在用户登录时和用户重新启动 APP 时调用.
 *
 * @param userid 用户 ID.
 */
- (void)registerPayWithUserID:(NSString *)userid{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [self registerPayWithUserID:userid keychainService:nil keychainAccount:nil];
#pragma clang diagnostic pop
}
- (void)registerPayWithUserID:(NSString *)userid
              keychainService:(NSString *)keychainService
              keychainAccount:(NSString *)keychainAccount{
    if (![self judgeJailbrokenCanPay]) {
        return ;
    }
    if (self.verifyManager) {
        return;
    }
    _userId = userid;
    if (!_reachability) {
        _reachability = [JKReachability reachabilityForInternetConnection];
        [_reachability startNotifier];
    }
    
    self.verifyManager = [[JKIAPVerifyManager alloc] initWithUserId:userid keychainService:keychainService keychainAccount:keychainAccount];
    self.verifyManager.delegate = self;
    [self checkUnfinishedTransaction];
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    
}
/**
 注销支付管理
 */
- (void)unRegisterPay{
    if (![self judgeJailbrokenCanPay]) {
        return ;
    }
    if (self.currentProductRequest) {
        [self.currentProductRequest cancel];
        self.currentProductRequest = nil;
    }
        self.verifyManager = nil;
    
    
    _appOrderID = nil;
    _productIdentifier= nil;
   _userId= nil;
    _currentModel= nil;//StatePurchasing后才有
    _currentPayment= nil;//已获取到订单信息,还未开始购买
      [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark - IAP

/**
 * 获取产品信息.
 *
 * @param productIdentifiers 产品标识.
 */
- (void)fetchProductInfoWithProductIdentifiers:(NSSet<NSString *> *)productIdentifiers{
    NSError *error = nil;
    if (!_userId) {
        error = [NSError errorWithJKIAPCode:JKIAPError_NotRegistered];
        goto sendMsg;
    }
    if (self.currentStatus != JKIAPLoadingStatus_None) {
        error = [NSError errorWithJKIAPCode:JKIAPError_Paying];
        goto sendMsg;
    }
   
    if (![self judgeJailbrokenCanPay]) {
        error = [NSError errorWithJKIAPCode:JKIAPError_Jailbroken];
        goto sendMsg;
    }
    
    if (!productIdentifiers) {
        error = [NSError errorWithJKIAPCode:JKIAPError_ProductId];
        goto sendMsg;
    }
    if (![SKPaymentQueue canMakePayments]) {
         error = [NSError errorWithJKIAPCode:JKIAPError_Permission];
    }
    
    sendMsg :
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
    
    
        self.currentStatus = JKIAPLoadingStatus_CheckingProduct;
        
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
        self.currentProductRequest = request;
        request.delegate = self;
        [request start];
    
  
}


/**
 恢复购买
 */
- (void)restoreProducts{
     [self checkUnfinishedTransaction];
    NSError *error = nil;
    if (!_userId) {
     error = [NSError errorWithJKIAPCode:JKIAPError_NotRegistered];
    }
    
    if (self.currentStatus != JKIAPLoadingStatus_None) {
         error = [NSError errorWithJKIAPCode:JKIAPError_Paying];
    }
    
    if (error) {
        [self sendDelegateErrorMethod:@selector(onIAPRestoreResult:withError:) error:error];
        return;
    }
       
        self.currentStatus = JKIAPLoadingStatus_Restoring;
         [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    
}




- (void)buyProductWithProductIdentifier:(NSString *)productIdentifier
                         appproductType:( AppleProductType)appproductType
                                orderId:(NSString *)orderId {
    
      [self checkUnfinishedTransaction];
    
    if ([orderId isEqualToString:_appOrderID]) {
           return;
       }
    
      NSError *error = nil;
      if (!_userId) {
       error = [NSError errorWithJKIAPCode:JKIAPError_NotRegistered];
          goto checkError;
      }
    
     if (self.currentStatus != JKIAPLoadingStatus_None) {
           error = [NSError errorWithJKIAPCode:JKIAPError_Paying];
         goto checkError;
     }
    
    if (!productIdentifier || ! orderId) {
        error = [NSError errorWithJKIAPCode:JKIAPError_Parameter];
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

    _productIdentifier =productIdentifier;
    _appOrderID = orderId;
    _productType = appproductType;
    _isBuyProdutTofetchList = YES;
    
    [self fetchProductInfoWithProductIdentifiers:[NSSet setWithObject:productIdentifier]];
    
   
}

-(void)checkUnfinishedTransaction{
    if (self.verifyManager.isVerifing) {
        return ;
    }
    
    if (![_reachability currentReachable]) {
        return ;
    }
    
    NSMutableSet *keychainSet =[self.verifyManager fetchAllPaymentTransactionModel];
    NSMutableSet *resultSet = [NSMutableSet new];
    [keychainSet enumerateObjectsUsingBlock:^(JKIAPTransactionModel*  _Nonnull model, BOOL * _Nonnull stop) {
        if ([model.userId isEqualToString:self->_userId]) {
            [resultSet addObject:model];
        }
    }];
    for (JKIAPTransactionModel *model in resultSet) {
        if (model.transactionStatus == TransactionStatusSeriverSucc) {
            if (self.delegate &&[self.delegate respondsToSelector:@selector(onRedistributeGoodsFinish:)]) {
                    [self.delegate onRedistributeGoodsFinish:model];
                 [self.verifyManager deletePaymentTransactionModel:model];
            }
        }else if (model.transactionStatus == TransactionStatusSeriverError || model.transactionStatus == TransactionStatusAppleSucc){
            //验证订单
      
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
    if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
        [self.delegate onLaunProductListFinish:products withError:nil];
    }
    JKIAPLog(@"产品付费数量: %d", (int)[products count]);
    if (!_isBuyProdutTofetchList) {
        self.currentStatus = JKIAPLoadingStatus_None;
        _isBuyProdutTofetchList = NO;
        return;
    }
    SKMutablePayment *payment = nil;
    NSInteger price = 0;
    for (SKProduct *p in products) {
        JKIAPLog(@"product info");
        JKIAPLog(@"产品标题 %@" , p.localizedTitle);
        JKIAPLog(@"产品描述信息: %@" , p.localizedDescription);
        JKIAPLog(@"价格: %@" , p.price);
        JKIAPLog(@"Product id: %@" , p.productIdentifier);
        price =p.price.integerValue;
        if ([p.productIdentifier isEqualToString:_productIdentifier]) {
            payment = [SKMutablePayment paymentWithProduct:p];
        }
    }
    
    
    NSError *error=nil ;
    if (payment) {
       
        NSArray *order = @[_appOrderID,@(price)];
        payment.applicationUsername = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:order options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
          JKIAPLog(@"开始进行购买: %@,%@" , payment.productIdentifier,payment.applicationUsername);
       
        self.currentStatus = JKIAPLoadingStatus_Paying;
        if (self.verifyManager.isVerifing) {
              _currentPayment = payment;
        }else{
             [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
    }else{
        error = [NSError errorWithJKIAPCode:JKIAPError_ProductId];
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
                JKIAPLog(@"IAP_恢复购买");
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
    NSString* payAmount =@"";
    NSString *orderId = @"";
    NSArray *array = [NSJSONSerialization JSONObjectWithData:[order dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if (array) {
        orderId = array[0];
        payAmount  = array[1] ;
    }
//    if (!orderId) {
//        //丢失信息,需要人工验证
//        [self endFailedTransaction:tran];
//       
//        return;
//    }
    NSString *transactionIdentifier = tran.transactionIdentifier;
    if (!transactionIdentifier) {
        transactionIdentifier = [NSUUID UUID].UUIDString;
    }
    JKIAPLog(@"IAP_购买完成,向自己的服务器验证 ---- %@,paying:%d", orderId,self.currentStatus);
  __weak  __typeof(self)  weakSelf = self;
       if (_currentModel && [orderId isEqualToString:_currentModel.seriverOrder]) {
           
           if (_currentModel.transactionStatus == TransactionStatusSeriverSucc || _currentModel.transactionStatus == TransactionStatusSeriverFailed) {
               [self finishTransationWithModel:_currentModel];
               return;
           }
         
           [self fetchTransactionReceiptData:^(NSString *receipt) {
            __strong  __typeof(self)  strongSelf = weakSelf;
               strongSelf->_currentModel.appStoreReceipt = receipt;
               strongSelf->_currentModel.transactionIdentifier =transactionIdentifier;
               [weakSelf.verifyManager startPaymentTransactionVerifingModel:strongSelf->_currentModel];
           }];
           
        }else{
         JKIAPTransactionModel *model = [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier appproductType:AppleProductType_Unknow price:payAmount orderId:orderId userId:_userId];
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
    JKIAPLog(@"IAP_商品添加进列表,username:%@",order);
    NSString* payAmount =@"";
    NSString *orderId = @"";
    if (order) {
        NSArray *array = [NSJSONSerialization JSONObjectWithData:[order dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
        if (array) {
            orderId = array[0];
            payAmount  = array[1] ;
        }
    }
    
    _currentModel =  [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier appproductType:_productType price:payAmount orderId:orderId userId:_userId];
    
    [self.verifyManager appendPaymentTransactionModel:_currentModel];
    
}

- (void)endFailedTransaction:(SKPaymentTransaction *)tran{
    NSString *order = tran.payment.applicationUsername;
    JKIAPLog(@"IAP_交易失败,order:%@,error:%@", order,tran.error);
    JKIAPTransactionModel *currentModel= _currentModel;
    if (!_currentModel) {
        NSString* payAmount =@"";
        NSString *orderId = @"";
        if (order) {
            NSArray *array = [NSJSONSerialization JSONObjectWithData:[order dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
            if (array) {
                orderId = array[0];
                payAmount  = array[1] ;
            }
        }
        
     currentModel = [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier appproductType:AppleProductType_Unknow price:payAmount orderId:orderId userId:nil];
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
            NSString *applicationUsername = transaction.payment.applicationUsername;
            NSString *productID = transaction.payment.productIdentifier;
            if (!applicationUsername) {
                applicationUsername = @"";
            }
            [storeResult addObject:productID];
            JKIAPLog(@"RestoreProductID %@,Username:%@",productID,applicationUsername);
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
    // 未完成的列表.
    NSArray<SKPaymentTransaction *> *transactionsWaitingForVerifing = [[SKPaymentQueue defaultQueue] transactions];
    SKPaymentTransaction *targetTransaction = nil;
    for (SKPaymentTransaction *transaction in transactionsWaitingForVerifing) {
        if ([transactionIdentifier isEqualToString:transaction.transactionIdentifier]) {
            targetTransaction = transaction;
            break;
        }
    }
    
    // 可能会出现明明有未成功的交易, 但是 transactionsWaitingForVerifing 就是没有值.
    // 此时应该将这笔已经完成的订单状态存起来, 等待之后苹果返回这笔订单的时候在进行处理.
    if (!targetTransaction) {

        NSString *errorString = [NSString stringWithFormat:@"订单在后台验证成功, 但是从 IAP 的未完成订单里取不到这比交易的错误 transactionIdentifier: %@", transactionIdentifier];
        JKIAPLog(errorString);
        [self.verifyManager updatePaymentTransactionModelStatus:model];
    }else {
        JKIAPLog(@"准备删除储存订单:%@",model.seriverOrder);
        [[SKPaymentQueue defaultQueue] finishTransaction:targetTransaction];
        if ([model.userId isEqualToString:_userId]) {
                [self.verifyManager deletePaymentTransactionModel:model];
        }else{
        
            [self.verifyManager updatePaymentTransactionModelStatus:model];
        }
    }
}

#pragma mark - JKIAPVerifyManagerDelegate

- (void)startPaymentTransactionVerifingModel:(JKIAPTransactionModel *)transactionModel{
    
    
    // 发送到苹果服务器验证凭证
    __weak typeof(self) weakSelf = self;
    if (self.delegate && [self.delegate respondsToSelector:@selector(verifyWithModel:resultAction:)]) {
        [self.delegate verifyWithModel:transactionModel resultAction:^(JKIAPVerifyResult result) {
            __strong  __typeof(self)  strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
            
            JKIAPLog(@"验证回调:resutl:%d,订单号%@",result,transactionModel.seriverOrder);
                
            switch (result) {
                case JKIAPVerifyValid:
                {
                    transactionModel.transactionStatus = TransactionStatusSeriverSucc;
                    [strongSelf finishTransationWithModel:transactionModel];
                    
                    if (strongSelf->_currentModel && [strongSelf.delegate respondsToSelector:@selector(onDistributeGoodsFinish:)]) {
                 
                            strongSelf.currentStatus = JKIAPLoadingStatus_None;
                            strongSelf->_currentModel = nil;
                        
                       
                         if ([transactionModel.userId isEqualToString:strongSelf->_userId]) {
                              [strongSelf.delegate onDistributeGoodsFinish:transactionModel];
                         }
                    }else if ([strongSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFinish:)]) {
                        if ([transactionModel.userId isEqualToString:strongSelf->_userId]) {
                              [strongSelf.delegate onRedistributeGoodsFinish:transactionModel];
                        }
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
                        
                        if ([transactionModel.userId isEqualToString:strongSelf->_userId]) {
                            [strongSelf.delegate onDistributeGoodsFailue:transactionModel withError:error];
                        }
                        
                    }else  if ([strongSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
                        if ([transactionModel.userId isEqualToString:strongSelf->_userId]) {
                                [strongSelf.delegate onRedistributeGoodsFailue:transactionModel withError:error];
                        }
                     
                       
                    }
                }
                    break;
                default:
                {
                    transactionModel.transactionStatus = TransactionStatusSeriverError;
                    NSError *error = [NSError errorWithJKIAPCode:JKIAPError_VerifyInvalid];
                    if (strongSelf.currentStatus != JKIAPLoadingStatus_None && [strongSelf.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
                        if ( strongSelf->_currentModel) {
                            strongSelf.currentStatus = JKIAPLoadingStatus_None;
                            strongSelf->_currentModel = nil;
                        }
                        if ([transactionModel.userId isEqualToString:strongSelf->_userId]) {
                              [strongSelf.delegate onDistributeGoodsFailue:transactionModel withError:error];
                        }
                      
                        
                    }else  if (strongSelf.currentStatus == JKIAPLoadingStatus_None && [strongSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
                        if ([transactionModel.userId isEqualToString:strongSelf->_userId]) {
                                [strongSelf.delegate onRedistributeGoodsFailue:transactionModel withError:error];
                        }
                    
                    
                    }
                }
            }
                //发送通知,启动下一次订单验证
                [[NSNotificationCenter defaultCenter] postNotificationName:JKIAPVerifyNotification object:transactionModel];
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
            [self fetchTransactionReceiptData:_receiptBlock];
        }
    }
}

#pragma mark - privateMethods


- (void)sendDelegateErrorMethod:(SEL)sel error:(NSError *)error{
    if (self.delegate && [self.delegate respondsToSelector:sel]) {
           [self.delegate performSelector:sel withObject:nil withObject:error];
    }
 
}


- (void)changLoadingStatus:(JKIAPLoadingStatus)status{
    if (JKIAPConfig.enableLoading) {
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
        if (msg) {
             [self.activityIndicatorController showActivityWithMessage:msg];
        }else{
            [self.activityIndicatorController stop];
        }
               
      }
}

#pragma mark - Notification

- (void)addNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didReceiveApplicationWillTerminateNotification) name:UIApplicationWillTerminateNotification object:nil];
    
       [[NSNotificationCenter defaultCenter] addObserver:manager selector:@selector(verifyFinishNotification) name:JKIAPVerifyFinishNotification object:nil];
}

- (void)applicationWillEnterForegroundNotification:(NSNotification *)note {
    // 检查沙盒中没有持久化的交易.
    [self checkUnfinishedTransaction];
}

- (void)didReceiveApplicationWillTerminateNotification {

    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
      [[NSNotificationCenter defaultCenter] removeObserver:self];
  
}

- (void)verifyFinishNotification{
    
    if (_currentPayment) {
        [[SKPaymentQueue defaultQueue] addPayment:_currentPayment];
        _currentPayment = nil;
    }
    
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
    if (_delegate && [_delegate respondsToSelector:@selector(currentStatus)]) {
        [_delegate currentStatus:currentStatus];
    }
    [self changLoadingStatus:currentStatus];
}

@end
