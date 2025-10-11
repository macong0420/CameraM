//
//  CMImageProcessor.h
//  CameraM
//
//  图片处理模块 - 从CameraManager拆分
//  职责: 图片裁剪、方向归一化、相册保存
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "../Managers/CameraManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMImageProcessor : NSObject

#pragma mark - Image Normalization

/// 标准化图像方向为UIImageOrientationUp
- (UIImage *)normalizeImageOrientation:(UIImage *)image;

#pragma mark - Image Cropping

/// 计算指定比例的裁剪区域
- (CGRect)cropRectForAspectRatio:(CameraAspectRatio)ratio
                     inImageSize:(CGSize)imageSize
                   withOrientation:(CameraDeviceOrientation)orientation;

/// 裁剪图片到指定比例
- (UIImage * _Nullable)cropImage:(UIImage *)image
                  toAspectRatio:(CameraAspectRatio)ratio
                withOrientation:(CameraDeviceOrientation)orientation;

#pragma mark - Photo Library

/// 保存图片到相册
- (void)saveImageToPhotosLibrary:(UIImage *)image
                        metadata:(NSDictionary * _Nullable)metadata
                      completion:(void (^_Nullable)(BOOL success, NSError * _Nullable error))completion;

#pragma mark - Helpers

/// 从metadata中提取创建日期
- (NSDate * _Nullable)creationDateFromMetadata:(NSDictionary * _Nullable)metadata;

/// 从metadata中提取位置信息
- (CLLocation * _Nullable)locationFromMetadata:(NSDictionary * _Nullable)metadata;

/// 计算比例值
- (CGFloat)aspectRatioValueForRatio:(CameraAspectRatio)ratio
                    inOrientation:(CameraDeviceOrientation)orientation;

@end

NS_ASSUME_NONNULL_END
