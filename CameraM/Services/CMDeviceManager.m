//
//  CMDeviceManager.m
//  CameraM
//
//  设备管理模块实现
//

#import "CMDeviceManager.h"
#import <float.h>

@interface CMDeviceManager ()

@property (nonatomic, readwrite) NSArray<CMCameraLensOption *> *availableLensOptions;
@property (nonatomic, readwrite, nullable) CMCameraLensOption *currentLensOption;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AVCaptureDevice *> *lensDeviceMap;

@end

@implementation CMDeviceManager

- (instancetype)init {
  self = [super init];
  if (self) {
    _availableLensOptions = @[];
    _lensDeviceMap = [NSMutableDictionary dictionary];
  }
  return self;
}

#pragma mark - Device Discovery

- (NSArray<AVCaptureDevice *> *)discoverDevicesForPosition:(CameraPosition)position {
  AVCaptureDevicePosition avPosition = (position == CameraPositionBack)
                                           ? AVCaptureDevicePositionBack
                                           : AVCaptureDevicePositionFront;
  NSMutableArray<AVCaptureDeviceType> *deviceTypes = [NSMutableArray array];

  if (position == CameraPositionBack) {
    [deviceTypes addObjectsFromArray:@[
      AVCaptureDeviceTypeBuiltInWideAngleCamera,
      AVCaptureDeviceTypeBuiltInUltraWideCamera,
      AVCaptureDeviceTypeBuiltInTelephotoCamera
    ]];
  } else {
    [deviceTypes addObject:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    if (@available(iOS 13.0, *)) {
      [deviceTypes addObject:AVCaptureDeviceTypeBuiltInTrueDepthCamera];
    }
  }

  AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession
      discoverySessionWithDeviceTypes:deviceTypes
                            mediaType:AVMediaTypeVideo
                             position:avPosition];

  // 去重
  NSMutableArray<AVCaptureDevice *> *uniqueDevices = [NSMutableArray array];
  NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];
  for (AVCaptureDevice *device in session.devices) {
    if (![seenIDs containsObject:device.uniqueID]) {
      [uniqueDevices addObject:device];
      [seenIDs addObject:device.uniqueID];
    }
  }

  // 降级处理
  if (uniqueDevices.count == 0) {
    AVCaptureDevice *fallback = [self cameraWithPosition:position];
    if (fallback) {
      [uniqueDevices addObject:fallback];
    }
  }

  NSLog(@"📷 [CMDeviceManager] 发现 %lu 个设备 (位置: %@)",
        (unsigned long)uniqueDevices.count,
        position == CameraPositionBack ? @"后置" : @"前置");

  return [uniqueDevices copy];
}

#pragma mark - Lens Management

