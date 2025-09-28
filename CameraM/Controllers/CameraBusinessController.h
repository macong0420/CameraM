/*
 * @Author: 马聪聪 macong0420@126.com
 * @Date: 2025-09-24 16:24:09
 * @LastEditors: 马聪聪 macong0420@126.com
 * @LastEditTime: 2025-09-26 17:02:31
 * @FilePath: /CameraM/CameraM/Controllers/CameraBusinessController.h
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
//
//  CameraBusinessController.h
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../Managers/CameraManager.h"
#import "../Models/CMWatermarkConfiguration.h"
#import "../Models/CMCameraLensOption.h"

NS_ASSUME_NONNULL_BEGIN

// 业务事件代理协议
@protocol CameraBusinessDelegate <NSObject>

@optional
// 相机状态变化
- (void)didChangeResolutionMode:(CameraResolutionMode)mode;
- (void)didChangeFlashMode:(FlashMode)mode;
- (void)didChangeAspectRatio:(CameraAspectRatio)ratio;
- (void)didChangeDeviceOrientation:(CameraDeviceOrientation)orientation;
- (void)didUpdateAvailableLensOptions:(NSArray<CMCameraLensOption *> *)lensOptions currentLens:(CMCameraLensOption *)currentLens;
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
@property (nonatomic, readonly) CameraDeviceOrientation currentDeviceOrientation;
@property (nonatomic, readonly) BOOL isUltraHighResolutionSupported;
@property (nonatomic, readonly) UIImage * _Nullable latestCapturedImage;
@property (nonatomic, readonly) CMWatermarkConfiguration *watermarkConfiguration;
@property (nonatomic, readonly) NSArray<CMCameraLensOption *> *availableLensOptions;
@property (nonatomic, readonly) CMCameraLensOption *currentLensOption;

// 内部组件访问（仅用于协调）
@property (nonatomic, readonly) CameraManager *cameraManager;

// 相机控制接口
- (void)setupCameraWithPreviewView:(UIView *)previewView completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
- (void)startSession;
- (void)stopSession;
- (void)cleanup;

// 方向监听控制
- (void)startOrientationMonitoring;
- (void)stopOrientationMonitoring;

// 拍摄控制
- (void)capturePhoto;
- (void)switchCamera;
- (void)switchResolutionMode;
- (void)switchFlashMode;
- (void)switchAspectRatio:(CameraAspectRatio)ratio;
- (void)switchToLensOption:(CMCameraLensOption *)lensOption;

// 对焦和曝光
- (void)focusAtPoint:(CGPoint)screenPoint withPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;
- (void)setExposureCompensation:(float)value;

// 网格线状态管理
- (void)toggleGridLines;
- (BOOL)isGridLinesVisible;

// 比例相关工具方法
- (CGRect)previewRectForCurrentAspectRatioInViewSize:(CGSize)viewSize;
- (CGRect)activePreviewRectInViewSize:(CGSize)viewSize;

// 水印
- (void)updateWatermarkConfiguration:(CMWatermarkConfiguration *)configuration;

// 外部图片处理
- (void)processImportedImage:(UIImage *)image
          withConfiguration:(nullable CMWatermarkConfiguration *)configuration
                  completion:(void (^)(UIImage * _Nullable processedImage, NSError * _Nullable error))completion;
- (void)processImportedImage:(UIImage *)image
                     metadata:(nullable NSDictionary *)metadata
            withConfiguration:(nullable CMWatermarkConfiguration *)configuration
                    completion:(void (^)(UIImage *_Nullable processedImage,
                                         NSError *_Nullable error))completion;
- (void)processImportedImage:(UIImage *)image
                  completion:(void (^)(UIImage * _Nullable processedImage, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
