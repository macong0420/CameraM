//
//  CMImageProcessor.m
//  CameraM
//
//  图片处理模块实现 - 从CameraManager拆分
//

#import "CMImageProcessor.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

@implementation CMImageProcessor

#pragma mark - Image Normalization

- (UIImage *)normalizeImageOrientation:(UIImage *)image {
  if (!image || image.imageOrientation == UIImageOrientationUp) {
    return image; // 已经是标准方向或图像为空
  }

  CGSize size = image.size;
  UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
  [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
  UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return normalizedImage ? normalizedImage : image;
}

#pragma mark - Image Cropping

- (CGRect)cropRectForAspectRatio:(CameraAspectRatio)ratio
                     inImageSize:(CGSize)imageSize
                   withOrientation:(CameraDeviceOrientation)orientation {
  const CGFloat imageWidth = imageSize.width;
  const CGFloat imageHeight = imageSize.height;

  if (imageWidth <= 0.0f || imageHeight <= 0.0f) {
    return CGRectZero;
  }

  const CGFloat targetAspect = [self aspectRatioValueForRatio:ratio
                                                 inOrientation:orientation];
  if (targetAspect <= 0.0f) {
    return CGRectMake(0.0f, 0.0f, imageWidth, imageHeight);
  }

  const CGFloat imageAspect = imageWidth / imageHeight;
  CGRect cropRect = CGRectMake(0.0f, 0.0f, imageWidth, imageHeight);

  if (fabs(imageAspect - targetAspect) < 0.0001f) {
    return CGRectIntegral(cropRect);
  }

  if (imageAspect > targetAspect) {
    // 图像比目标更宽，需要裁剪左右两侧
    const CGFloat targetWidth = imageHeight * targetAspect;
    const CGFloat xOffset = (imageWidth - targetWidth) / 2.0f;
    cropRect = CGRectMake(xOffset, 0.0f, targetWidth, imageHeight);
  } else {
    // 图像比目标更窄（或更高），裁剪上下
    const CGFloat targetHeight = imageWidth / targetAspect;
    const CGFloat yOffset = (imageHeight - targetHeight) / 2.0f;
    cropRect = CGRectMake(0.0f, yOffset, imageWidth, targetHeight);
  }

  NSLog(@"📐 [CMImageProcessor] 裁剪区域: %@, 原图尺寸: %.0fx%.0f, 目标比例: %.3f",
        NSStringFromCGRect(cropRect), imageWidth, imageHeight, targetAspect);
  return CGRectIntegral(cropRect);
}

- (UIImage *)cropImage:(UIImage *)image
        toAspectRatio:(CameraAspectRatio)ratio
      withOrientation:(CameraDeviceOrientation)orientation {
  if (!image) {
    return nil;
  }

  NSLog(@"🖼 [CMImageProcessor] 原始图像信息 - 尺寸: (%.0fx%.0f), 方向: %ld, 比例目标: %ld",
        image.size.width, image.size.height, (long)image.imageOrientation,
        (long)ratio);

  // 第一步：将图像标准化为UIImageOrientationUp方向
  UIImage *normalizedImage = [self normalizeImageOrientation:image];

  NSLog(@"✅ [CMImageProcessor] 标准化后图像 - 尺寸: (%.0fx%.0f), 方向: %ld",
        normalizedImage.size.width, normalizedImage.size.height,
        (long)normalizedImage.imageOrientation);

  // 第二步：在标准化的图像上进行裁剪
  CGRect cropRect = [self cropRectForAspectRatio:ratio
                                     inImageSize:normalizedImage.size
                                 withOrientation:orientation];

  NSLog(@"✂️ [CMImageProcessor] 计算的裁剪区域: (%.0f, %.0f, %.0f, %.0f)",
        cropRect.origin.x, cropRect.origin.y, cropRect.size.width, cropRect.size.height);

  // 第三步：执行裁剪
  CGImageRef croppedCGImage =
      CGImageCreateWithImageInRect(normalizedImage.CGImage, cropRect);
  if (!croppedCGImage) {
    NSLog(@"❌ [CMImageProcessor] 裁剪失败，返回原图");
    return image;
  }

  UIImage *croppedImage = [UIImage imageWithCGImage:croppedCGImage];
  CGImageRelease(croppedCGImage);

  NSLog(@"🎉 [CMImageProcessor] 最终裁剪结果 - 尺寸: (%.0fx%.0f), 实际比例: %.2f:1",
        croppedImage.size.width, croppedImage.size.height,
        croppedImage.size.width / croppedImage.size.height);

  return croppedImage;
}

#pragma mark - Photo Library

- (void)saveImageToPhotosLibrary:(UIImage *)image
                        metadata:(NSDictionary *)metadata
                      completion:(void (^)(BOOL success, NSError *error))completion {
  if (!image) {
    if (completion) {
      dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = [NSError errorWithDomain:@"CMImageProcessor"
                                             code:2001
                                         userInfo:@{
                                           NSLocalizedDescriptionKey : @"Image is nil"
                                         }];
        completion(NO, error);
      });
    }
    return;
  }

  [PHPhotoLibrary
      requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                 handler:^(PHAuthorizationStatus status) {
                                   if (status == PHAuthorizationStatusAuthorized ||
                                       status == PHAuthorizationStatusLimited) {
                                     [[PHPhotoLibrary sharedPhotoLibrary]
                                         performChanges:^{
                                           PHAssetCreationRequest *request =
                                               [PHAssetCreationRequest
                                                   creationRequestForAssetFromImage:image];

                                           // 设置创建日期
                                           NSDate *creationDate =
                                               [self creationDateFromMetadata:metadata];
                                           if (creationDate) {
                                             request.creationDate = creationDate;
                                           }

                                           // 设置位置信息
                                           CLLocation *location =
                                               [self locationFromMetadata:metadata];
                                           if (location) {
                                             request.location = location;
                                           }
                                         }
                                         completionHandler:^(BOOL success,
                                                           NSError *error) {
                                           if (!success && error) {
                                             NSLog(@"❌ [CMImageProcessor] 保存图片失败: %@",
                                                   error.localizedDescription);
                                           } else {
                                             NSLog(@"✅ [CMImageProcessor] 图片保存成功");
                                           }
                                           if (completion) {
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                               completion(success, error);
                                             });
                                           }
                                         }];
                                   } else {
                                     if (completion) {
                                       NSError *permissionError =
                                           [NSError errorWithDomain:@"CMImageProcessor"
                                                               code:2002
                                                           userInfo:@{
                                                             NSLocalizedDescriptionKey :
                                                                 @"Photo library permission denied"
                                                           }];
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                         completion(NO, permissionError);
                                       });
                                     }
                                   }
                                 }];
}

