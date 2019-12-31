//
//  ViewController.m
//  IPADemo
//
//  Created by kane on 2018/8/7.
//  Copyright © 2018年 kane. All rights reserved.
//

#import "ViewController.h"
#import "JKIAPHelp.h"

//沙盒测试环境验证
#define SandBoxURL @"https://sandbox.itunes.apple.com/verifyReceipt"
//正式环境验证
#define AppStoreURL @"https://buy.itunes.apple.com/verifyReceipt"
@interface ViewController ()<JKIAPPayDelegate,UITableViewDelegate,UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UIButton *loginBtn;
@property (weak, nonatomic) IBOutlet UITableView *logTableView;
@property (weak, nonatomic) IBOutlet UITextField *accountField;
@property (nonatomic, strong) NSMutableArray *logArray;
@end
#define NonConsumable @"com.rayark.cytus2.bundle004"
#define Consumable @"com.rayark.cytus2.bundle004"
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [JKIAPManager sharedManager].delegate = self;
    [[JKIAPManager sharedManager] registerPay];
    
    self.accountField.text = @"test1";
   
    _logArray = [NSMutableArray new];
}
- (IBAction)loginBtnAction:(UIButton *)sender {
    if (sender.isSelected) {
       
        [sender setSelected:NO];
    }else{
        if (self.accountField.text.length==0) {
            return;
        }
        [sender resignFirstResponder];
       
        [sender setSelected:YES];
    }
    
}

- (IBAction)buyAction1:(id)sender {
    
    NSString *orderId = [NSString stringWithFormat:@"%ud",arc4random()%99999999];
    
    [[JKIAPManager sharedManager] buyProductWithUserID:self.accountField.text productIdentifier:NonConsumable orderId:orderId];
   
}
- (IBAction)buyAction2:(id)sender {
    NSString *orderId = [NSString stringWithFormat:@"%d",arc4random()];
    
    [[JKIAPManager sharedManager] buyProductWithUserID:self.accountField.text productIdentifier:NonConsumable orderId:orderId];
}
- (IBAction)restore:(id)sender {
    [[JKIAPManager sharedManager] restoreProducts];

}

- (void)onIAPPayFailue:(JKIAPTransactionModel *)model withError:(NSError *)error{
    NSString *log =[NSString stringWithFormat:@"demo--购买失败%@,订单号%@",error.localizedDescription,model];
    
    if (error.code == JKIAPError_HasUnfinishedTransaction) {
        [[JKIAPManager sharedManager] checkUnfinishTransaction];
    }
    NSLog(@"%@",log);
    [self JKIAPLog:log];
}

- (void)onIAPPaymentSucess:(JKIAPTransactionModel *)model{
    NSString *log =[NSString stringWithFormat:@"demo--购买完成,订单号%@",model.seriverOrder];
    NSLog(@"%@",log);
    [self JKIAPLog:log];
   
}


- (void)verifyWithModel:(JKIAPTransactionModel *)model resultAction:(VerifyRsultBlock)resultAction{
    

    NSString *appOrderId = model.seriverOrder;
    NSDictionary *dic = @{@"receipt-data":model.appStoreReceipt};
  __weak  __typeof(self)  weakSelf = self;
    [self networkingPOSTWithURLString:SandBoxURL parameters:dic jasonParmeter:YES success:^(id  _Nullable responseObject) {
        
        NSInteger appleCode = [responseObject[@"status"] integerValue];
        
        if (appleCode == 0) {
       
            NSString *log =[NSString stringWithFormat:@"本地验证苹果凭证成功:%@",responseObject];
            NSLog(@"%@",log);
            [weakSelf JKIAPLog:log];
            
            resultAction(JKIAPVerifyValid);
            //NSArray *array = responseObject[@"receipt"][@"in_app"];
           
            
        }else if (appleCode ==21005 ){
       
            NSString *log =[NSString stringWithFormat:@"苹果服务器不可用!%@",appOrderId];
            NSLog(@"%@",log);
            [weakSelf JKIAPLog:log];
            resultAction(JKIAPVerifyFailed);
            
            //[weakSelf checkUnchekReceipt];
        }else if (appleCode == 21007) {//沙箱订单
            NSString *log =[NSString stringWithFormat:@"本地验证苹果凭证失败:%@",responseObject];
            NSLog(@"%@",log);
            [weakSelf JKIAPLog:log];
          
          
        }else{
            NSString *log =[NSString stringWithFormat:@"本地验证苹果凭证失败:%ld",(long)appleCode];
            NSLog(@"%@",log);
            [weakSelf JKIAPLog:log];
             resultAction(JKIAPVerifyInvalid);
        }
        
    } failure:^(NSError *error) {
        
        resultAction(JKIAPVerifyFailed);
        NSString *log =[NSString stringWithFormat:@"本地验证苹果凭证失败!:%@",error];
        NSLog(@"%@",log);
        [weakSelf JKIAPLog:log];
     
    }];
}

- (IBAction)deletedAll:(id)sender {
    //仅用于测试
    [[JKIAPVerifyManager new] cleanAllModels];
}



/**
 获取苹果商店信息成功
 
 @param products 商店物品
 @param error 错误信息
 */
-(void)onLaunProductListFinish:(NSArray<SKProduct *>*)products withError:(NSError*)error{
   
    for (SKProduct *obj in products) {
        
        NSString *log =[NSString stringWithFormat:@"demo--获取苹果商店信息成功%@",obj.productIdentifier];
        NSLog(@"%@",log);
        [self JKIAPLog:log];
    }
}



