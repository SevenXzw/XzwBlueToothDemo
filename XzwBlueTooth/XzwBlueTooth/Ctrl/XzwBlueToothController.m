//
//  XzwBlueToothController.m
//  XzwBlueTooth
//
//  Created by Vilson on 16/5/13.
//  Copyright © 2016年 demo. All rights reserved.
//

/*
 *   暂时知道这些，后续有发现再更新
 *   纯属自己的理解可能有错误， 希望指正。 大家一起进步
 *   并且次demo只提供功能上的思路，界面可以自己调整
 */

#import "XzwBlueToothController.h"

//添加蓝牙CoreBluetooth框架头文件
#import <CoreBluetooth/CoreBluetooth.h>
//封装好的一个读写数据类
#import "BLEUtility.h"
/*
 每一个服务和特征都需要用一个UUID（unique identifier）去标识，UUID是一个16bit或者128bit的值
 你必须要确定你自己的UUID不能和其他已经存在的服务冲突即可
 */
//这里的UUID要和周边设备对应的UUID相同
static NSString * const kServiceUUID = @"FFF0";//服务UUID
static NSString * const kCharacteristicUUID = @"FFF1";//特征UUID
static NSString * const kNotificationUUID = @"FFF2"; //使能通知UUID

static NSString * const myCentralManagerIdentifier = @"com.adsmart.my1";//APP蓝牙标示符，唯一的

@interface XzwBlueToothController ()
/*
 实现两个协议
 CBCentralManagerDelegate:中央设备管理器代理
 CBPeripheralDelegate:周边设备代理
 */
<CBCentralManagerDelegate, CBPeripheralDelegate>
//中央设备管理器 用来管理所有的外围设备
@property (nonatomic, strong) CBCentralManager *manager;

//保存接收到的数据
@property (nonatomic, strong) NSMutableData *data;


//保存发现的周边设备
@property (nonatomic, strong) CBPeripheral *myPeripheral;

//保存特征
@property (nonatomic, strong) CBCharacteristic *myCharacteristic;

//蓝牙线程
@property (nonatomic,strong) dispatch_queue_t bleGCD;
@end

@implementation XzwBlueToothController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.data = [[NSMutableData alloc] init];
    //初始化蓝牙线程
    self.bleGCD = dispatch_queue_create("BLEgcd", NULL);
    #pragma  mark - 1、创建中央设备管理器
    //1、创建中央设备管理器
    //第一种初始化方法
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:self.bleGCD];
    //第二种初始化方法
    /*
     options 这个字典可以传两个KEY
     CBCentralManagerOptionRestoreIdentifierKey 对应的是该APP的蓝牙唯一标示符，如果系统蓝牙遇到了该APP连接过的蓝牙会根据这个ID唤醒APP
     CBCentralManagerOptionShowPowerAlertKey 对应的是一个布尔值  对应是否弹出提示  默认是弹提示
     
     */
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:self.bleGCD options:@{CBCentralManagerOptionRestoreIdentifierKey:myCentralManagerIdentifier}];
}
#pragma  mark - 回调方法 检测中央设备状态
-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        //如果蓝牙关闭，那么无法开启检测，直接返回
        NSLog(@"蓝牙关闭");
        return;
    }
    
#pragma mark - 2、扫描周边设备
    /*
     options 这个字典可以传两个KEY
     CBCentralManagerScanOptionAllowDuplicatesKey 对应的是 是否扫到了设备就回调 不自动过滤调重复扫描到的设备
     默认的是NO 即自动过去重复的外围设备
     
     CBCentralManagerScanOptionSolicitedServiceUUIDsKey 是用于告诉self.manager，要开始寻找一个指定的服务了。如果你将第一个参数设置为nil，self.manager就会开始寻找所有的服务
     
     该方法第一个参数也是填写指定的搜索外围服务，但是有时候后面的options填空，前面填指令服务又搜索不到（可能与硬件的发广播有关系），具体原因不清楚。一般两个都写一样的。
     
     */
    //    [central scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber numberWithBool:YES],CBCentralManagerScanOptionSolicitedServiceUUIDsKey:@[[CBUUID UUIDWithString:kServiceUUID]]}];
    
    //或者这样写
    [central scanForPeripheralsWithServices:nil options:nil];
    
    
}

