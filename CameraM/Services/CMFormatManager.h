//
//  CMFormatManager.h
//  CameraM
//
//  设备格式管理模块 - 从CameraManager拆分
//  职责: 设备格式缓存、4800万像素支持检测、格式切换
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "../Managers/CameraManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMFormatManager : NSObject

#pragma mark - Format Caching

/// 预热指定设备的格式缓存
- (void)primeFormatCachesForDevice:(AVCaptureDevice *)device;

/// 获取标准格式（12MP）
- (AVCaptureDeviceFormat * _Nullable)standardFormatForDevice:(AVCaptureDevice *)device;

/// 获取超高分辨率格式（48MP）
- (AVCaptureDeviceFormat * _Nullable)ultraHighResolutionFormatForDevice:(AVCaptureDevice *)device;

/// 查找超高分辨率格式
- (AVCaptureDeviceFormat * _Nullable)findUltraHighResolutionFormatForDevice:(AVCaptureDevice *)device;

#pragma mark - Format Application

/// 应用格式到设备
- (BOOL)applyFormat:(AVCaptureDeviceFormat *)format toDevice:(AVCaptureDevice *)device;

#pragma mark - Photo Dimensions

/// 获取格式的最大照片尺寸
- (CMVideoDimensions)maxPhotoDimensionsForFormat:(AVCaptureDeviceFormat *)format;

/// 配置照片设置的最大尺寸
- (void)configureMaxPhotoDimensionsForSettings:(AVCapturePhotoSettings *)settings
                                   photoOutput:(AVCapturePhotoOutput *)photoOutput
                                  currentDevice:(AVCaptureDevice *)currentDevice;

#pragma mark - Device Support Check

/// 检查设备是否支持超高分辨率
- (BOOL)deviceSupportsUltraHighResolution:(AVCaptureDevice *)device;

#pragma mark - Cache Management

/// 清除所有格式缓存
- (void)clearAllFormatCaches;

/// 清除指定设备的格式缓存
- (void)clearFormatCachesForDevice:(AVCaptureDevice *)device;

@end

NS_ASSUME_NONNULL_END
