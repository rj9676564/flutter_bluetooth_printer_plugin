//
//  BlueToothManager.h
//  BluetoothPrint
//
//  Created by Tgs on 16/3/7.
//  Copyright © 2016年 Tgs. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "ConnecterBlock.h"
@interface BlueToothManager : NSObject<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    CBCentralManager * _manager;
    CBPeripheral * _per;
    CBCharacteristic * _char;
    CBCharacteristic * _readChar;
    
    NSMutableArray * _peripheralList;
    NSData * _responseData;
    void (^connectBlack)(ConnectState state);
//connectBlack:(void(^_Nullable)(ConnectState state)) connectState
    void (^printSuccess)(BOOL sizeValue);
    void (^responseBlock)(NSData *returnData);
    void (^bluetoothListArr)(NSMutableArray *blueToothArray);
    BOOL valuePrint;
}

/**
 *  创建BlueToothManager单例
 *
 *  @return BlueToothManager单例
 */
+(instancetype)getInstance;

/**
 *  开始扫描
 */
- (void)startScan;

/**
 *  停止扫描
 */
-(void)stopScan;

/**
 *  获得设备列表
 *
 *  @return 设备列表
 */
-(NSMutableArray *)getNameList;

/**
 *  连接设备
 *
 *  @param per 选择的设备
 */
-(void)connectPeripheralWith:(CBPeripheral *)per connectBlack:(void(^_Nullable)(ConnectState state)) connectState;

/**
 *  打开通知
 */
-(void)openNotify;

/**
 *  关闭停止
 */
-(void)cancelNotify;

/**
 *  发送信息给蓝牙
 *
 *  @param str 遵循通信协议的设定
 */
- (void)sendDataWithString:(NSString *)str andInfoData:(NSData *)infoData response:(void(^)(NSData* responseData))printBlock;

/**
 *  展示蓝牙返回的结果
 */
-(void)showResult;

/**
 *  断开连接
 *
 *  @param per 连接的per
 */
-(void)cancelPeripheralWith:(CBPeripheral *)per ;

/*
 * 打印字典信息
 @param stateStr:typeNum 1-本地商品打印，本地服务--0 ，易商城--2
 **/
-(void)getBluetoothPrintWith:(NSDictionary *)dictionary andPrintType:(NSInteger)typeNum;
-(void)getPrintSuccessReturn:(void(^)(BOOL sizeValue))printBlock;
-(void)getBlueListArray:(void (^)(NSMutableArray *blueToothArray))listBlock;
@end