/**
 苹果恢复购买结果
 
 @param productIdentifiers 恢复购买结果
 @param error 错误信息
 */
-(void)onIAPRestoreResult:(NSArray*)productIdentifiers  withError:(NSError*)error{

    NSString *log =[NSString stringWithFormat:@"demo-苹果恢复购买结果%@,error:%@",productIdentifiers,error];
    NSLog(@"%@",log);
    [self JKIAPLog:log];
}

/**
 发货成功回调
 
 @param model 交易模型
 */
-(void)onDistributeGoodsFinish:(JKIAPTransactionModel*)model{
 
    NSString *log =[NSString stringWithFormat:@"demo-发货成功%@:%@",model.productIdentifier,model.seriverOrder];
    NSLog(@"%@",log);
    [self JKIAPLog:log];
}

//发货失败回调(业务错误)
//如果code=10001 则需要补发,其他错误则不需要
-(void)onDistributeGoodsFailue:(JKIAPTransactionModel*)model withError:(NSError *)error{
    
    NSString *log =[NSString stringWithFormat:@"demo-发货失败%@:%@,error:%@",model.productIdentifier,model.seriverOrder,error];
    NSLog(@"%@",log);
    [self JKIAPLog:log];
}


/*******************补发回调用********************/

//补发货成功回调
-(void)onRedistributeGoodsFinish:(JKIAPTransactionModel*)model{
    
    
    NSString *log =[NSString stringWithFormat:@"demo-补发货成功%@:%@",model.productIdentifier,model.seriverOrder];
    NSLog(@"%@",log);
    [self JKIAPLog:log];
}

//补发货失败回调
-(void)onRedistributeGoodsFailue:(JKIAPTransactionModel*)model withError:(NSError *)error{
    NSString *log =[NSString stringWithFormat:@"demo-补发货失败%@:%@",model.productIdentifier,model.seriverOrder];
    NSLog(@"%@",log);
    [self JKIAPLog:log];
}

/*******************补发回调用********************/

- (void)JKIAPLog:(NSString *)log{
  
   
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
         [self.logArray addObject:log];
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:weakSelf.logArray.count-1 inSection:0];
        [indexPaths addObject: indexPath];
        
        [weakSelf.logTableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        
        NSIndexPath *midIndex =   [weakSelf.logTableView indexPathForRowAtPoint:CGPointMake(2, self->_logTableView.contentOffset.y+weakSelf.logTableView.frame.size.height-20)];
        
        NSInteger row =indexPath.row -midIndex.row ;
        if (row < 10) {
            [weakSelf  tableViewScollToBottomWithAnimated:YES];
        }
    });
}

#pragma mark *** tableView delegate ***
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.logArray.count;
}

static NSString *const kReUsableCellIdentifier= @"cellIdentifier";
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView  dequeueReusableCellWithIdentifier:kReUsableCellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kReUsableCellIdentifier];
        cell.textLabel.font = [UIFont systemFontOfSize:12];
        cell.textLabel.numberOfLines =0;
    }
    cell.textLabel.text = self.logArray[indexPath.row];
    return cell;
}
- (void)tableViewScollToBottomWithAnimated:(BOOL)animated{
    NSInteger lastRowIndex = [self.logTableView numberOfRowsInSection:0] - 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (lastRowIndex > 0) {
            NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:lastRowIndex inSection:0];
            [self.logTableView scrollToRowAtIndexPath:lastIndexPath atScrollPosition: UITableViewScrollPositionBottom animated:animated];
        }
    });
    
}
#pragma mark - NetWork


/**
 网络请求

 @param URLString 地址
 @param parameters 参数
 @param jasonParmeter 是否传jason
 @param success 成功
 @param failure 失败
 */
- (void)networkingPOSTWithURLString:(NSString *)URLString
                         parameters:(nullable NSDictionary*)parameters
                      jasonParmeter:(BOOL)jasonParmeter
                            success:(nullable void (^)(id _Nullable responseObject))success
                            failure:(nullable void (^)(NSError *error))failure{
    // 1、创建URL资源地址
    NSURL *url = [NSURL URLWithString:URLString];
    // 2、创建Reuest请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 10;


    // 设置头部参数
    // [request addValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
    [request setValue:@"application/x-www-form-urlencoded;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    // 4、构造请求参数
    // 4.3、NSString转成NSData数据类型。
    NSData *payloadData = nil;
    if (jasonParmeter) {
        payloadData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:nil];
    }else{
        // 4.2、遍历字典，以“key=value&”的方式创建参数字符串。
        NSMutableString *parameterString = [[NSMutableString alloc]init];
        int pos =0;
        for (NSString *key in parameters.allKeys) {
            // 拼接字符串
            [parameterString appendFormat:@"%@=%@", key, parameters[key]];
            if(pos<parameters.allKeys.count-1){
                [parameterString appendString:@"&"];
            }
            pos++;
        }

        payloadData = [parameterString dataUsingEncoding:NSUTF8StringEncoding];
    }


    // 5、设置请求报文
    [request setHTTPBody:payloadData];
    // 8、创建会话任务

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (failure) {
                failure(error);
            }
        }else{

            NSError *err;
            NSDictionary *jsondic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&err];

            if (success) {
                success(jsondic);
            }
        }
    }];
    // 9、执行任务
    [task resume];

}







@end
