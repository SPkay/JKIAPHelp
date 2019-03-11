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
    JKReachability *_reachability;
}

/**
 是否允许越狱支付
 */
@property (nonatomic, assign) BOOL shouldJailbrokenPay;



/**
 是否允许Loading
 */
@property (nonatomic, assign) BOOL enableLoading;

/**
 * 获取商品列表请求.
 */
@property(nonatomic, weak) SKProductsRequest *currentProductRequest;


/* 活动指示器 */
@property (nonatomic,strong)JKIAPActivityIndicator *activityView;

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
        manager.shouldJailbrokenPay = NO;
        JKIAPConfig.enableLog = YES;
        manager.enableLoading = YES;
        [manager addNotificationObserver];
        [manager addObserver:manager forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:nil];
     
    });
    
    return manager;
}



/**
 * 是否允许越狱支付,默认NO
 */
- (void)shouldJailbrokenPay:(BOOL)jailbrokenPay{
      _shouldJailbrokenPay = jailbrokenPay;
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
- (BOOL)judgeIsCanPay{
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
    if (!self.shouldJailbrokenPay && [JKJailbreakDetectTool detectCurrentDeviceIsJailbroken]) {
        JKIAPLog(@"越狱机器无法购买");
        return NO;
    }
    return YES;
}


/*!
 @method
 @abstract 隐藏Loading（不建议）
 @discussion 防止用户多次重复购买，特加入loading
 @author bladebao
 */
- (void)hideLoading:(BOOL)hide{
    _enableLoading = !hide;
}

- (void)setIsEnLog:(BOOL)isEnable{
    JKIAPConfig.enableLog = isEnable;
}


/**
 * 注册支付事务监听, 并且开始支付凭证验证队列.
 *
 * @warning ⚠️ 请在用户登录时和用户重新启动 APP 时调用.
 *
 * @param userid 用户 ID.
 */
- (void)registerPayWithUserID:(NSString *)userid{
    [self registerPayWithUserID:userid keychainService:nil keychainAccount:nil];
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
    if (self.loading) {
        
        if (_isBuyProdutTofetchList) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
                [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Paying userInfo:@{NSLocalizedDescriptionKey:@"正在购买或者请求商品中...."}]];
            }
        }else{
            if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
                [self.delegate onLaunProductListFinish:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Paying userInfo:@{NSLocalizedDescriptionKey:@"正在购买或者请求商品中...."}]];
            }
        }
        return;
    }
    
    if (![self judgeJailbrokenCanPay]) {
        if (_isBuyProdutTofetchList) {
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
                [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Jailbroken userInfo:@{NSLocalizedDescriptionKey:@"越狱机器无法购买...."}]];
            }
        }else{
            if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
                [self.delegate onLaunProductListFinish:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Jailbroken userInfo:@{NSLocalizedDescriptionKey:@"越狱机器无法购买...."}]];
            }
        }
        return;
    }
    
    if (!productIdentifiers) {
        if (_isBuyProdutTofetchList) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
                [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Parameter userInfo:@{NSLocalizedDescriptionKey:@"参数无效...."}]];
            }
        }else{
            if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
                [self.delegate onLaunProductListFinish:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Parameter userInfo:@{NSLocalizedDescriptionKey:@"参数无效...."}]];
            }
        }
        
        return;
    }
    
    if (self.currentProductRequest) {
        [self.currentProductRequest cancel];
        self.currentProductRequest = nil;
    }
    
    if ([SKPaymentQueue canMakePayments]) {
        [self.activityView setLableMessage:@"查询商品中...."];
           self.loading = YES;
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
        self.currentProductRequest = request;
        request.delegate = self;
        [request start];
    
    }else {
        
        NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Permission userInfo:@{NSLocalizedDescriptionKey : @"用户禁止应用内付费购买"}];
        if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
            [self.delegate onLaunProductListFinish:nil withError:error];
        }
    }
    
  
}


/**
 恢复购买
 */
- (void)restoreProducts{
    if (self.loading) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPRestoreResult:withError:)]) {
            [self.delegate onIAPRestoreResult:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Paying userInfo:@{NSLocalizedDescriptionKey : @"正在购买或者请求商品中...."}]];
        }
    }else{
        [self.activityView setLableMessage:@"恢复购买中...."];
        self.loading = YES;
         [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    }
}




