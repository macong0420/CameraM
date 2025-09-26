//
//  ARFilterDescriptor.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "ARFilterDescriptor.h"
#import "ARFilterPipeline.h"

@implementation ARFilterDescriptor

+ (instancetype)descriptorWithId:(NSString *)identifier
                            name:(NSString *)name
                        pipeline:(ARFilterPipeline *)pipeline {
  return [self descriptorWithId:identifier
                            name:name
                         pipeline:pipeline
                       accentColor:nil];
}

+ (instancetype)descriptorWithId:(NSString *)identifier
                             name:(NSString *)name
                         pipeline:(ARFilterPipeline *)pipeline
                       accentColor:(UIColor *)accentColor {
  ARFilterDescriptor *d = [ARFilterDescriptor new];
  d.identifier = identifier;
  d.displayName = name;
  d.pipeline = pipeline;
  d.intensity = 1.0f;
  d.accentColor = accentColor ?: [UIColor systemOrangeColor];
  return d;
}

@end