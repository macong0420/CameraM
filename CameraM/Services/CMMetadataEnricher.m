//
//  CMMetadataEnricher.m
//  CameraM
//
//  元数据增强模块实现
//

#import "CMMetadataEnricher.h"
#import <ImageIO/ImageIO.h>

@implementation CMMetadataEnricher

#pragma mark - Metadata Enrichment

- (NSDictionary *)enrichMetadataFromPhoto:(AVCapturePhoto *)photo
                         originalMetadata:(NSDictionary *)metadata
                                 location:(CLLocation *)location
                                   device:(AVCaptureDevice *)device
                               lensOption:(CMCameraLensOption *)lensOption {
  NSMutableDictionary *mutableMetadata =
      metadata ? [metadata mutableCopy] : [NSMutableDictionary dictionary];
  if (!mutableMetadata) {
    mutableMetadata = [NSMutableDictionary dictionary];
  }

  // 获取照片位置信息
  CLLocation *photoLocation = location;

  // 如果提供了位置且有效，添加GPS信息
  if ([self isValidLocation:photoLocation]) {
    NSDictionary *gps = [self gpsDictionaryForLocation:photoLocation];
    if (gps.count > 0) {
      mutableMetadata[(NSString *)kCGImagePropertyGPSDictionary] = gps;
    }
  }

  // 填充EXIF镜头元数据
  NSMutableDictionary *exif =
      metadata[(NSString *)kCGImagePropertyExifDictionary]
          ? [metadata[(NSString *)kCGImagePropertyExifDictionary] mutableCopy]
          : [NSMutableDictionary dictionary];
  [self populateLensMetadataInExif:exif device:device lensOption:lensOption];

  if (exif.count > 0) {
    mutableMetadata[(NSString *)kCGImagePropertyExifDictionary] = exif;
  }

  return [mutableMetadata copy];
}

#pragma mark - Lens Metadata