#pragma  mark - 回调方法 成功扫描到周边设备
/*
 peripheral：扫描到的周边设备
 advertisementData：响应数据  跟广播包所放的内容有关系
 RSSI即Received Signal Strength Indication：接收的信号强度指示
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
#pragma  mark - 3、连接周边设备
    if (self.myPeripheral != peripheral) {
        self.myPeripheral = peripheral; //保存扫描的周边设备 防止arc释放
        
        //3、连接周边设备
        [self.manager connectPeripheral:peripheral options:nil];
    }
}


#pragma  mark - 回调方法 成功连接周边设备
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    // 停止扫描
    [self.manager stopScan];
    // 清空数据
    [self.data setLength:0];
    
    //设置代理
    peripheral.delegate=self;
    
#pragma  mark - 4、扫描周边设备的服务
    //让周边设备找到服务
    [peripheral discoverServices:@[ [CBUUID UUIDWithString:kServiceUUID]] ];
    //或者这样写 两者没什么区别
    //    [peripheral discoverServices:nil];
    
}
#pragma  mark -  蓝牙断开连接回调方法
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)erro
{
    NSLog(@"蓝牙断开连接");
}

#pragma  mark - 回调方法 接收到连接的周边设备的服务
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        return;
    }
    
    //遍历周边设备的服务 通过代理返回特征
    for (CBService *service in peripheral.services) {
        //发现特征
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

#pragma  mark - 回调方法 获取特征
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        return;
    }
    
    //判断是否是匹配的服务kServiceUUID
    if ([service.UUID isEqual:[CBUUID UUIDWithString: kServiceUUID]]) {
        //遍历特征
        for (CBCharacteristic *characteristic in service.characteristics) {
            
            //找到我们需要的特征
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]]) {
                
                self.myCharacteristic = characteristic; //保存特征
                
                /*
                 当发现传送服务特征后我们要订阅他 来告诉周边设备我们想要这个特征所持有的数据
                 */
#pragma mark - 6、接收数据
                //开启订阅(监听数据)
                CBUUID *sUUID = [CBUUID UUIDWithString:kServiceUUID];
                CBUUID *cUUID = [CBUUID UUIDWithString:kNotificationUUID];
                //第一个参数是设备 第二个是设备服务 第三个是使能通知服务UUID，方便后续发送通知推送UUID 第四个参数是是否使能通知
                [BLEUtility setNotificationForCharacteristic:peripheral sCBUUID:sUUID cCBUUID:cUUID enable:YES];
            }
        }
    }
}
#pragma mark - 写完数据回调
-(void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (error) {
        //    NSLog(@"isMainThread %d",[NSThread isMainThread]);
        NSLog(@"didWriteValueForCharacteristic %@ error = %@",characteristic,error);
    }
    
}

#pragma  mark - 回调方法 接收到通知发来的数据
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    if (error) {
        return;
    }
    
    //    NSData *datav = characteristic.value;
    
    //characteristic.value 是特征中所包含的数据  处理数据
    [self.data appendData:characteristic.value];
    
}

#pragma  mark - 发送数据
-(void)writeChar:(NSData *)data
{
    CBUUID *sUUID = [CBUUID UUIDWithString:kServiceUUID];
    CBUUID *cUUID = [CBUUID UUIDWithString:kCharacteristicUUID];
    //第一个参数是设备 第二个是设备服务 第三个是写入的特征项 第四个参数是写入的数据 以二级制计算
    [BLEUtility writeCharacteristic:self.myPeripheral sCBUUID:sUUID cCBUUID:cUUID data:data];
}

#pragma  mark - 回调方法 —— 订阅状态改变
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        return;
    }
    
    if (characteristic.isNotifying) {
        NSLog(@"开始订阅");
    }
    else{
        //取消订阅的状态发生，断开连接
        NSLog(@"订阅结束");
        
#pragma  mark - 7、断开连接
        //断开连接 会调用断开连接的方法
        [self.manager cancelPeripheralConnection:peripheral];
        
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
