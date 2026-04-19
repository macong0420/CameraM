//
//  CMImageProcessor.m
//  CameraM
//
//  图片处理模块实现 - 从CameraManager拆分
//

#import "CMImageProcessor.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

static const CGFloat kCMPhotoSaveJPEGQuality = 0.96f;

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

  return CGRectIntegral(cropRect);
}

- (UIImage *)cropImage:(UIImage *)image
        toAspectRatio:(CameraAspectRatio)ratio
      withOrientation:(CameraDeviceOrientation)orientation {
  if (!image) {
    return nil;
  }

  // 第一步：将图像标准化为UIImageOrientationUp方向
  UIImage *normalizedImage = [self normalizeImageOrientation:image];

  // 第二步：在标准化的图像上进行裁剪
  CGRect cropRect = [self cropRectForAspectRatio:ratio
                                     inImageSize:normalizedImage.size
                                 withOrientation:orientation];

  // 第三步：执行裁剪
  CGImageRef croppedCGImage =
      CGImageCreateWithImageInRect(normalizedImage.CGImage, cropRect);
  if (!croppedCGImage) {
    return image;
  }

  UIImage *croppedImage = [UIImage imageWithCGImage:croppedCGImage];
  CGImageRelease(croppedCGImage);

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

  void (^performSaveBlock)(void) = ^{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      NSData *photoData = UIImageJPEGRepresentation(image, kCMPhotoSaveJPEGQuality);

      [[PHPhotoLibrary sharedPhotoLibrary]
          performChanges:^{
            PHAssetCreationRequest *request = nil;
            if (photoData.length > 0) {
              request = [PHAssetCreationRequest creationRequestForAsset];
              [request addResourceWithType:PHAssetResourceTypePhoto
                                      data:photoData
                                   options:nil];
            } else {
              request = [PHAssetCreationRequest creationRequestForAssetFromImage:image];
            }

            NSDate *creationDate = [self creationDateFromMetadata:metadata];
            if (creationDate) {
              request.creationDate = creationDate;
            }

            CLLocation *location = [self locationFromMetadata:metadata];
            if (location) {
              request.location = location;
            }
          }
          completionHandler:^(BOOL success, NSError *error) {
            if (completion) {
              dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
              });
            }
          }];
    });
  };

  PHAuthorizationStatus status =
      [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
  if (status == PHAuthorizationStatusAuthorized ||
      status == PHAuthorizationStatusLimited) {
    performSaveBlock();
    return;
  }

  if (status == PHAuthorizationStatusNotDetermined) {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus grantedStatus) {
      if (grantedStatus == PHAuthorizationStatusAuthorized ||
          grantedStatus == PHAuthorizationStatusLimited) {
        performSaveBlock();
      } else if (completion) {
        NSError *permissionError =
            [NSError errorWithDomain:@"CMImageProcessor"
                                code:2002
                            userInfo:@{
                              NSLocalizedDescriptionKey : @"Photo library permission denied"
                            }];
        dispatch_async(dispatch_get_main_queue(), ^{
          completion(NO, permissionError);
        });
      }
    }];
    return;
  }

  if (completion) {
    NSError *permissionError = [NSError errorWithDomain:@"CMImageProcessor"
                                                   code:2002
                                               userInfo:@{
                                                 NSLocalizedDescriptionKey : @"Photo library permission denied"
                                               }];
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(NO, permissionError);
    });
  }
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
