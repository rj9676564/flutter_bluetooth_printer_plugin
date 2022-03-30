//
//  BlueToothManager.m
//  BluetoothPrint
//
//  Created by Tgs on 16/3/7.
//  Copyright © 2016年 Tgs. All rights reserved.
//

#import "BlueToothManager.h"

@implementation BlueToothManager

//创建单例类
+(instancetype)getInstance
{
    static BlueToothManager * manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[BlueToothManager alloc]init];
    });
    return manager;
    
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _manager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
    }
    return self;
}

//开始扫描
- (void)startScan
{
    //    [LCProgressHUD showLoadingText:@"正在扫描"];
//    _manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionRestoreIdentifierKey:@"myCentralManagerIdentifier" }];
//    _manager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
    _peripheralList = [[NSMutableArray alloc]initWithCapacity:0];
    [_manager scanForPeripheralsWithServices:nil options:nil];
    
}

//停止扫描
-(void)stopScan
{
    [_manager stopScan];
    
}

//检查蓝牙信息
-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        NSLog(@"蓝牙打开，开始扫描");
        [central scanForPeripheralsWithServices:nil options:nil];
//        central.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
        NSString *uuidstring = [[NSUserDefaults standardUserDefaults] valueForKey:@"UUID"];
        if(uuidstring==nil){
            [central scanForPeripheralsWithServices:nil options:nil];
        }else{
            NSUUID *storagePeripheralUUID = [[NSUUID alloc] initWithUUIDString:uuidstring];
            [central scanForPeripheralsWithServices:@[storagePeripheralUUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
        }
        
    }
    else
    {
        NSLog(@"蓝牙不可用");
    }
}

//扫描到的设备
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"%@===%@===%@",peripheral.name,RSSI,peripheral.identifier.UUIDString );
//    36E298FB-527C-0E50-6952-368DEBBE60EE
    [_peripheralList addObject:peripheral];
    NSString *uuidstring = [[NSUserDefaults standardUserDefaults] valueForKey:@"UUID"];
    if([peripheral.identifier.UUIDString isEqualToString:uuidstring]){
        NSLog(@"相同设备，直接连接");
    
        [self connectPeripheralWith:peripheral connectBlack:nil];
    }
    if (bluetoothListArr) {
        bluetoothListArr(_peripheralList);
    }
}
-(void)getBlueListArray:(void (^)(NSMutableArray *blueToothArray))listBlock{
    bluetoothListArr = [listBlock copy];
}
//获取扫描到设备的列表
-(NSMutableArray *)getNameList
{
    
    return _peripheralList;
    
}

//连接设备
-(void)connectPeripheralWith:(CBPeripheral *)per connectBlack:(void(^_Nullable)(ConnectState state)) connectState{
    if (per!=nil) {
        valuePrint = NO;
        _per = nil;
        _char = nil;
        _readChar = nil;
        connectBlack =  [connectState copy];
        per.delegate=self;
        [_manager connectPeripheral:per options:nil];
    }
}

//连接设备失败
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (connectBlack) {
        connectBlack(CONNECT_STATE_FAILT);
    }
    //    NSLog(@">>>连接到名称为（%@）的设备-失败,原因:%@",[peripheral name],[error localizedDescription]);
}

//设备断开连接
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (connectBlack) {
        connectBlack(CONNECT_STATE_DISCONNECT);
    }
    //    NSLog(@">>>外设连接断开连接 %@: %@\n", [peripheral name], [error localizedDescription]);
}

//连接设备成功
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    _per = peripheral;
    _per.delegate = self;
    if (connectBlack!=nil) {
        connectBlack(CONNECT_STATE_CONNECTED);
    }
    [peripheral discoverServices:@[[CBUUID UUIDWithString:@"49535343-fe7d-4ae5-8fa9-9fafd205e455"]]];
//    [peripheral discoverServices:nil];
    
}

//扫描设备的服务
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        //        NSLog(@"扫描%@的服务发生的错误是：%@",peripheral.name,[error localizedDescription]);
        
    }
    else
    {
        for (CBService *service in peripheral.services) {
//            NSLog(@"%@",ser);
//            [peripheral discoverCharacteristics:nil forService:service];
            if ([service.UUID isEqual:[CBUUID UUIDWithString:@"49535343-fe7d-4ae5-8fa9-9fafd205e455"]]) {
                //查找特征
                [_per discoverCharacteristics:nil forService:service];
            }
        }
        if (connectBlack!=nil) {
            connectBlack(CONNECT_STATE_CONNECTED);
        }
    }
}



