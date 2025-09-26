//
//  ARClassicBWOperation.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "ARClassicBWOperation.h"
@import CoreImage;

@implementation ARClassicBWOperation

- (CIImage *)applyToImage:(CIImage *)image {
  // 去饱和 + 轻对比
  CIFilter *colorFilter = [CIFilter filterWithName:@"CIColorControls"];
  [colorFilter setValue:image forKey:kCIInputImageKey];
  [colorFilter setValue:@(0.0) forKey:kCIInputSaturationKey];
  [colorFilter setValue:@(1.05) forKey:kCIInputContrastKey];
  CIImage *desat = colorFilter.outputImage ?: image;

  // 胶片曲线
  CIFilter *curveFilter = [CIFilter filterWithName:@"CIToneCurve"];
  [curveFilter setValue:desat forKey:kCIInputImageKey];
  [curveFilter setValue:[CIVector vectorWithX:0 Y:0] forKey:@"inputPoint0"];
  [curveFilter setValue:[CIVector vectorWithX:0.25 Y:0.22]
                 forKey:@"inputPoint1"];
  [curveFilter setValue:[CIVector vectorWithX:0.5 Y:0.55]
                 forKey:@"inputPoint2"];
  [curveFilter setValue:[CIVector vectorWithX:0.75 Y:0.82]
                 forKey:@"inputPoint3"];
  [curveFilter setValue:[CIVector vectorWithX:1.0 Y:1.0] forKey:@"inputPoint4"];
  CIImage *curve = curveFilter.outputImage ?: desat;

  // 轻微局部对比（明度锐化）
  CIFilter *luma = [CIFilter filterWithName:@"CILumaSharpen"];
  [luma setValue:curve forKey:kCIInputImageKey];
  [luma setValue:@(0.25) forKey:@"inputAmount"];
  [luma setValue:@(2.0) forKey:@"inputRadius"];
  CIImage *lumaImg = luma.outputImage ?: curve;

  // 渐晕
  CIFilter *vignetteFilter = [CIFilter filterWithName:@"CIVignette"];
  [vignetteFilter setValue:lumaImg forKey:kCIInputImageKey];
  [vignetteFilter setValue:@(0.35) forKey:@"inputIntensity"];
  [vignetteFilter setValue:@(1.0) forKey:@"inputRadius"];
  CIImage *vignette = vignetteFilter.outputImage ?: lumaImg;

  return vignette;
}

@end