//
//  CMOrientationManager.h
//  CameraM
//
//  设备方向管理模块 - 从CameraManager拆分
//  职责: 监听设备方向变化、转换方向枚举、通知代理
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../Managers/CameraManager.h"

NS_ASSUME_NONNULL_BEGIN

@class CMOrientationManager;

/// 方向变化代理
@protocol CMOrientationManagerDelegate <NSObject>
@optional
/// 设备方向已改变
- (void)orientationManager:(CMOrientationManager *)manager
    didChangeDeviceOrientation:(CameraDeviceOrientation)orientation;
@end

@interface CMOrientationManager : NSObject

/// 代理
@property (nonatomic, weak) id<CMOrientationManagerDelegate> delegate;

/// 当前设备方向
@property (nonatomic, readonly) CameraDeviceOrientation currentDeviceOrientation;

#pragma mark - Lifecycle

/// 开始监听设备方向
- (void)startMonitoring;

/// 停止监听设备方向
- (void)stopMonitoring;

#pragma mark - Orientation Conversion

/// 获取当前视频方向(用于AVFoundation)
- (AVCaptureVideoOrientation)currentVideoOrientation;

/// 从UIDeviceOrientation转换到CameraDeviceOrientation
- (CameraDeviceOrientation)cameraOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation;

@end

NS_ASSUME_NONNULL_END