//扫描服务的特征值
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    
    if (error)
    {
        //        NSLog(@"扫描服务：------->%@的特征值的错误是：%@",service.UUID,[error localizedDescription]);
    }
    else
    {
        for (CBCharacteristic * cha in service.characteristics)
        {
            if ([cha.UUID isEqual:[CBUUID UUIDWithString:@"49535343-8841-43f4-a8d4-ecbe34729bb3"]]) {
                _char = cha;
            }
            
            // 通知
            if ([cha.UUID isEqual:[CBUUID UUIDWithString:@"49535343-1e4d-4bd9-ba61-23c647249616"]]) {
                _readChar = cha;
                [_per setNotifyValue:YES forCharacteristic:cha];
            }
        }
    }
    [self sendDataWithString:nil andInfoData:[@"\n\n\n\n\n\n\n\n" dataUsingEncoding:NSUTF8StringEncoding] response:^(NSData *responseData) {
        NSLog(@"bluetooth manager %@",responseData);
    }];
//    [self sendDataWithString:nil data:["success"]];
}

//获取特征值的信息
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSData *value = characteristic.value;
    NSLog(@"蓝牙回复：%@",value);
    
    if (error)
    {
        //        NSLog(@"获取特征值%@的错误为%@",characteristic.UUID,error);
        
    }
    else
    {
        //        NSLog(@"------->特征值：%@  value：%@",characteristic.UUID,characteristic.value);
        _responseData = characteristic.value;
        responseBlock(_responseData);
    }
}

//扫描特征值的描述
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        //        NSLog(@"搜索到%@的Descriptors的错误是：%@",characteristic.UUID,error);
        
    }
    else
    {
        //        NSLog(@",,,,,,,,,,,characteristic uuid:%@",characteristic.UUID);
        //
        //        for (CBDescriptor * d in characteristic.descriptors)
        //        {
        //            NSLog(@"------->Descriptor uuid:%@",d.UUID);
        //
        //        }
    }
}

//获取描述值的信息
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    //    if (error)
    //    {
    //        NSLog(@"获取%@的描述的错误是：%@",peripheral.name,error);
    //    }
    //    else
    //    {
    //        NSLog(@"characteristic uuid:%@  value:%@",[NSString stringWithFormat:@"%@",descriptor.UUID],descriptor.value);
    //
    //    }
}

//像蓝牙发送信息
- (void)sendDataWithString:(NSString *)str andInfoData:(NSData *)infoData response:(void(^)(NSData* responseData))printBlock
{
    responseBlock =  [printBlock copy];
    [self openNotify];
     if (_per==nil||_char==nil) {
        valuePrint = NO;
//        if (conReturnBlock) {
//            conReturnBlock(nil ,nil,@"BLUEDISS");
//            return;
//        }
    }else{
        valuePrint = YES;
        if (str==nil||str.length==0) {
            if (_per && _char)
            {
                switch (_char.properties & 0x04) {
                    case CBCharacteristicPropertyWriteWithoutResponse:
                    {
                        //                       CBCharacteristicWriteWithResponse
                        [_per writeValue:infoData forCharacteristic:_char type:CBCharacteristicWriteWithoutResponse];
                        break;
                        
                    }
                    default:
                    {
                        [_per writeValue:infoData forCharacteristic:_char type:CBCharacteristicWriteWithResponse];
                        break;
                    }
                }
                
            }
            
        }else{
            NSData * data = [str dataUsingEncoding:NSUTF8StringEncoding];
            if (_per && _char)
            {
                switch (_char.properties & 0x04) {
                    case CBCharacteristicPropertyWriteWithoutResponse:
                    {
                        [_per writeValue:data forCharacteristic:_char type:CBCharacteristicWriteWithoutResponse];
                        break;
                    }
                    default:
                    {
                        [_per writeValue:data forCharacteristic:_char type:CBCharacteristicWriteWithoutResponse];
                        break;
                    }
                }
                
            }
        }
        
    }
    
}
-(void)getPrintSuccessReturn:(void(^)(BOOL sizeValue))printBlock{
    printSuccess = [printBlock copy];
}
//展示蓝牙返回的信息
-(void)showResult
{
    if (printSuccess&&valuePrint==YES) {
        printSuccess(YES);
    }
}


//隐藏HUD
- (void)hideHUD {
    
    //    [LCProgressHUD hide];
}

//打开通知
-(void)openNotify
{
    if (_readChar!=nil&&_per!=nil) {
        [_per setNotifyValue:YES forCharacteristic:_readChar];
    }
}

//关闭通知
-(void)cancelNotify
{
    [_per setNotifyValue:NO forCharacteristic:_readChar];
    
}

//断开连接
-(void)cancelPeripheralWith:(CBPeripheral *)per
{
    [_manager cancelPeripheralConnection:_per];
    
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
        // 读取数据
    [_per readValueForCharacteristic:characteristic];
}

@end