- (void)populateLensMetadataInExif:(NSMutableDictionary *)exif
                            device:(AVCaptureDevice *)device
                        lensOption:(CMCameraLensOption *)lensOption {
  if (!device) {
    return;
  }

  // 镜头制造商
  NSString *manufacturer = nil;
  if ([device respondsToSelector:@selector(manufacturer)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    manufacturer = device.manufacturer;
#pragma clang diagnostic pop
  }
  if (manufacturer.length == 0) {
    manufacturer = @"Apple";
  }
  exif[(NSString *)kCGImagePropertyExifLensMake] = manufacturer;

  // 镜头型号
  NSString *lensModel = nil;
  if (device.localizedName.length > 0 && lensOption.displayName.length > 0) {
    if ([lensOption.displayName isEqualToString:device.localizedName]) {
      lensModel = lensOption.displayName;
    } else {
      lensModel = [NSString stringWithFormat:@"%@ %@",
                                             device.localizedName,
                                             lensOption.displayName];
    }
  } else if (lensOption.displayName.length > 0) {
    lensModel = lensOption.displayName;
  } else if (device.localizedName.length > 0) {
    lensModel = device.localizedName;
  } else {
    lensModel = @"Camera Lens";
  }
  exif[(NSString *)kCGImagePropertyExifLensModel] = lensModel;

  // 镜头序列号(使用设备ID)
  if (lensOption.deviceUniqueID.length > 0) {
    exif[(NSString *)kCGImagePropertyExifLensSerialNumber] =
        lensOption.deviceUniqueID;
  }

  // 数字变焦比率
  CGFloat zoomFactor = lensOption ? lensOption.zoomFactor : 1.0f;
  if (zoomFactor > 0.0f) {
    exif[(NSString *)kCGImagePropertyExifDigitalZoomRatio] =
        @(roundf(zoomFactor * 100.0f) / 100.0f);
  }

  // 光圈值
  CGFloat aperture = device.lensAperture;
  if (aperture > 0.0f) {
    NSNumber *apertureNumber = @(roundf(aperture * 100.0f) / 100.0f);
    exif[(NSString *)kCGImagePropertyExifFNumber] = apertureNumber;
    if (!exif[(NSString *)kCGImagePropertyExifMaxApertureValue]) {
      exif[(NSString *)kCGImagePropertyExifMaxApertureValue] =
          apertureNumber;
    }
  }

  // 焦距
  NSNumber *focalLengthNumber =
      exif[(NSString *)kCGImagePropertyExifFocalLength];
  if (!focalLengthNumber) {
    CGFloat baseFocal = [self baselineFocalLengthForDevice:device];
    CGFloat computedFocal = baseFocal * MAX(zoomFactor, 0.1f);
    focalLengthNumber = @(roundf(computedFocal * 10.0f) / 10.0f);
    exif[(NSString *)kCGImagePropertyExifFocalLength] = focalLengthNumber;
  }

  // 35mm等效焦距
  if (!exif[(NSString *)kCGImagePropertyExifFocalLenIn35mmFilm] &&
      focalLengthNumber) {
    exif[(NSString *)kCGImagePropertyExifFocalLenIn35mmFilm] =
        @(roundf(focalLengthNumber.doubleValue));
  }

  // 镜头规格
  if (!exif[(NSString *)kCGImagePropertyExifLensSpecification]) {
    double focal = focalLengthNumber.doubleValue;
    NSNumber *focalSpec = @(round(focal * 10.0) / 10.0);
    NSNumber *apertureSpec =
        (aperture > 0.0f) ? @(round(aperture * 100.0f) / 100.0f) : @(0.0f);
    exif[(NSString *)kCGImagePropertyExifLensSpecification] =
        @[ focalSpec, focalSpec, apertureSpec, apertureSpec ];
  }
}

#pragma mark - GPS Metadata

- (NSDictionary *)gpsDictionaryForLocation:(CLLocation *)location {
  if (![self isValidLocation:location]) {
    return nil;
  }

  NSMutableDictionary *gps = [NSMutableDictionary dictionary];
  CLLocationCoordinate2D coordinate = location.coordinate;

  // 纬度
  double latitude = fabs(coordinate.latitude);
  double longitude = fabs(coordinate.longitude);
  gps[(NSString *)kCGImagePropertyGPSLatitude] = @(latitude);
  gps[(NSString *)kCGImagePropertyGPSLatitudeRef] =
      (coordinate.latitude >= 0.0) ? @"N" : @"S";

  // 经度
  gps[(NSString *)kCGImagePropertyGPSLongitude] = @(longitude);
  gps[(NSString *)kCGImagePropertyGPSLongitudeRef] =
      (coordinate.longitude >= 0.0) ? @"E" : @"W";

  // 海拔
  double altitude = location.altitude;
  gps[(NSString *)kCGImagePropertyGPSAltitude] = @(fabs(altitude));
  gps[(NSString *)kCGImagePropertyGPSAltitudeRef] =
      (altitude < 0.0) ? @1 : @0;

  // 时间戳
  static NSDateFormatter *dateFormatter = nil;
  static NSDateFormatter *timeFormatter = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy:MM:dd";
    dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    dateFormatter.locale =
        [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

    timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.dateFormat = @"HH:mm:ss.SSS";
    timeFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    timeFormatter.locale =
        [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  });

  NSDate *timestamp = location.timestamp ?: [NSDate date];
  gps[(NSString *)kCGImagePropertyGPSDateStamp] =
      [dateFormatter stringFromDate:timestamp];
  gps[(NSString *)kCGImagePropertyGPSTimeStamp] =
      [timeFormatter stringFromDate:timestamp];

  // 精度
  if (location.horizontalAccuracy >= 0.0) {
    gps[(NSString *)kCGImagePropertyGPSDOP] =
        @(MAX(location.horizontalAccuracy, 1.0));
  }

  // 速度
  if (location.speed >= 0.0) {
    double speedKmh = location.speed * 3.6;
    gps[(NSString *)kCGImagePropertyGPSSpeed] = @(speedKmh);
    gps[(NSString *)kCGImagePropertyGPSSpeedRef] = @"K";
  }

  // 方向
  if (location.course >= 0.0) {
    gps[(NSString *)kCGImagePropertyGPSTrack] = @(location.course);
    gps[(NSString *)kCGImagePropertyGPSTrackRef] = @"T";
  }

  return [gps copy];
}

- (BOOL)isValidLocation:(CLLocation *)location {
  if (!location) {
    return NO;
  }
  if (location.horizontalAccuracy < 0.0) {
    return NO;
  }
  NSTimeInterval age = fabs([location.timestamp timeIntervalSinceNow]);
  return age <= 300.0; // 5分钟内的位置有效
}

#pragma mark - Helpers

- (CGFloat)baselineFocalLengthForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return 24.0f;
  }
  if (device.position == AVCaptureDevicePositionFront) {
    return 28.0f;
  }
  return 24.0f;
}

@end
