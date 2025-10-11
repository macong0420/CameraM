//
//  CMDeviceManager.h
//  CameraM
//
//  设备管理模块 - 从CameraManager拆分
//  职责: 设备发现、镜头管理、设备切换
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "../Models/CMCameraLensOption.h"
#import "../Managers/CameraManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMDeviceManager : NSObject

#pragma mark - Properties

/// 当前可用的镜头选项列表
@property (nonatomic, readonly) NSArray<CMCameraLensOption *> *availableLensOptions;

/// 当前选中的镜头选项
@property (nonatomic, readonly, nullable) CMCameraLensOption *currentLensOption;

#pragma mark - Device Discovery

/// 发现指定位置的所有可用设备
- (NSArray<AVCaptureDevice *> *)discoverDevicesForPosition:(CameraPosition)position;

#pragma mark - Lens Management

/// 重建镜头选项列表
- (void)rebuildLensOptionsForPosition:(CameraPosition)position
                              devices:(NSArray<AVCaptureDevice *> *)devices
                         shouldNotify:(BOOL)notify;

/// 根据镜头选项获取对应的设备
- (AVCaptureDevice * _Nullable)deviceForLensOption:(CMCameraLensOption *)lensOption
                                           devices:(NSArray<AVCaptureDevice *> *)devices;

/// 通过设备唯一ID获取设备
- (AVCaptureDevice * _Nullable)deviceByUniqueID:(NSString *)uniqueID;

#pragma mark - Lens Selection

/// 选择指定的镜头选项
- (void)selectLensOption:(CMCameraLensOption *)lensOption;

/// 获取当前镜头快照（用于通知）
- (NSArray<CMCameraLensOption *> *)lensOptionsSnapshot;

/// 获取当前镜头选项快照
- (CMCameraLensOption * _Nullable)currentLensOptionSnapshot;

@end

NS_ASSUME_NONNULL_END
