//
//  JKIAPManager.m
//  JKIAPHelp
//
//  Created by kane on 2018/8/7.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "JKIAPManager.h"
#import "JKJailbreakDetectTool.h"

#import "JKIAPConfig.h"
#import "JKIAPVerifyManager.h"
#import "JKIAPActivityIndicator.h"




@interface JKIAPManager()<SKPaymentTransactionObserver,SKProductsRequestDelegate,JKIAPVerifyManagerDelegate>
{
    NSString *_appOrderID;
    NSString *_productIdentifier;
    AppleProductType _productType;
    NSString * _userId;
    JKIAPTransactionModel *_currentModel;
    BOOL _isBuyProdutTofetchList;

}
/** 请求中 */
@property (nonatomic, assign,readwrite) BOOL isPaying;


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
    
        [manager addObserver:manager forKeyPath:@"isPaying" options:NSKeyValueObservingOptionNew context:nil];
        
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
    if (![self judgeJailbrokenCanPay]) {
        return ;
    }
    if (self.verifyManager) {
        return;
    }
    
  
    _userId = userid;
    
    self.verifyManager = [[JKIAPVerifyManager alloc] initWithUserId:userid];
    self.verifyManager.delegate = self;
  
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
      [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}



#pragma mark - IAP
//withProductType:(AppproductType)productType
/**
 * 获取产品信息.
 *
 * @param productIdentifiers 产品标识.
 */
- (void)fetchProductInfoWithProductIdentifiers:(NSSet<NSString *> *)productIdentifiers{
    if (self.isPaying) {
        
        if (_isBuyProdutTofetchList) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
                [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"正在购买或者请求商品中...."}]];
            }
        }else{
            if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
                [self.delegate onLaunProductListFinish:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"正在购买或者请求商品中...."}]];
            }
        }
        return;
    }
    
    if (![self judgeJailbrokenCanPay]) {
        if (_isBuyProdutTofetchList) {
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
                [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"越狱机器无法购买...."}]];
            }
        }else{
            if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
                [self.delegate onLaunProductListFinish:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"越狱机器无法购买...."}]];
            }
        }
        return;
    }
    
    if (!productIdentifiers) {
        if (_isBuyProdutTofetchList) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
                [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"参数无效...."}]];
            }
        }else{
            if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
                [self.delegate onLaunProductListFinish:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"参数无效...."}]];
            }
        }
        
        return;
    }
    
    if (self.currentProductRequest) {
        [self.currentProductRequest cancel];
        self.currentProductRequest = nil;
    }
    
    if ([SKPaymentQueue canMakePayments]) {
           self.isPaying = YES;
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
        self.currentProductRequest = request;
        request.delegate = self;
        [request start];
    
    }else {
        
        NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"用户禁止应用内付费购买"}];
        if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
            [self.delegate onLaunProductListFinish:nil withError:error];
        }
    }
    
  
}


/**
 恢复购买
 */
- (void)restoreProducts{
    if (self.isPaying) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPRestoreResult:withError:)]) {
            [self.delegate onIAPRestoreResult:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"正在购买或者请求商品中...."}]];
        }
    }else{
        self.isPaying = YES;
         [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    }
}

/**
 购买物品(苹果购买完成后再生成订单)
 
 @param productIdentifier 物品标识
 @param appproductType 物品类型
 */
- (void)buyProductWithProductIdentifier:(NSString *)productIdentifier appproductType:( AppleProductType)appproductType{
    
}