#pragma mark - Helpers

- (NSDate *)creationDateFromMetadata:(NSDictionary *)metadata {
  if (!metadata) {
    return nil;
  }

  // 尝试从EXIF中提取日期
  NSDictionary *exifDict = metadata[(NSString *)kCGImagePropertyExifDictionary];
  if (exifDict) {
    NSString *dateString = exifDict[(NSString *)kCGImagePropertyExifDateTimeOriginal];
    if (dateString) {
      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
      formatter.dateFormat = @"yyyy:MM:dd HH:mm:ss";
      formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
      formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
      NSDate *date = [formatter dateFromString:dateString];
      if (date) {
        return date;
      }
    }
  }

  return nil;
}

- (CLLocation *)locationFromMetadata:(NSDictionary *)metadata {
  if (!metadata) {
    return nil;
  }

  NSDictionary *gpsDict = metadata[(NSString *)kCGImagePropertyGPSDictionary];
  if (!gpsDict) {
    return nil;
  }

  NSNumber *latitudeNum = gpsDict[(NSString *)kCGImagePropertyGPSLatitude];
  NSString *latitudeRef = gpsDict[(NSString *)kCGImagePropertyGPSLatitudeRef];
  NSNumber *longitudeNum = gpsDict[(NSString *)kCGImagePropertyGPSLongitude];
  NSString *longitudeRef = gpsDict[(NSString *)kCGImagePropertyGPSLongitudeRef];

  if (!latitudeNum || !longitudeNum) {
    return nil;
  }

  CLLocationDegrees latitude = latitudeNum.doubleValue;
  if ([latitudeRef isEqualToString:@"S"]) {
    latitude = -latitude;
  }

  CLLocationDegrees longitude = longitudeNum.doubleValue;
  if ([longitudeRef isEqualToString:@"W"]) {
    longitude = -longitude;
  }

  CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
  if (!CLLocationCoordinate2DIsValid(coordinate)) {
    return nil;
  }

  // 提取海拔信息
  CLLocationDistance altitude = 0.0;
  NSNumber *altitudeNum = gpsDict[(NSString *)kCGImagePropertyGPSAltitude];
  if (altitudeNum) {
    altitude = altitudeNum.doubleValue;
    NSNumber *altitudeRef = gpsDict[(NSString *)kCGImagePropertyGPSAltitudeRef];
    if (altitudeRef && altitudeRef.intValue == 1) {
      altitude = -altitude; // 海平面以下
    }
  }

  // 提取时间戳
  NSDate *timestamp = nil;
  NSString *dateStamp = gpsDict[(NSString *)kCGImagePropertyGPSDateStamp];
  NSString *timeStamp = gpsDict[(NSString *)kCGImagePropertyGPSTimeStamp];
  if (dateStamp && timeStamp) {
    NSString *dateTimeString = [NSString stringWithFormat:@"%@ %@", dateStamp, timeStamp];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy:MM:dd HH:mm:ss.SSS";
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    timestamp = [formatter dateFromString:dateTimeString];
  }

  return [[CLLocation alloc] initWithCoordinate:coordinate
                                       altitude:altitude
                             horizontalAccuracy:0.0
                               verticalAccuracy:0.0
                                      timestamp:timestamp ?: [NSDate date]];
}

- (CGFloat)aspectRatioValueForRatio:(CameraAspectRatio)ratio
                    inOrientation:(CameraDeviceOrientation)orientation {
  BOOL isPortrait = (orientation == CameraDeviceOrientationPortrait);

  switch (ratio) {
  case CameraAspectRatio4to3:
    // 竖屏: 3:4 (0.75), 横屏: 4:3 (1.33)
    return isPortrait ? (3.0f / 4.0f) : (4.0f / 3.0f);
  case CameraAspectRatio1to1:
    // 正方形在任何方向都是1:1
    return 1.0f;
  case CameraAspectRatioXpan:
    // 竖屏: 24:65 (0.37), 横屏: 65:24 (2.7)
    return isPortrait ? (24.0f / 65.0f) : (65.0f / 24.0f);
  }
  return 1.0f;
}

@end
