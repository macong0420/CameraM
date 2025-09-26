//
//  ARWarmToneOperation.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "ARWarmToneOperation.h"
@import CoreImage;

@implementation ARWarmToneOperation

- (CIImage *)applyToImage:(CIImage *)image {
  // 暖色调调整
  CIFilter *tempFilter = [CIFilter filterWithName:@"CITemperatureAndTint"];
  [tempFilter setValue:image forKey:kCIInputImageKey];
  [tempFilter setValue:[CIVector vectorWithX:6500 Y:0] forKey:@"inputNeutral"];
  [tempFilter setValue:[CIVector vectorWithX:5500 Y:50]
                forKey:@"inputTargetNeutral"];
  CIImage *warmTone = tempFilter.outputImage ?: image;

  // 增加饱和度和对比度
  CIFilter *colorFilter = [CIFilter filterWithName:@"CIColorControls"];
  [colorFilter setValue:warmTone forKey:kCIInputImageKey];
  [colorFilter setValue:@(1.15) forKey:kCIInputSaturationKey];
  [colorFilter setValue:@(1.08) forKey:kCIInputContrastKey];
  [colorFilter setValue:@(0.02) forKey:kCIInputBrightnessKey];
  CIImage *enhanced = colorFilter.outputImage ?: warmTone;

  // 轻微的高光压制和阴影提升
  CIFilter *shadowFilter = [CIFilter filterWithName:@"CIHighlightShadowAdjust"];
  [shadowFilter setValue:enhanced forKey:kCIInputImageKey];
  [shadowFilter setValue:@(0.8) forKey:@"inputHighlightAmount"];
  [shadowFilter setValue:@(1.2) forKey:@"inputShadowAmount"];
  CIImage *shadows = shadowFilter.outputImage ?: enhanced;

  return shadows;
}

@end