- (void)buyProductWithProductIdentifier:(NSString *)productIdentifier
                         appproductType:( AppleProductType)appproductType
                                orderId:(NSString *)orderId {
    if ([orderId isEqualToString:_appOrderID]) {
        return;
    }
    
    [self checkUnfinishedTransaction];
    
    if (self.loading) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
            [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Paying userInfo:@{NSLocalizedDescriptionKey:@"正在购买或者请求商品中...."}]];
        }
        return;
    }
    if (!productIdentifier || ! orderId) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
            [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Parameter userInfo:@{NSLocalizedDescriptionKey:@"购买失败,参数错误...."}]];
        }
        return;
    }
    if (![_reachability currentReachable]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
            [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Net userInfo:@{NSLocalizedDescriptionKey:@"无法连接网络...."}]];
        }
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
            [self.verifyManager startPaymentTransactionVerifingModel :model];
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
        self.loading = NO;
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
        [self.activityView setLableMessage:@"正在购买中...."];
      
        if (self.verifyManager.isVerifing) {
              _currentPayment = payment;
        }else{
             [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
    }else{
          error = [NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_ProductId userInfo:@{NSLocalizedDescriptionKey : @"没有购买的物品"}];
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
            [self.delegate onIAPPayFailue:nil withError:error];
        }
        self.loading = NO;
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
    JKIAPLog(@"IAP_购买完成,向自己的服务器验证 ---- %@,paying:%d", orderId,self.loading);

       if (_currentModel && [orderId isEqualToString:_currentModel.seriverOrder]) {
           
           if (_currentModel.transactionStatus == TransactionStatusSeriverSucc || _currentModel.transactionStatus == TransactionStatusSeriverFailed) {
               [self finishTransationWithModel:_currentModel];
               return;
           }
           
            _currentModel.appStoreReceipt = [self fetchTransactionReceiptData];
            _currentModel.transactionIdentifier =transactionIdentifier;
            [self.verifyManager startPaymentTransactionVerifingModel:_currentModel];
        }else{
         JKIAPTransactionModel *model = [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier appproductType:AppleProductType_Unknow price:payAmount orderId:orderId userId:_userId];
         model.appStoreReceipt = [self fetchTransactionReceiptData];
         model.transactionIdentifier = transactionIdentifier;
          [self.verifyManager startPaymentTransactionVerifingModel:model];
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
    
    if (self.loading && _currentModel) {
        self.loading = NO;
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
    self.loading = NO;
    if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPRestoreResult:withError:)]) {
        [self.delegate onIAPRestoreResult:storeResult withError:nil];
    }
    
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error{
     JKIAPLog(@"RestoreError%@",error);
    self.loading = NO;
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
    
    if (!transactionModel.appStoreReceipt) {
        transactionModel.appStoreReceipt=[self fetchTransactionReceiptData];
    }
    
    if (!transactionModel.appStoreReceipt) {
        
        NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_Receipt userInfo:@{NSLocalizedDescriptionKey:@"无本地票据"}];
        if (self.loading && [self.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
            [self.delegate onDistributeGoodsFailue:transactionModel withError:error];
        }else  if (!self.loading && [self.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
            [self.delegate onRedistributeGoodsFailue:transactionModel withError:error];
        }
        transactionModel.transactionStatus = TransactionStatusSeriverFailed;
        [self.verifyManager updatePaymentTransactionModelStatus:transactionModel];
        if (self.loading && _currentModel) {
            self.loading = NO;
            _currentModel = nil;
        }
            [[NSNotificationCenter defaultCenter] postNotificationName:JKIAPVerifyNotification object:transactionModel];
        return;
    }
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
                 
                            strongSelf.loading = NO;
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
                    NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_VerifyInvalid userInfo:@{NSLocalizedDescriptionKey:@"服务器验证失败"}];
                    
                    if (strongSelf->_currentModel && [strongSelf.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
                      
                            strongSelf.loading = NO;
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
                    NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:JKIAPError_VerifyInvalid userInfo:@{NSLocalizedDescriptionKey:@"验证请求网络错误"}];
                    if (strongSelf.loading && [strongSelf.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
                        if ( strongSelf->_currentModel) {
                            strongSelf.loading = NO;
                            strongSelf->_currentModel = nil;
                        }
                        if ([transactionModel.userId isEqualToString:strongSelf->_userId]) {
                              [strongSelf.delegate onDistributeGoodsFailue:transactionModel withError:error];
                        }
                      
                        
                    }else  if (!strongSelf.loading && [strongSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
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




/**
 获取当前票据
 
 @return 票据
 */
- (NSString *)fetchTransactionReceiptData{
    NSURL *appStoreReceiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:appStoreReceiptURL];
     NSString *receiptString=[receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    if(!receiptData){
        
        _refreshRequest= [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:nil];
        _refreshRequest.delegate = self;
        [_refreshRequest start];
        
    }
    return receiptString;
}


#pragma mark -  SKRequestDelegate
- (void)requestDidFinish:(SKRequest *)request {
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
                JKIAPLog(@"IAP_SKReceiptRefreshRequest_Success");
    }
}
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        JKIAPLog(@"IAP_SKReceiptRefreshRequest_Error:%@",error.localizedDescription);
    }
}

#pragma mark - privateMethods

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"loading"]) {
        
        BOOL vaule = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (vaule) {
            [self.activityView start];
        }else{
            [self.activityView stop];
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

#pragma mark -  Getter
- (JKIAPActivityIndicator *)activityView{
    if (!_activityView) {
        _activityView = [JKIAPActivityIndicator new];
        [_activityView setLableMessage:@"正在购买中...."];
    }
    return _activityView;
}

#pragma mark -  Setter

- (void)setLoading:(BOOL)loading{
    _loading = loading;
}
@end
