//
//  CameraManager.h
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CameraManager;

// 相机状态枚举
typedef NS_ENUM(NSInteger, CameraState) {
    CameraStateIdle,
    CameraStateSetup,
    CameraStateRunning,
    CameraStateCapturing,
    CameraStateStopped,
    CameraStateError
};

// 相机类型枚举
typedef NS_ENUM(NSInteger, CameraPosition) {
    CameraPositionBack,
    CameraPositionFront
};

// 闪光灯模式
typedef NS_ENUM(NSInteger, FlashMode) {
    FlashModeAuto,
    FlashModeOn,
    FlashModeOff
};

// 设备方向枚举
typedef NS_ENUM(NSInteger, CameraDeviceOrientation) {
    CameraDeviceOrientationPortrait,           // 竖屏
    CameraDeviceOrientationLandscapeLeft,      // 向左横屏
    CameraDeviceOrientationLandscapeRight      // 向右横屏
};

// 拍照比例枚举
typedef NS_ENUM(NSInteger, CameraAspectRatio) {
    CameraAspectRatio4to3,    // 4:3 传统相机比例
    CameraAspectRatio1to1,    // 1:1 正方形
    CameraAspectRatioXpan     // 65:24 超宽比例
};

// 4800万像素模式
typedef NS_ENUM(NSInteger, CameraResolutionMode) {
    CameraResolutionModeStandard,    // 标准分辨率
    CameraResolutionModeUltraHigh    // 4800万像素
};

// 代理协议 - 高内聚设计
@protocol CameraManagerDelegate <NSObject>

@optional
- (void)cameraManager:(CameraManager *)manager didChangeState:(CameraState)state;
- (void)cameraManager:(CameraManager *)manager didCapturePhoto:(UIImage *)image withMetadata:(NSDictionary *)metadata;
- (void)cameraManager:(CameraManager *)manager didFailWithError:(NSError *)error;
- (void)cameraManager:(CameraManager *)manager didChangeResolutionMode:(CameraResolutionMode)mode;
- (void)cameraManager:(CameraManager *)manager didChangeFlashMode:(FlashMode)mode;
- (void)cameraManager:(CameraManager *)manager didChangeAspectRatio:(CameraAspectRatio)ratio;
- (void)cameraManager:(CameraManager *)manager didChangeDeviceOrientation:(CameraDeviceOrientation)orientation;

@end

@interface CameraManager : NSObject

// 单例模式 - 内存优化
+ (instancetype)sharedManager;
- (instancetype)init NS_UNAVAILABLE;

// 代理
@property (nonatomic, weak) id<CameraManagerDelegate> delegate;

// 状态属性 - 只读，封装性
@property (nonatomic, readonly) CameraState currentState;
@property (nonatomic, readonly) CameraPosition currentPosition;
@property (nonatomic, readonly) CameraResolutionMode currentResolutionMode;
@property (nonatomic, readonly) FlashMode currentFlashMode;
@property (nonatomic, readonly) CameraAspectRatio currentAspectRatio;
@property (nonatomic, readonly) CameraDeviceOrientation currentDeviceOrientation;
@property (nonatomic, readonly) BOOL isUltraHighResolutionSupported;

// 预览层 - 弱引用，避免循环引用
@property (nonatomic, readonly, strong) AVCaptureVideoPreviewLayer *previewLayer;

// 核心方法 - 职责单一
- (void)setupCameraWithPreviewView:(UIView *)previewView completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
- (void)startSession;
- (void)stopSession;
- (void)capturePhoto;
- (void)switchCamera;
- (void)switchResolutionMode:(CameraResolutionMode)mode;
- (void)switchFlashMode:(FlashMode)mode;
- (void)switchAspectRatio:(CameraAspectRatio)ratio;
- (void)focusAtPoint:(CGPoint)point;
- (void)setExposureCompensation:(float)value;

// 设备方向相关
- (void)startDeviceOrientationMonitoring;
- (void)stopDeviceOrientationMonitoring;
- (void)updateDeviceOrientation:(UIDeviceOrientation)deviceOrientation;

// 比例相关工具方法
- (CGRect)cropRectForAspectRatio:(CameraAspectRatio)ratio inImageSize:(CGSize)imageSize;
- (UIImage *)cropImage:(UIImage *)image toAspectRatio:(CameraAspectRatio)ratio;
- (CGRect)previewRectForAspectRatio:(CameraAspectRatio)ratio inViewSize:(CGSize)viewSize;

// 内存管理
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END