//
//  CMMetadataEnricher.h
//  CameraM
//
//  元数据增强模块 - 从CameraManager拆分
//  职责: GPS信息写入、镜头EXIF元数据填充
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import "../Models/CMCameraLensOption.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMMetadataEnricher : NSObject

#pragma mark - Metadata Enrichment

/// 增强照片元数据(添加GPS和镜头信息)
/// @param photo AVCapturePhoto对象
/// @param metadata 原始元数据
/// @param location 当前位置(可为nil)
/// @param device 当前摄像头设备
/// @param lensOption 当前镜头选项
- (NSDictionary *)enrichMetadataFromPhoto:(AVCapturePhoto *)photo
                         originalMetadata:(NSDictionary *)metadata
                                 location:(CLLocation * _Nullable)location
                                   device:(AVCaptureDevice *)device
                               lensOption:(CMCameraLensOption * _Nullable)lensOption;

#pragma mark - Lens Metadata

/// 填充镜头EXIF元数据
/// @param exif 可变EXIF字典
/// @param device 摄像头设备
/// @param lensOption 镜头选项
- (void)populateLensMetadataInExif:(NSMutableDictionary *)exif
                            device:(AVCaptureDevice *)device
                        lensOption:(CMCameraLensOption * _Nullable)lensOption;

#pragma mark - GPS Metadata

/// 从位置生成GPS字典
/// @param location 位置对象
- (NSDictionary * _Nullable)gpsDictionaryForLocation:(CLLocation *)location;

/// 验证位置是否有效
/// @param location 位置对象
- (BOOL)isValidLocation:(CLLocation * _Nullable)location;

#pragma mark - Helpers

/// 计算设备的基准焦距(35mm等效)
/// @param device 摄像头设备
- (CGFloat)baselineFocalLengthForDevice:(AVCaptureDevice *)device;

@end

NS_ASSUME_NONNULL_END
