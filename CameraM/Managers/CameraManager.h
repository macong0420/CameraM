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
@property (nonatomic, readonly) BOOL isUltraHighResolutionSupported;

// 预览层 - 弱引用，避免循环引用
@property (nonatomic, readonly, weak) AVCaptureVideoPreviewLayer *previewLayer;

// 核心方法 - 职责单一
- (void)setupCameraWithPreviewView:(UIView *)previewView completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
- (void)startSession;
- (void)stopSession;
- (void)capturePhoto;
- (void)switchCamera;
- (void)switchResolutionMode:(CameraResolutionMode)mode;

// 内存管理
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END