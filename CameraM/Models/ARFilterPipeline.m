//
//  ARFilterPipeline.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "ARFilterPipeline.h"
#import "CMFilmLookOperations.h"

@interface ARFilterPipeline ()
@property(nonatomic, strong, readwrite)
    NSArray<id<ARFilterOperation>> *operations;
@end

@implementation ARFilterPipeline

- (instancetype)initWithOperations:(NSArray<id<ARFilterOperation>> *)ops {
  if (self = [super init]) {
    _operations = [ops copy];
    _intensity = 1.0f;
  }
  return self;
}

- (CMFilmGrainOperation *)grainOperation {
  for (id<ARFilterOperation> op in self.operations) {
    if ([op isKindOfClass:[CMFilmGrainOperation class]]) {
      return (CMFilmGrainOperation *)op;
    }
  }
  return nil;
}

- (BOOL)supportsGrainAdjustment {
  return [self grainOperation] != nil;
}

- (float)grainIntensity {
  CMFilmGrainOperation *grain = [self grainOperation];
  return grain ? grain.intensity : 0.0f;
}

- (void)setGrainIntensity:(float)grainIntensity {
  CMFilmGrainOperation *grain = [self grainOperation];
  if (grain) {
    grain.intensity = MAX(0.0f, MIN(1.0f, grainIntensity));
  }
}

- (CIImage *)process:(CIImage *)image {
  CIImage *out = image;
  for (id<ARFilterOperation> op in self.operations) {
    out = [op applyToImage:out] ?: out;
  }

  // 全局强度混合：原图与 out 的线性混合
  if (self.intensity < 0.999f) {
    CIFilter *blend = [CIFilter filterWithName:@"CISourceOverCompositing"];
    // 构造 alpha 面具
    CIImage *mask =
        [[CIImage imageWithColor:[CIColor colorWithRed:self.intensity
                                                 green:self.intensity
                                                  blue:self.intensity
                                                 alpha:1.0]]
            imageByCroppingToRect:out.extent];
    CIFilter *maskBlend = [CIFilter filterWithName:@"CIBlendWithAlphaMask"];
    [maskBlend setValue:out forKey:kCIInputImageKey];
    [maskBlend setValue:image forKey:kCIInputBackgroundImageKey];
    [maskBlend setValue:mask forKey:@"inputMaskImage"];
    out = maskBlend.outputImage ?: out;
  }
  return out;
}

@end