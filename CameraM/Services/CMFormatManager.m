//
//  CMFormatManager.m
//  CameraM
//
//  设备格式管理模块实现
//

#import "CMFormatManager.h"
#import <float.h>

@interface CMFormatManager ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, AVCaptureDeviceFormat *> *standardDeviceFormats;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AVCaptureDeviceFormat *> *ultraHighDeviceFormats;

@end

@implementation CMFormatManager

- (instancetype)init {
  self = [super init];
  if (self) {
    _standardDeviceFormats = [NSMutableDictionary dictionary];
    _ultraHighDeviceFormats = [NSMutableDictionary dictionary];
  }
  return self;
}

#pragma mark - Format Caching

- (void)primeFormatCachesForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return;
  }
  // 预先缓存两种格式
  [self standardFormatForDevice:device];
  [self ultraHighResolutionFormatForDevice:device];
}

- (AVCaptureDeviceFormat *)standardFormatForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return nil;
  }

  NSString *key = [self formatCacheKeyForDevice:device];
  if (key.length == 0) {
    return device.activeFormat;
  }

  AVCaptureDeviceFormat *cached = self.standardDeviceFormats[key];
  if (!cached) {
    AVCaptureDeviceFormat *active = device.activeFormat;
    if (active) {
      self.standardDeviceFormats[key] = active;
      cached = active;
    }
  }

  return cached ?: device.activeFormat;
}

- (AVCaptureDeviceFormat *)ultraHighResolutionFormatForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return nil;
  }

  NSString *key = [self formatCacheKeyForDevice:device];
  if (key.length == 0) {
    return [self findUltraHighResolutionFormatForDevice:device];
  }

  AVCaptureDeviceFormat *cached = self.ultraHighDeviceFormats[key];
  if (!cached) {
    cached = [self findUltraHighResolutionFormatForDevice:device];
    if (cached) {
      self.ultraHighDeviceFormats[key] = cached;
    }
  }

  return cached;
}

- (AVCaptureDeviceFormat *)findUltraHighResolutionFormatForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return nil;
  }

  AVCaptureDeviceFormat *bestFormat = nil;
  int64_t bestPixelCount = 0;
  CGFloat bestAspectPenalty = CGFLOAT_MAX;

  for (AVCaptureDeviceFormat *format in device.formats) {
    CMVideoDimensions stillDimensions = [self maxPhotoDimensionsForFormat:format];
    if (stillDimensions.width <= 0 || stillDimensions.height <= 0) {
      continue;
    }

    int64_t pixelCount =
        (int64_t)stillDimensions.width * (int64_t)stillDimensions.height;
    if (pixelCount < 40000000) { // 约4000万像素以上才考虑，48MP约为8064x6048
      continue;
    }

    CGFloat aspect =
        (CGFloat)stillDimensions.width / (CGFloat)stillDimensions.height;
    CGFloat penalty = fabs(aspect - (4.0f / 3.0f)); // 优先4:3比例

    if (!bestFormat || pixelCount > bestPixelCount ||
        (pixelCount == bestPixelCount && penalty < bestAspectPenalty)) {
      bestFormat = format;
      bestPixelCount = pixelCount;
      bestAspectPenalty = penalty;
    }
  }

  if (bestFormat) {
    NSLog(@"✅ [CMFormatManager] 找到超高分辨率格式: %lldMP",
          bestPixelCount / 1000000);
  }

  return bestFormat;
}

#pragma mark - Format Application

