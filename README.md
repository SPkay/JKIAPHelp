# JKIAPHelp
## JKIAPHelp用于Apple内购,解决内购中遇到的丢单问题.(用户支付成功,无法得到对应的商品)
### *本方案目前只适用于从自己的服务器获取到订单后再开始进入苹果的内购流程.*
### 内购有很多坑,一般来说会出现的问题有:

 1. 用户购买,IAP无回调响应,用户退出程序导致定单异常.
 2. 用户购买成功,自己的服务器网络发生错误,无法及时到账.
 3. SKPaymentTransaction.applicationUsername丢失的问题.
 4. 用户卸载程序导致本地订单号丢失.
 5. 获取本地苹果票据为空.
 ---
 
### 解决方案基本逻辑:
 在系统支付回调
 
> -(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction

 SKPaymentTransactionStatePurchasing时将订单相关信息加入到钥匙串中保证订单信息的完整性与可靠性,然后在SKPaymentTransactionStatePurchased的时候来验证订单.验证是通过开发者实现JKIAP代理
> -(void)verifyWithModel:(JKIAPTransactionModel *)model resultAction:(VerifyRsultBlock)resultAction

 来向开发者自己的服务器完成订单的验证.如果验证出现失效或者完成那么就判断当前的用户是否和创建订单时候的用户一致,如果一致那么久删除钥匙串里对应的订单完成购买,不一致的话就将状态同步到钥匙串里,当下一次用户注册时通过补发货的回调来通知开发者.
 如果服务器验证网络错误,就同步钥匙串订单状态.当用户**点击购买,从后台进入程序,重新注册JKIAP**时就会检测当前未完成的订单,将未完成的订单再次验证,如果再次发生错误就下一次再验证,有多个未完成的话就继续验证下一个订单.
 
 一般来说SKPaymentTransaction.applicationUsername是储存外部订单信息的唯一地方了,在iOS12以前还能用requestData来储存,现在苹果禁止了...SKPaymentTransaction.applicationUsername丢失的问题相信很多开发者都遇到过.在JKIAP中如果丢失处理方式是通过对比UserID以及productIdentifier来确定一个以前在SKPaymentTransactionStatePurchasing时储存的订单.看视比较粗暴,但是因为苹果的交易是串行的,JKIAP里面也是串行验证,所以通过UserID和productIdentifier就能确定为同一个订单了.


 
### 使用方式:
 1. pod 'JKIAPHelp'或拖入JKIAPHelp文件夹
 2. 实现代理*JKIAPPayDelegate*,用于向自己的服务器进行订单验证
 ```
 -(void)verifyWithModel:(JKIAPTransactionModel *)model resultAction:(VerifyRsultBlock)resultAction{
 
 //验证完成后调用resultAction来通知JKIAPManager完成验证.
 
       //例如 resultAction(JKIAPVerifyValid);
 } 
 ```
 3. 实现发货的回调,通过回调来进行发货操作.
 ```
 // 发货成功回调
 -(void)onDistributeGoodsFinish:(JKIAPTransactionModel*)model;
 
 //发货失败回调
 -(void)onDistributeGoodsFailue:(JKIAPTransactionModel*)model withError:(NSError *)error;

//补发货成功回调
-(void)onRedistributeGoodsFinish:(JKIAPTransactionModel*)model;

//补发货失败回调
-(void)onRedistributeGoodsFailue:(JKIAPTransactionModel*)model withError:(NSError *)error;
```
 4. 注册
 `[[JKIAPManager sharedManager] registerPayWithUserID:@"userOne"];`
 5. 购买
 `  [[JKIAPManager sharedManager] buyProductWithProductIdentifier:@"com.objId.com" appproductType:AppleProductType_Consumable orderId:@"orderId"];`
 
