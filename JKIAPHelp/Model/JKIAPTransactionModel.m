//
//  JKIAPTransactionModel.m
//  JKIAPHelp
//
//  Created by kane on 2018/8/8.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "JKIAPTransactionModel.h"
#import "JKIAPConfig.h"


@interface JKIAPTransactionModel ()
@end

@implementation JKIAPTransactionModel

- (NSString *)description {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd hh:mm:ss";
    NSString *dateString = [formatter stringFromDate:self.transactionDate];
    return [NSString stringWithFormat:@"productIdentifier: %@, transactionIdentifier: %@, transactionDate: %@,applicationUsername :%@, transactionStatus: %lu,cancelStatusCheckCount:%d", self.productIdentifier, self.transactionIdentifier, dateString,self.applicationUsername, (unsigned long)self.transactionStatus,self.cancelStatusCheckCount];
}




- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _productIdentifier = [aDecoder decodeObjectForKey:@"productIdentifier"];
        _transactionIdentifier = [aDecoder decodeObjectForKey:@"transactionIdentifier"];
        _transactionDate = [aDecoder decodeObjectForKey:@"transactionDate"];
        _seriverOrder = [aDecoder decodeObjectForKey:@"seriverOrder"];
        _priceString = [aDecoder decodeObjectForKey:@"priceString"];
     _applicationUsername = [aDecoder decodeObjectForKey:@"applicationUsername"];
        _userId =[aDecoder decodeObjectForKey:@"userId"];
        _transactionStatus = [aDecoder decodeIntegerForKey:@"transactionStatus"];
        _appStoreReceipt = [aDecoder decodeObjectForKey:@"appStoreReceipt"];
        _error = [aDecoder decodeObjectForKey:@"error"];
        _cancelStatusCheckCount = [[aDecoder decodeObjectForKey:@"cancelStatusCheckCount"] integerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.productIdentifier forKey:@"productIdentifier"];
    [aCoder encodeObject:self.transactionIdentifier forKey:@"transactionIdentifier"];
    [aCoder encodeObject:self.transactionDate forKey:@"transactionDate"];
    [aCoder encodeObject:self.seriverOrder forKey:@"seriverOrder"];
    [aCoder encodeObject:self.priceString forKey:@"priceString"];

    [aCoder encodeObject:self.applicationUsername forKey:@"applicationUsername"];
    [aCoder encodeObject:self.userId forKey:@"userId"];
    [aCoder encodeObject:self.appStoreReceipt forKey:@"appStoreReceipt"];
    
    [aCoder encodeInteger:self.transactionStatus forKey:@"transactionStatus"];
     [aCoder encodeObject:self.error forKey:@"error"];
      [aCoder encodeObject:@(self.cancelStatusCheckCount) forKey:@"cancelStatusCheckCount"];
}



+ (instancetype)modelWithProductIdentifier:(NSString *)productIdentifier
  applicationUsername:(NSString *)applicationUsername{
    NSParameterAssert(productIdentifier);
       //NSParameterAssert(orderId);
    
    JKIAPTransactionModel*model = [JKIAPTransactionModel new];
          model.productIdentifier = productIdentifier;
          
          model.applicationUsername = applicationUsername;
         
          model.transactionStatus = 0;
          model.transactionDate = [NSDate date];

    
    if (applicationUsername) {
         NSError *error = nil;
        
           NSData *data = [applicationUsername dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            NSDictionary *JKIAPInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
                     
                     if (!error && [JKIAPInfo isKindOfClass:[NSDictionary class]]) {
                         model.priceString = [JKIAPInfo objectForKey:@"JKIAP_Price"];
                         model.seriverOrder =  [JKIAPInfo objectForKey:@"JKIAP_OrderID"];
                         model.userId =  [JKIAPInfo objectForKey:@"JKIAP_UserId"];
                     }
        }
         
    }
       return model;
}

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
    if (object.applicationUsername) {
       isSeriverOrderMatch=  [self.applicationUsername  isEqualToString:object.applicationUsername];
    }
    return isTransactionIdentifierMatch && isProductIdentifierMatch&&isSeriverOrderMatch ;
}


#pragma mark -  Setter
- (void)setUserId:(NSString *)userId{
    if (userId) {
            _userId = userId;
    }

}
- (void)setProductIdentifier:(NSString *)productIdentifier{
    if (productIdentifier) {
            _productIdentifier = productIdentifier;
    }
}
- (void)setTransactionDate:(NSDate *)transactionDate{
    if (transactionDate) {
        _transactionDate = transactionDate;
    }
}
- (void)setSeriverOrder:(NSString *)seriverOrder{
    if (seriverOrder) {
        _seriverOrder = seriverOrder;
    }
}

- (void)setApplicationUsername:(NSString *)applicationUsername{
   
    _applicationUsername = applicationUsername;
    if (applicationUsername !=nil) {
           NSError *error = nil;
                 NSData *data = [applicationUsername dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            NSDictionary *JKIAPInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
                            if (!error && [JKIAPInfo isKindOfClass:[NSDictionary class]]) {
                                _priceString = [JKIAPInfo objectForKey:@"JKIAP_Price"];
                                _seriverOrder =  [JKIAPInfo objectForKey:@"JKIAP_OrderID"];
                                _userId =  [JKIAPInfo objectForKey:@"JKIAP_UserId"];
                            }
        }
                
       }
}


@end
