#import "FlutterBluetoothPrinterPlugin.h"
#import "ConnecterManager.h"
#import "BlueToothManager.h"
@interface FlutterBluetoothPrinterPlugin (){
    BlueToothManager * _manager;
}
@property(nonatomic, retain) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, retain) FlutterMethodChannel *channel;
@property(nonatomic) NSMutableDictionary *scannedPeripherals;
@property(nonatomic) CBPeripheral *connectedDevice;
@property(nonatomic) bool isAvailable;
@property(nonatomic) bool isInitialized;

@property (nonatomic,strong) FlutterResult _result;

@property (nonatomic, strong) NSMutableArray *accumulatedDataArray; // 累积数据的数组
@property (nonatomic, strong) NSTimer *timeoutTimer;               // 定时器
@property (nonatomic, assign) BOOL isResultCalled;                 // 标记是否已调用result

@end

@implementation FlutterBluetoothPrinterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"id.flutter.plugins/bluetooth_printer"
            binaryMessenger:[registrar messenger]];
    
  FlutterBluetoothPrinterPlugin* instance = [[FlutterBluetoothPrinterPlugin alloc] init];
  instance.channel = channel;
  instance.scannedPeripherals = [NSMutableDictionary new];
    
    
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init
{
    self = [super init];

    
    return self;
}

- (void) initialize:(void(^)(bool))callback {
    if ([self isInitialized]){
        callback(self.isAvailable);
        return;
    }
    
    self.isAvailable = false;
    [Manager didUpdateState:^(NSInteger state) {
        switch (state) {
            case CBManagerStateUnsupported:
                NSLog(@"The platform/hardware doesn't support Bluetooth Low Energy.");
                callback(false);
                break;
            case CBManagerStateUnauthorized:
                NSLog(@"The app is not authorized to use Bluetooth Low Energy.");
                callback(false);
                break;
            case CBManagerStatePoweredOff:
                NSLog(@"Bluetooth is currently powered off.");
                callback(false);
                break;
            case CBManagerStatePoweredOn:
                self->_isAvailable = true;
                NSLog(@"Bluetooth power on");
                callback(true);
                break;
            case CBManagerStateUnknown:
            default:
                callback(false);
                break;
        }
    }];
}


// 辅助方法：将 NSData 转换为十六进制字符串
- (NSString *)hexStringWithData:(NSData *)data {
    NSMutableString *hexString = [NSMutableString stringWithCapacity:data.length * 2];
    const unsigned char *bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        [hexString appendFormat:@"%02x", bytes[i]];
    }
    return hexString;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
  if ([@"startScan" isEqualToString:call.method]) {
      _manager = [BlueToothManager getInstance];
      [self.scannedPeripherals removeAllObjects];
//      [self initialize:^(bool isAvailable) {
//          if (isAvailable){
//              [self startScan];
//              result(@(YES));
//          } else {
//              result(@(NO));
//          }
//      }];
      [_manager getBlueListArray:^(NSMutableArray *blueToothArray) {
          for (CBPeripheral* peripheral in blueToothArray) {
              NSDictionary *device = [self deviceToMap:blueToothArray.lastObject];
              [self.scannedPeripherals setObject:peripheral forKey:device[@"address"]];
              [self->_channel invokeMethod:@"onDiscovered" arguments:device];
          }
//          self.scannedPeripherals = [blueToothArray mutableCopy];
//          NSDictionary *device = [self deviceToMap:blueToothArray.lastObject];
      }];
      [_manager startScan];
      result(@(YES));
  } else if ([@"isConnected" isEqualToString:call.method]){
      bool res = [self connectedDevice] != nil;
      result(@(res));
  } else if ([@"connectedDevice" isEqualToString:call.method]){
      if (_connectedDevice != nil){
          NSDictionary *map = [self deviceToMap:_connectedDevice];
          result(map);
          return;
      }
      
      result(nil);
  } else if ([@"stopScan" isEqualToString:call.method]){
      [_manager stopScan];
      result(@(YES));
  } else if ([@"isEnabled" isEqualToString:call.method]){
      [self initialize:^(bool isAvailable) {
          result(@(isAvailable));
      }];
  } else if ([@"print" isEqualToString:call.method]){
      @try {
          self._result = result;
          FlutterStandardTypedData *arg = [call arguments];
          NSData *data = [arg data];
          
          [_manager sendDataWithString:nil andInfoData:data response:^(NSData *responseData) {
              NSLog(@"Bluetooth manager response data: %@", responseData);
                 
                 // 1. Parse data to array
                 uint8_t *bytePtr = (uint8_t *)[responseData bytes];
                 NSInteger totalData = [responseData length] / sizeof(uint8_t);
                 NSMutableArray *dataArray = [NSMutableArray array];
                 for (int i = 0; i < totalData; i++) {
                     NSInteger byteInteger = [[NSString stringWithFormat:@"%d", bytePtr[i]] integerValue];
                     [dataArray addObject:@(byteInteger)];
                 }
                 
                 // 2. Check if data starts with the reset sequence [2, 116, 114, 101, 110, 100, 105, 116, 1]
                 NSArray *resetSequence = @[@2, @116, @114, @101, @110, @100, @105, @116, @1];
                 BOOL isResetSequence = NO;
                 if (dataArray.count >= resetSequence.count) {
                     isResetSequence = YES;
                     for (NSUInteger i = 0; i < resetSequence.count; i++) {
                         if (![dataArray[i] isEqual:resetSequence[i]]) {
                             isResetSequence = NO;
                             break;
                         }
                     }
                 }
                 
                 // 3. Initialize accumulatedDataArray if nil
                 if (!self.accumulatedDataArray) {
                     self.accumulatedDataArray = [NSMutableArray array];
                 }
                 
                 // 4. Clear accumulatedDataArray if reset sequence is detected
                 if (isResetSequence) {
                     [self.accumulatedDataArray removeAllObjects];
                     NSLog(@"Reset sequence detected, cleared accumulatedDataArray");
                 }
                 
                 // 5. Append new data to accumulatedDataArray
                 [self.accumulatedDataArray addObjectsFromArray:dataArray];
                 NSLog(@"当前累积数据量: %ld", self.accumulatedDataArray.count);
                 
                 // 6. Reset timer (restart 10-second countdown on new data)
                 [self resetTimer];
          }];

     } @catch(FlutterError *e) {
         result(e);
     }
  } else if ([@"connect" isEqualToString:call.method]){
      NSDictionary *device = [call arguments];
      @try {
        CBPeripheral *peripheral = [_scannedPeripherals objectForKey:[device objectForKey:@"address"]];
        _connectedDevice=peripheral;
        [_manager stopScan];
        __weak typeof(self) weakSelf = self;
        self.state = ^(ConnectState state) {
            switch (state) {
                case CONNECT_STATE_CONNECTED:
                    weakSelf.connectedDevice = peripheral;
                    result(@(YES));
                    break;
                    
                case CONNECT_STATE_DISCONNECT:
                    weakSelf.connectedDevice = nil;
                    break;
                    
                case CONNECT_STATE_FAILT:
                case CONNECT_STATE_TIMEOUT:
                    result(@(NO));
                    break;
                    
                default:
                    break;
            }
            [weakSelf updateConnectState:state];
           };
//        _prez
//        [Manager connectPeripheral:peripheral options:nil timeout:2 connectBlack: self.state];
          [_manager connectPeripheralWith:peripheral  connectBlack:self.state];
      } @catch(FlutterError *e) {
        result(e);
      }
  } else if ([@"getDevice" isEqualToString:call.method]){
      NSDictionary *device = [call arguments];
      @try {
        CBPeripheral *peripheral = [_scannedPeripherals objectForKey:[device objectForKey:@"address"]];
        if (peripheral != nil){
            NSDictionary *map = [self deviceToMap:peripheral];
            result(map);
        }
      } @catch(FlutterError *e) {
        result(nil);
      }
  } else if ([@"disconnect" isEqualToString:call.method]){
      @try {
        if (_connectedDevice != nil){
            [_manager cancelPeripheralWith:_connectedDevice];
            _connectedDevice = nil;
        }
          
        result(@(YES));
      } @catch(FlutterError *e) {
        result(e);
      }
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void) startScan {
 
    [Manager scanForPeripheralsWithServices:nil options:nil discover:^(CBPeripheral * _Nullable peripheral, NSDictionary<NSString *,id> * _Nullable advertisementData, NSNumber * _Nullable RSSI) {
        if (peripheral.name != nil) {
            [self.scannedPeripherals setObject:peripheral forKey:[[peripheral identifier] UUIDString]];
            
            NSDictionary *device = [self deviceToMap:peripheral];
            [self->_channel invokeMethod:@"onDiscovered" arguments:device];
        }
    }];
}