- (void)rebuildLensOptionsForPosition:(CameraPosition)position
                              devices:(NSArray<AVCaptureDevice *> *)devices
                         shouldNotify:(BOOL)notify {
  if (devices.count == 0) {
    self.availableLensOptions = @[];
    [self.lensDeviceMap removeAllObjects];
    self.currentLensOption = nil;
    return;
  }

  // 找到参考设备（通常是1x广角）
  AVCaptureDevice *referenceDevice = nil;
  if (position == CameraPositionBack) {
    for (AVCaptureDevice *device in devices) {
      if ([device.deviceType
              isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
        referenceDevice = device;
        break;
      }
    }
  }
  if (!referenceDevice) {
    referenceDevice = devices.firstObject;
  }

  NSMutableArray<CMCameraLensOption *> *options = [NSMutableArray array];
  NSMutableDictionary<NSString *, AVCaptureDevice *> *deviceMap =
      [NSMutableDictionary dictionary];

  for (AVCaptureDevice *device in devices) {
    CGFloat zoom = [self canonicalZoomForDevice:device reference:referenceDevice];
    NSString *title = [self titleForZoomFactor:zoom];
    NSString *identifier =
        [NSString stringWithFormat:@"lens.%@", device.uniqueID];
    CMCameraLensOption *option =
        [CMCameraLensOption optionWithIdentifier:identifier
                                     displayName:title
                                      zoomFactor:zoom
                                  deviceUniqueID:device.uniqueID];
    [options addObject:option];
    if (device.uniqueID) {
      deviceMap[device.uniqueID] = device;
    }
  }

  // 按缩放因子排序
  [options sortUsingComparator:^NSComparisonResult(CMCameraLensOption *obj1,
                                                   CMCameraLensOption *obj2) {
    if (obj1.zoomFactor < obj2.zoomFactor) {
      return NSOrderedAscending;
    }
    if (obj1.zoomFactor > obj2.zoomFactor) {
      return NSOrderedDescending;
    }
    return [obj1.displayName compare:obj2.displayName];
  }];

  self.availableLensOptions = [options copy];
  self.lensDeviceMap = deviceMap;

  // 选择默认镜头
  CMCameraLensOption *selected = nil;
  if (self.currentLensOption) {
    // 尝试保留当前选择
    for (CMCameraLensOption *candidate in self.availableLensOptions) {
      if ([candidate.identifier
              isEqualToString:self.currentLensOption.identifier]) {
        selected = candidate;
        break;
      }
    }
  }

  if (!selected) {
    // 选择最接近1x的镜头
    CGFloat closestDiff = CGFLOAT_MAX;
    for (CMCameraLensOption *candidate in self.availableLensOptions) {
      CGFloat diff = fabs(candidate.zoomFactor - 1.0f);
      if (diff < closestDiff) {
        closestDiff = diff;
        selected = candidate;
      }
    }
  }

  if (!selected) {
    selected = self.availableLensOptions.firstObject;
  }

  self.currentLensOption = selected;

  NSLog(@"🔍 [CMDeviceManager] 重建镜头选项: %lu个, 当前: %@",
        (unsigned long)self.availableLensOptions.count,
        selected.displayName);
}

- (AVCaptureDevice *)deviceForLensOption:(CMCameraLensOption *)lensOption
                                 devices:(NSArray<AVCaptureDevice *> *)devices {
  if (!lensOption) {
    return nil;
  }

  // 先从映射表查找
  if (lensOption.deviceUniqueID.length > 0) {
    AVCaptureDevice *mappedDevice = self.lensDeviceMap[lensOption.deviceUniqueID];
    if (mappedDevice) {
      return mappedDevice;
    }
  }

  // 从设备列表查找
  for (AVCaptureDevice *device in devices) {
    if ([device.uniqueID isEqualToString:lensOption.deviceUniqueID]) {
      return device;
    }
  }

  return devices.firstObject;
}

- (AVCaptureDevice *)deviceByUniqueID:(NSString *)uniqueID {
  if (uniqueID.length == 0) {
    return nil;
  }
  return self.lensDeviceMap[uniqueID];
}

#pragma mark - Lens Selection

- (void)selectLensOption:(CMCameraLensOption *)lensOption {
  if (!lensOption) {
    return;
  }

  // 验证选项在可用列表中
  BOOL found = NO;
  for (CMCameraLensOption *option in self.availableLensOptions) {
    if ([option.identifier isEqualToString:lensOption.identifier]) {
      self.currentLensOption = option;
      found = YES;
      break;
    }
  }

  if (found) {
    NSLog(@"✅ [CMDeviceManager] 选中镜头: %@", lensOption.displayName);
  } else {
    NSLog(@"⚠️ [CMDeviceManager] 镜头选项不在可用列表中: %@", lensOption.identifier);
  }
}

- (NSArray<CMCameraLensOption *> *)lensOptionsSnapshot {
  return [[NSArray alloc] initWithArray:self.availableLensOptions copyItems:YES];
}

- (CMCameraLensOption *)currentLensOptionSnapshot {
  return [self.currentLensOption copy];
}

#pragma mark - Private Helpers

- (AVCaptureDevice *)cameraWithPosition:(CameraPosition)position {
  AVCaptureDevicePosition avPosition = (position == CameraPositionBack)
                                           ? AVCaptureDevicePositionBack
                                           : AVCaptureDevicePositionFront;
  return [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                            mediaType:AVMediaTypeVideo
                                             position:avPosition];
}

- (CGFloat)canonicalZoomForDevice:(AVCaptureDevice *)device
                        reference:(AVCaptureDevice *)referenceDevice {
  if (device.position == AVCaptureDevicePositionFront) {
    return 1.0f;
  }

  CGFloat referenceFOV = referenceDevice.activeFormat.videoFieldOfView;
  CGFloat targetFOV = device.activeFormat.videoFieldOfView;
  CGFloat rawZoom = (referenceFOV > 0.0f && targetFOV > 0.0f)
                        ? (referenceFOV / targetFOV)
                        : 1.0f;

  // 根据设备类型返回标准缩放值
  if ([device.deviceType
          isEqualToString:AVCaptureDeviceTypeBuiltInUltraWideCamera]) {
    return 0.5f;
  }
  if ([device.deviceType
          isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
    return 1.0f;
  }
  if ([device.deviceType
          isEqualToString:AVCaptureDeviceTypeBuiltInTelephotoCamera]) {
    if (rawZoom >= 4.5f) {
      return 5.0f;
    }
    if (rawZoom >= 2.7f) {
      return 3.0f;
    }
    if (rawZoom >= 1.6f) {
      return 2.0f;
    }
    return MAX(1.5f, rawZoom);
  }

  return MAX(0.1f, rawZoom);
}

- (NSString *)titleForZoomFactor:(CGFloat)zoomFactor {
  CGFloat rounded = zoomFactor;

  // 标准化缩放值
  if (zoomFactor < 0.8f) {
    rounded = 0.5f;
  } else if (fabs(zoomFactor - 1.0f) < 0.15f) {
    rounded = 1.0f;
  } else if (fabs(zoomFactor - 2.0f) < 0.4f) {
    rounded = 2.0f;
  } else if (fabs(zoomFactor - 3.0f) < 0.5f) {
    rounded = 3.0f;
  } else if (fabs(zoomFactor - 5.0f) < 0.6f) {
    rounded = 5.0f;
  } else {
    rounded = roundf(zoomFactor * 10.0f) / 10.0f;
  }

  // 格式化显示
  if (fabs(rounded - roundf(rounded)) < 0.05f) {
    return [NSString stringWithFormat:@"%.0fx", roundf(rounded)];
  }
  return [NSString stringWithFormat:@"%.1fx", rounded];
}

@end