- (void)buyProductWithProductIdentifier:(NSString *)productIdentifier
                         appproductType:( AppleProductType)appproductType
                                orderId:(NSString *)orderId {
    [self checkUnfinishedTransaction];
    
    if (self.isPaying) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
            [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"正在购买或者请求商品中...."}]];
        }
        return;
    }
    if (!productIdentifier || ! orderId) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
            [self.delegate onIAPPayFailue:nil withError:[NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"购买失败,参数错误...."}]];
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
            
            [self startPaymentTransactionVerifingModel:model];
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
    if (!_isBuyProdutTofetchList) {
        self.isPaying = NO;
        _isBuyProdutTofetchList = NO;
        if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
            [self.delegate onLaunProductListFinish:products withError:nil];
        }
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
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onLaunProductListFinish:withError:)]) {
        [self.delegate onLaunProductListFinish:products withError:nil];
    }
    
    
    NSError *error=nil ;
    if (payment) {
       
        NSArray *order = @[_appOrderID,@(price)];
        payment.applicationUsername = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:order options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
          JKIAPLog(@"开始进行购买: %@,%@" , payment.productIdentifier,payment.applicationUsername);
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        
    }else{
          error = [NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"没有购买的物品"}];
        if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPPayFailue:withError:)]) {
            [self.delegate onIAPPayFailue:nil withError:error];
        }
        self.isPaying = NO;
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
                self.isPaying = NO;
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
    NSArray *array = [NSJSONSerialization JSONObjectWithData:[order dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    if (array) {
        orderId = array[0];
        payAmount  = array[1] ;
    }
    if (!orderId) {
        [self endFailedTransaction:tran];
       
        return;
    }
    JKIAPLog(@"IAP_购买完成,向自己的服务器验证 ---- %@,paying:%d", orderId,self.isPaying);

       if (_currentModel && [orderId isEqualToString:_currentModel.seriverOrder]) {
           
           if (_currentModel.transactionStatus == TransactionStatusSeriverSucc || _currentModel.transactionStatus == TransactionStatusSeriverFailed) {
               [self finishTransationWithModel:_currentModel];
               return;
           }
           
            _currentModel.appStoreReceipt = [self fetchTransactionReceiptData];
            _currentModel.transactionIdentifier = tran.transactionIdentifier;
            [self.verifyManager startPaymentTransactionVerifingModel:_currentModel];
        }else{
         JKIAPTransactionModel *model = [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier appproductType:AppleProductType_Unknow price:payAmount orderId:orderId userId:nil];
         model.appStoreReceipt = [self fetchTransactionReceiptData];
         model.transactionIdentifier = tran.transactionIdentifier;
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
    
  _currentModel=  [JKIAPTransactionModel modelWithProductIdentifier:tran.payment.productIdentifier appproductType:_productType price:payAmount orderId:orderId userId:_userId];
    
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
   
    if (self.isPaying && _currentModel) {
        self.isPaying = NO;
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
   
    if (_currentModel) {
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
    self.isPaying = NO;
    if (self.delegate && [self.delegate respondsToSelector:@selector(onIAPRestoreResult:withError:)]) {
        [self.delegate onIAPRestoreResult:storeResult withError:nil];
    }
    
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error{
     JKIAPLog(@"RestoreError%@",error);
    self.isPaying = NO;
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
        if (self.isPaying && _currentModel) {
            self.isPaying = NO;
            _currentModel=nil;
        }
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
        
        NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"无本地票据"}];
        if (self.isPaying && [self.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
            [self.delegate onDistributeGoodsFailue:transactionModel withError:error];
        }else  if (!self.isPaying && [self.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
            [self.delegate onRedistributeGoodsFailue:transactionModel withError:error];
        }
        transactionModel.transactionStatus = TransactionStatusSeriverFailed;
        [self.verifyManager updatePaymentTransactionModelStatus:transactionModel];
        if (self.isPaying && _currentModel) {
            self.isPaying = NO;
            _currentModel = nil;
        }
        return;
    }
    // 发送到苹果服务器验证凭证
    __weak typeof(self) weakSelf = self;
    if (self.delegate && [self.delegate respondsToSelector:@selector(verifyWithModel:resultAction:)]) {
        [self.delegate verifyWithModel:transactionModel resultAction:^(JKIAPVerifyResult result) {
            [[NSNotificationCenter defaultCenter] postNotificationName:JKIAPVerifyNotification object:nil];
            JKIAPLog(@"验证回调:resutl:%d,订单号%@",result,transactionModel.seriverOrder);
            switch (result) {
                case JKIAPVerifyValid:
                {
                    transactionModel.transactionStatus = TransactionStatusSeriverSucc;
                    if (weakSelf.isPaying && [weakSelf.delegate respondsToSelector:@selector(onDistributeGoodsFinish:)]) {
                        
                        if ( self->_currentModel) {
                            weakSelf.isPaying = NO;
                            self->_currentModel = nil;
                        }
                         if ([transactionModel.userId isEqualToString:self->_userId]) {
                              [weakSelf.delegate onDistributeGoodsFinish:transactionModel];
                         }
                       
                        [weakSelf finishTransationWithModel:transactionModel];
                    }else if (!weakSelf.isPaying && [weakSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFinish:)]) {
                        if ([transactionModel.userId isEqualToString:self->_userId]) {
                              [weakSelf.delegate onRedistributeGoodsFinish:transactionModel];
                        }
                      
                        [weakSelf finishTransationWithModel:transactionModel];
                    }
                   
                }
                    break;
                case JKIAPVerifyInvalid:
                {
                    transactionModel.transactionStatus = TransactionStatusSeriverFailed;
                    NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"服务器验证失败"}];
                    if (weakSelf.isPaying && [weakSelf.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
                        if ( self->_currentModel) {
                            weakSelf.isPaying = NO;
                            self->_currentModel = nil;
                        }
                        if ([transactionModel.userId isEqualToString:self->_userId]) {
                            [weakSelf.delegate onDistributeGoodsFailue:transactionModel withError:error];
                        }
                        [weakSelf finishTransationWithModel:transactionModel];
                    }else  if (!weakSelf.isPaying && [weakSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
                        if ([transactionModel.userId isEqualToString:self->_userId]) {
                                [weakSelf.delegate onRedistributeGoodsFailue:transactionModel withError:error];
                        }
                     
                        [weakSelf finishTransationWithModel:transactionModel];
                    }
                }
                    break;
                default:
                {
                    transactionModel.transactionStatus = TransactionStatusSeriverError;
                    NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"验证请求网络错误"}];
                    if (weakSelf.isPaying && [weakSelf.delegate respondsToSelector:@selector(onDistributeGoodsFailue:withError:)]) {
                        if ( self->_currentModel) {
                            weakSelf.isPaying = NO;
                            self->_currentModel = nil;
                        }
                        if ([transactionModel.userId isEqualToString:self->_userId]) {
                              [weakSelf.delegate onDistributeGoodsFailue:transactionModel withError:error];
                        }
                      
                        
                    }else  if (!weakSelf.isPaying && [weakSelf.delegate respondsToSelector:@selector(onRedistributeGoodsFailue:withError:)]) {
                        if ([transactionModel.userId isEqualToString:self->_userId]) {
                                [weakSelf.delegate onRedistributeGoodsFailue:transactionModel withError:error];
                        }
                    
                    
                    }
                }
                    break;
            }
            
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
        
        SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] init];
        request.delegate = self;
        [request start];
        
    }
    return receiptString;
}




#pragma mark - privateMethods

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"isPaying"]) {
        
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
}

- (void)applicationWillEnterForegroundNotification:(NSNotification *)note {
    // 检查沙盒中没有持久化的交易.
    [self.verifyManager checkUnfinishedTransaction];
}

- (void)didReceiveApplicationWillTerminateNotification {
    if ([self currentDeviceIsJailbroken]) {
        return;
    }
    
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
      [[NSNotificationCenter defaultCenter] removeObserver:self];
  
}

- (JKIAPActivityIndicator *)activityView{
    if (!_activityView) {
        _activityView = [JKIAPActivityIndicator new];
        [_activityView setLableMessage:@"正在购买中...."];
    }
    return _activityView;
}


@end
