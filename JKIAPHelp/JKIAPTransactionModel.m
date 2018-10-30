//
//  JKIAPTransactionModel.m
//  JKIAPHelp
//
//  Created by kane on 2018/8/8.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "JKIAPTransactionModel.h"
#import "JKIAPConfig.h"
NSUInteger const kJKIAPPaymentTransactionModelVerifyWarningCount = 20; // 最多验证次数，如果超过这个值就报警。


@interface JKIAPTransactionModel ()

/**
 * 用户 id.
 */
@property(nonatomic, copy, readwrite) NSString *userId;
/**
 * 商品 id.
 */
@property(nonatomic, copy, readwrite) NSString *productIdentifier;

/**
 * 订单 id.
 */
@property(nonatomic, copy, readwrite) NSString *seriverOrder;

@property(nonatomic, strong, readwrite) NSDate *transactionDate;
@end

@implementation JKIAPTransactionModel
- (NSString *)description {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd hh:mm:ss";
    NSString *dateString = [formatter stringFromDate:self.transactionDate];
    return [NSString stringWithFormat:@"productIdentifier: %@, transactionIdentifier: %@, transactionDate: %@, orderNo:%@,  priceTagString: %@, transactionStatus: %lu,userId:%@", self.productIdentifier, self.transactionIdentifier, dateString, self.seriverOrder, self.priceString, (unsigned long)self.transactionStatus,self.userId];
}




- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _productIdentifier = [aDecoder decodeObjectForKey:@"productIdentifier"];
        _transactionIdentifier = [aDecoder decodeObjectForKey:@"transactionIdentifier"];
        _transactionDate = [aDecoder decodeObjectForKey:@"transactionDate"];
        _seriverOrder = [aDecoder decodeObjectForKey:@"seriverOrder"];
        _priceString = [aDecoder decodeObjectForKey:@"priceString"];
     _appleProductType = [aDecoder decodeIntegerForKey:@"appleProductType"];
        _userId =[aDecoder decodeObjectForKey:@"userId"];
        _transactionStatus = [aDecoder decodeIntegerForKey:@"transactionStatus"];
        _appStoreReceipt = [aDecoder decodeObjectForKey:@"appStoreReceipt"];
        _error = [aDecoder decodeObjectForKey:@"error"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.productIdentifier forKey:@"productIdentifier"];
    [aCoder encodeObject:self.transactionIdentifier forKey:@"transactionIdentifier"];
    [aCoder encodeObject:self.transactionDate forKey:@"transactionDate"];
    [aCoder encodeObject:self.seriverOrder forKey:@"seriverOrder"];
    [aCoder encodeObject:self.priceString forKey:@"priceString"];

    [aCoder encodeInteger:self.appleProductType forKey:@"appleProductType"];
    [aCoder encodeObject:self.userId forKey:@"userId"];
    [aCoder encodeObject:self.appStoreReceipt forKey:@"appStoreReceipt"];
    
    [aCoder encodeInteger:self.transactionStatus forKey:@"transactionStatus"];
     [aCoder encodeObject:self.error forKey:@"error"];
}

+ (instancetype)modelWithProductIdentifier:(NSString *)productIdentifier
                            appproductType:( AppleProductType)appproductType
                                     price:(NSString *)price
                                   orderId:(NSString *)orderId
                                    userId:(NSString *)userId{
    
    NSParameterAssert(productIdentifier);
    NSParameterAssert(orderId);

    JKIAPTransactionModel*model = [JKIAPTransactionModel new];
    model.productIdentifier = productIdentifier;
    model.priceString = price;
    model.appleProductType = appproductType;
    model.seriverOrder = orderId;
    model.transactionStatus = 0;
    model.transactionDate = [NSDate date];
    model.userId = userId;
    return model;
}

//- (void)setModelVerifyCount:(NSUInteger)modelVerifyCount {
//    _modelVerifyCount = modelVerifyCount;
//    
//    if (modelVerifyCount > kJKIAPPaymentTransactionModelVerifyWarningCount) {
//        NSString *errorString = [NSString stringWithFormat:@"验证次数超过最大验证次数: %@", self];
//        NSError *error = [NSError errorWithDomain:JKIAPErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : errorString}];
//    }
//}

#pragma mark - Private

- (BOOL)isEqual:(id)object {
    if (!object) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[JKIAPTransactionModel class]]) {
        return NO;
    }
    
    return [self isEqualToModel:((JKIAPTransactionModel *)object)];
}

- (BOOL)isEqualToModel:(JKIAPTransactionModel *)object {
    
    BOOL isProductIdentifierMatch = [self.productIdentifier isEqualToString:object.productIdentifier];
    
    BOOL isTransactionIdentifierMatch= YES;
    if (self.transactionIdentifier) {
         isTransactionIdentifierMatch =[self.transactionIdentifier isEqualToString:object.transactionIdentifier];
    }
    BOOL isSeriverOrderMatch = YES;
    if (object.seriverOrder) {
       isSeriverOrderMatch=  [self.seriverOrder isEqualToString:object.seriverOrder];
    }
   
 
    
    return isTransactionIdentifierMatch && isProductIdentifierMatch&&isSeriverOrderMatch ;
}
@end
