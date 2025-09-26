//
//  ARCoolToneOperation.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "ARCoolToneOperation.h"
@import CoreImage;

@implementation ARCoolToneOperation

- (CIImage *)applyToImage:(CIImage *)image {
  // 冷色调调整
  CIFilter *tempFilter = [CIFilter filterWithName:@"CITemperatureAndTint"];
  [tempFilter setValue:image forKey:kCIInputImageKey];
  [tempFilter setValue:[CIVector vectorWithX:6500 Y:0] forKey:@"inputNeutral"];
  [tempFilter setValue:[CIVector vectorWithX:7500 Y:-30]
                forKey:@"inputTargetNeutral"];
  CIImage *coolTone = tempFilter.outputImage ?: image;

  // 调整饱和度和对比度
  CIFilter *colorFilter = [CIFilter filterWithName:@"CIColorControls"];
  [colorFilter setValue:coolTone forKey:kCIInputImageKey];
  [colorFilter setValue:@(1.1) forKey:kCIInputSaturationKey];
  [colorFilter setValue:@(1.12) forKey:kCIInputContrastKey];
  [colorFilter setValue:@(-0.01) forKey:kCIInputBrightnessKey];
  CIImage *enhanced = colorFilter.outputImage ?: coolTone;

  // 轻微的蓝色偏移
  CIFilter *matrixFilter = [CIFilter filterWithName:@"CIColorMatrix"];
  [matrixFilter setValue:enhanced forKey:kCIInputImageKey];
  [matrixFilter setValue:[CIVector vectorWithX:0.98 Y:0 Z:0 W:0]
                  forKey:@"inputRVector"];
  [matrixFilter setValue:[CIVector vectorWithX:0 Y:0.99 Z:0 W:0]
                  forKey:@"inputGVector"];
  [matrixFilter setValue:[CIVector vectorWithX:0 Y:0 Z:1.05 W:0]
                  forKey:@"inputBVector"];
  [matrixFilter setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:1]
                  forKey:@"inputAVector"];
  CIImage *colorMatrix = matrixFilter.outputImage ?: enhanced;

  return colorMatrix;
}

@end