- (NSDictionary*) deviceToMap:(CBPeripheral*)peripheral {
    bool isConnected = false;
    if (_connectedDevice != nil){
        isConnected = _connectedDevice.identifier.UUIDString == peripheral.identifier.UUIDString;
    }
    
    NSDictionary *device = [NSDictionary dictionaryWithObjectsAndKeys:peripheral.identifier.UUIDString,@"address",peripheral.name,@"name",@1,@"type", @(isConnected), @"is_connected",nil];
    return device;
}

-(void)updateConnectState:(ConnectState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNumber *ret;
        
        switch (state) {
            case CONNECT_STATE_CONNECTING:
                NSLog(@"status -> %@", @"Connecting ...");
                ret = @0;
                break;
            case CONNECT_STATE_CONNECTED:
                NSLog(@"status -> %@", @"Connection success");
                ret = @1;
                break;
            case CONNECT_STATE_FAILT:
                NSLog(@"status -> %@", @"Connection failed");
                ret = @2;
                break;
            case CONNECT_STATE_DISCONNECT:
                NSLog(@"status -> %@", @"Disconnected");
                ret = @3;
                break;
            default:
                NSLog(@"status -> %@", @"Connection timed out");
                ret = @4;
                break;
        }
        
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:ret,@"id",nil];
        [self->_channel invokeMethod:@"onStateChanged" arguments:dict];
    });
}


// 重置定时器
- (void)resetTimer {
    // 取消之前的定时器
    if (self.timeoutTimer) {
        [self.timeoutTimer invalidate];
        self.timeoutTimer = nil;
    }
    
    // 4. 创建新的定时器（10秒后触发）
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                         target:self
                                                       selector:@selector(handleTimeout)
                                                       userInfo:nil
                                                        repeats:NO];
}

// 定时器触发时的处理
- (void)handleTimeout {
    NSLog(@"handleTimeout 10秒内无新数据，最终数据量: %ld", self.accumulatedDataArray.count);
    // 确保只调用一次result
    if (!self.isResultCalled) {
        self.isResultCalled = YES;
        NSLog(@"10秒内无新数据，最终数据量: %ld", self.accumulatedDataArray.count);
        
        // 调用result并传递累积的数据
        if (self.accumulatedDataArray) {
            self._result(self.accumulatedDataArray);
        } else {
            self._result(@[]); // 返回空数组表示无数据
        }
        
        // 清理资源
        self.accumulatedDataArray = nil;
        [self.timeoutTimer invalidate];
        self.timeoutTimer = nil;
        self.isResultCalled = NO;
    }
}

@end
