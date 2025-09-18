//
//  CameraBusinessController.h
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CameraManager.h"

NS_ASSUME_NONNULL_BEGIN

// 业务事件代理协议
@protocol CameraBusinessDelegate <NSObject>

@optional
// 相机状态变化
- (void)didChangeResolutionMode:(CameraResolutionMode)mode;
- (void)didChangeFlashMode:(FlashMode)mode;
- (void)didChangeAspectRatio:(CameraAspectRatio)ratio;
- (void)didCapturePhoto:(UIImage *)image withMetadata:(NSDictionary *)metadata;
- (void)didFailWithError:(NSError *)error;

// UI状态更新
- (void)shouldUpdateCaptureButtonEnabled:(BOOL)enabled;
- (void)shouldShowCaptureFlashEffect;

@end

@interface CameraBusinessController : NSObject

@property (nonatomic, weak) id<CameraBusinessDelegate> delegate;

// 状态查询接口
@property (nonatomic, readonly) CameraResolutionMode currentResolutionMode;
@property (nonatomic, readonly) FlashMode currentFlashMode;
@property (nonatomic, readonly) CameraAspectRatio currentAspectRatio;
@property (nonatomic, readonly) BOOL isUltraHighResolutionSupported;
@property (nonatomic, readonly) UIImage * _Nullable latestCapturedImage;

// 内部组件访问（仅用于协调）
@property (nonatomic, readonly) CameraManager *cameraManager;

// 相机控制接口
- (void)setupCameraWithPreviewView:(UIView *)previewView completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
- (void)startSession;
- (void)stopSession;
- (void)cleanup;

// 拍摄控制
- (void)capturePhoto;
- (void)switchCamera;
- (void)switchResolutionMode;
- (void)switchFlashMode;
- (void)switchAspectRatio:(CameraAspectRatio)ratio;

// 对焦和曝光
- (void)focusAtPoint:(CGPoint)screenPoint withPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;
- (void)setExposureCompensation:(float)value;

// 网格线状态管理
- (void)toggleGridLines;
- (BOOL)isGridLinesVisible;

// 比例相关工具方法
- (CGRect)previewRectForCurrentAspectRatioInViewSize:(CGSize)viewSize;

@end

NS_ASSUME_NONNULL_END