- (BOOL)applyFormat:(AVCaptureDeviceFormat *)format toDevice:(AVCaptureDevice *)device {
  if (!device || !format) {
    return NO;
  }

  if (device.activeFormat == format) {
    return NO; // 格式已经是当前格式
  }

  NSError *configurationError = nil;
  if (![device lockForConfiguration:&configurationError]) {
    NSLog(@"⚠️ [CMFormatManager] 无法锁定设备配置: %@",
          configurationError.localizedDescription);
    return NO;
  }

  // 保存当前缩放
  CGFloat previousZoom = device.videoZoomFactor;
  device.activeFormat = format;

  // 调整缩放到新格式的有效范围
  CGFloat minZoom = device.minAvailableVideoZoomFactor;
  CGFloat maxZoom = device.maxAvailableVideoZoomFactor;
  CGFloat clampedZoom = MIN(MAX(previousZoom, minZoom), maxZoom);
  if (fabs(clampedZoom - previousZoom) > 0.001f) {
    device.videoZoomFactor = clampedZoom;
    NSLog(@"ℹ️ [CMFormatManager] 缩放调整: %.2f -> %.2f", previousZoom, clampedZoom);
  }

  [device unlockForConfiguration];

  NSLog(@"✅ [CMFormatManager] 格式应用成功");
  return YES;
}

#pragma mark - Photo Dimensions

- (CMVideoDimensions)maxPhotoDimensionsForFormat:(AVCaptureDeviceFormat *)format {
  if (!format) {
    return (CMVideoDimensions){0, 0};
  }

  CMVideoDimensions bestDimensions = format.highResolutionStillImageDimensions;

  if (@available(iOS 17.0, *)) {
    for (NSValue *value in format.supportedMaxPhotoDimensions) {
      CMVideoDimensions candidate = {0, 0};
      [value getValue:&candidate];
      int64_t candidatePixels =
          (int64_t)candidate.width * (int64_t)candidate.height;
      int64_t bestPixels =
          (int64_t)bestDimensions.width * (int64_t)bestDimensions.height;
      if (candidatePixels > bestPixels) {
        bestDimensions = candidate;
      }
    }
  }

  // 如果没有高分辨率尺寸，使用格式描述的尺寸
  if (bestDimensions.width <= 0 || bestDimensions.height <= 0) {
    bestDimensions =
        CMVideoFormatDescriptionGetDimensions(format.formatDescription);
  }

  return bestDimensions;
}

- (void)configureMaxPhotoDimensionsForSettings:(AVCapturePhotoSettings *)settings
                                   photoOutput:(AVCapturePhotoOutput *)photoOutput
                                  currentDevice:(AVCaptureDevice *)currentDevice {
  if (!settings) {
    return;
  }

  if (@available(iOS 17.0, *)) {
    CMVideoDimensions targetDimensions = photoOutput.maxPhotoDimensions;

    if ((targetDimensions.width <= 0 || targetDimensions.height <= 0) &&
        currentDevice.activeFormat) {
      targetDimensions =
          [self maxPhotoDimensionsForFormat:currentDevice.activeFormat];
    }

    if (targetDimensions.width > 0 && targetDimensions.height > 0) {
      settings.maxPhotoDimensions = targetDimensions;
      NSLog(@"📐 [CMFormatManager] 配置照片尺寸: %dx%d",
            targetDimensions.width, targetDimensions.height);
    }
  }
}

#pragma mark - Device Support Check

- (BOOL)deviceSupportsUltraHighResolution:(AVCaptureDevice *)device {
  return ([self ultraHighResolutionFormatForDevice:device] != nil);
}

#pragma mark - Cache Management

- (void)clearAllFormatCaches {
  [self.standardDeviceFormats removeAllObjects];
  [self.ultraHighDeviceFormats removeAllObjects];
  NSLog(@"🗑 [CMFormatManager] 清除所有格式缓存");
}

- (void)clearFormatCachesForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return;
  }

  NSString *key = [self formatCacheKeyForDevice:device];
  if (key.length > 0) {
    [self.standardDeviceFormats removeObjectForKey:key];
    [self.ultraHighDeviceFormats removeObjectForKey:key];
    NSLog(@"🗑 [CMFormatManager] 清除设备格式缓存: %@", key);
  }
}

#pragma mark - Private Helpers

- (NSString *)formatCacheKeyForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return nil;
  }

  NSString *uniqueID = device.uniqueID;
  if (uniqueID.length > 0) {
    return uniqueID;
  }

  // 备用方案：使用设备指针
  return [NSString stringWithFormat:@"%p", device];
}

@end
