//
//  ARFilterFactory.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "ARFilterFactory.h"
#import "ARClassicBWOperation.h"
#import "ARCoolToneOperation.h"
#import "ARFilterDescriptor.h"
#import "ARFilterPipeline.h"
#import "ARWarmToneOperation.h"

@implementation ARFilterFactory

+ (NSArray<ARFilterDescriptor *> *)defaultFilters {
  // 1) 原片
  ARFilterPipeline *none = [[ARFilterPipeline alloc] initWithOperations:@[]];
  ARFilterDescriptor *d0 = [ARFilterDescriptor descriptorWithId:@"none"
                                                           name:@"原片"
                                                       pipeline:none];

  // 2) 经典黑白
  ARFilterPipeline *bw = [[ARFilterPipeline alloc]
      initWithOperations:@[ [ARClassicBWOperation new] ]];
  ARFilterDescriptor *d1 = [ARFilterDescriptor descriptorWithId:@"classic_bw"
                                                           name:@"经典黑白"
                                                       pipeline:bw];

  // 3) 暖色调
  ARFilterPipeline *warm = [[ARFilterPipeline alloc]
      initWithOperations:@[ [ARWarmToneOperation new] ]];
  ARFilterDescriptor *d2 = [ARFilterDescriptor descriptorWithId:@"warm_tone"
                                                           name:@"暖色调"
                                                       pipeline:warm];

  // 4) 冷色调
  ARFilterPipeline *cool = [[ARFilterPipeline alloc]
      initWithOperations:@[ [ARCoolToneOperation new] ]];
  ARFilterDescriptor *d3 = [ARFilterDescriptor descriptorWithId:@"cool_tone"
                                                           name:@"冷色调"
                                                       pipeline:cool];

  return @[ d0, d1, d2, d3 ];
}

@end