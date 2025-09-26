//
//  CMFilmLookOperations.m
//  CameraM
//
//  Created by OpenAI Assistant on 2024/4/6.
//

#import "CMFilmLookOperations.h"
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

static inline CGFloat CMClamp(CGFloat value, CGFloat minValue, CGFloat maxValue) {
  if (value < minValue) {
    return minValue;
  }
  if (value > maxValue) {
    return maxValue;
  }
  return value;
}

static inline CGFloat CMSmoothstep(CGFloat edge0, CGFloat edge1, CGFloat x) {
  CGFloat t = CMClamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
  return t * t * (3.0f - 2.0f * t);
}

static void CMRGBToHSL(CGFloat r, CGFloat g, CGFloat b, CGFloat *outH, CGFloat *outS,
                       CGFloat *outL) {
  CGFloat maxValue = MAX(r, MAX(g, b));
  CGFloat minValue = MIN(r, MIN(g, b));
  CGFloat h = 0.0f;
  CGFloat s = 0.0f;
  CGFloat l = (maxValue + minValue) * 0.5f;

  if (fabs(maxValue - minValue) < 1e-5f) {
    h = 0.0f;
    s = 0.0f;
  } else {
    CGFloat d = maxValue - minValue;
    s = l > 0.5f ? d / (2.0f - maxValue - minValue) : d / (maxValue + minValue);

    if (maxValue == r) {
      h = (g - b) / d + (g < b ? 6.0f : 0.0f);
    } else if (maxValue == g) {
      h = (b - r) / d + 2.0f;
    } else {
      h = (r - g) / d + 4.0f;
    }
    h /= 6.0f;
  }

  if (outH) {
    *outH = h;
  }
  if (outS) {
    *outS = s;
  }
  if (outL) {
    *outL = l;
  }
}

static CGFloat CMHueToRGB(CGFloat p, CGFloat q, CGFloat t) {
  if (t < 0.0f) {
    t += 1.0f;
  }
  if (t > 1.0f) {
    t -= 1.0f;
  }
  if (t < 1.0f / 6.0f) {
    return p + (q - p) * 6.0f * t;
  }
  if (t < 1.0f / 2.0f) {
    return q;
  }
  if (t < 2.0f / 3.0f) {
    return p + (q - p) * (2.0f / 3.0f - t) * 6.0f;
  }
  return p;
}

static void CMHSLToRGB(CGFloat h, CGFloat s, CGFloat l, CGFloat *outR, CGFloat *outG,
                       CGFloat *outB) {
  CGFloat r = l;
  CGFloat g = l;
  CGFloat b = l;

  if (s > 1e-5f) {
    CGFloat q = l < 0.5f ? l * (1.0f + s) : l + s - l * s;
    CGFloat p = 2.0f * l - q;
    r = CMHueToRGB(p, q, h + 1.0f / 3.0f);
    g = CMHueToRGB(p, q, h);
    b = CMHueToRGB(p, q, h - 1.0f / 3.0f);
  }

  if (outR) {
    *outR = r;
  }
  if (outG) {
    *outG = g;
  }
  if (outB) {
    *outB = b;
  }
}

CMHSLAdjustment CMHSLAdjustmentMake(CGFloat startHue, CGFloat endHue, CGFloat hueShift,
                                    CGFloat saturationScale, CGFloat luminanceShift) {
  CMHSLAdjustment adjustment;
  adjustment.startHue = startHue;
  adjustment.endHue = endHue;
  adjustment.hueShift = hueShift;
  adjustment.saturationScale = saturationScale;
  adjustment.luminanceShift = luminanceShift;
  return adjustment;
}

@implementation NSValue (CMFilmAdjustments)

+ (instancetype)valueWithCMHSLAdjustment:(CMHSLAdjustment)adjustment {
  return [NSValue valueWithBytes:&adjustment objCType:@encode(CMHSLAdjustment)];
}

- (CMHSLAdjustment)cm_HSLAdjustmentValue {
  CMHSLAdjustment adjustment;
  [self getValue:&adjustment];
  return adjustment;
}

@end

#pragma mark - CMFilmColorMatrixOperation

@interface CMFilmColorMatrixOperation ()
@property(nonatomic, strong) CIVector *redVector;
@property(nonatomic, strong) CIVector *greenVector;
@property(nonatomic, strong) CIVector *blueVector;
@property(nonatomic, strong) CIVector *biasVector;
@property(nonatomic, strong) NSArray<CIVector *> *toneCurvePoints;
@property(nonatomic, assign) CGFloat microContrast;
@end

@implementation CMFilmColorMatrixOperation

- (instancetype)initWithRedVector:(CIVector *)redVector
                      greenVector:(CIVector *)greenVector
                       blueVector:(CIVector *)blueVector
                       biasVector:(CIVector *)biasVector
                  toneCurvePoints:(NSArray<CIVector *> *)points
                    microContrast:(CGFloat)microContrast {
  if (self = [super init]) {
    _redVector = redVector ?: [CIVector vectorWithX:1 Y:0 Z:0 W:0];
    _greenVector = greenVector ?: [CIVector vectorWithX:0 Y:1 Z:0 W:0];
    _blueVector = blueVector ?: [CIVector vectorWithX:0 Y:0 Z:1 W:0];
    _biasVector = biasVector ?: [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    _toneCurvePoints = points ?: @[];
    _microContrast = microContrast;
  }
  return self;
}

- (CIImage *)applyToImage:(CIImage *)image {
  if (!image) {
    return nil;
  }

  CIImage *output = image;

  CIFilter *matrix = [CIFilter filterWithName:@"CIColorMatrix"];
  [matrix setValue:output forKey:kCIInputImageKey];
  [matrix setValue:self.redVector forKey:@"inputRVector"];
  [matrix setValue:self.greenVector forKey:@"inputGVector"];
  [matrix setValue:self.blueVector forKey:@"inputBVector"];
  [matrix setValue:self.biasVector forKey:@"inputBiasVector"];
  output = matrix.outputImage ?: output;

  if (self.toneCurvePoints.count == 5) {
    CIFilter *curve = [CIFilter filterWithName:@"CIToneCurve"];
    [curve setValue:output forKey:kCIInputImageKey];
    [curve setValue:self.toneCurvePoints[0] forKey:@"inputPoint0"];
    [curve setValue:self.toneCurvePoints[1] forKey:@"inputPoint1"];
    [curve setValue:self.toneCurvePoints[2] forKey:@"inputPoint2"];
    [curve setValue:self.toneCurvePoints[3] forKey:@"inputPoint3"];
    [curve setValue:self.toneCurvePoints[4] forKey:@"inputPoint4"];
    output = curve.outputImage ?: output;
  }

  if (self.microContrast > 1e-4f) {
    CIFilter *unsharp = [CIFilter filterWithName:@"CIUnsharpMask"];
    [unsharp setValue:output forKey:kCIInputImageKey];
    [unsharp setValue:@(self.microContrast * 1.6f) forKey:@"inputIntensity"];
    [unsharp setValue:@(2.0f) forKey:@"inputRadius"];
    CIImage *sharp = unsharp.outputImage;
    if (sharp) {
      output = sharp;
    }
  }

  return output;
}

@end

#pragma mark - CMFilmHSLRemapOperation

@interface CMFilmHSLRemapOperation ()
@property(nonatomic, strong) NSArray<NSValue *> *adjustments;
@property(nonatomic, assign) NSUInteger cubeDimension;
@property(nonatomic, assign) CGFloat skinHueCenter;
@property(nonatomic, assign) CGFloat skinHueWidth;
@property(nonatomic, assign) CGFloat skinPreserveFactor;
@property(nonatomic, strong) NSData *cubeData;
@property(nonatomic, strong) CIFilter *colorCubeFilter;
@end

@implementation CMFilmHSLRemapOperation

- (instancetype)initWithAdjustments:(NSArray<NSValue *> *)adjustments
                      cubeDimension:(NSUInteger)dimension
                      skinHueCenter:(CGFloat)skinHueCenter
                       skinHueWidth:(CGFloat)skinHueWidth
                 skinPreserveFactor:(CGFloat)skinPreserveFactor {
  if (self = [super init]) {
    _adjustments = [adjustments copy] ?: @[];
    _cubeDimension = MAX(16, MIN(dimension, 64));
    _skinHueCenter = skinHueCenter;
    _skinHueWidth = MAX(1.0, skinHueWidth);
    _skinPreserveFactor = CMClamp(skinPreserveFactor, 0.0f, 1.0f);
    _cubeData = [self buildCubeData];
  }
  return self;
}

- (NSData *)buildCubeData {
  NSUInteger size = self.cubeDimension;
  NSUInteger cubeDataSize = size * size * size * 4;
  NSMutableData *data = [NSMutableData dataWithLength:cubeDataSize * sizeof(float)];
  float *cube = (float *)data.mutableBytes;

  CGFloat skinCenter = fmod(self.skinHueCenter, 360.0f);
  if (skinCenter < 0) {
    skinCenter += 360.0f;
  }
  CGFloat halfWidth = self.skinHueWidth * 0.5f;

  NSUInteger offset = 0;
  for (NSUInteger z = 0; z < size; z++) {
    CGFloat blue = (CGFloat)z / (CGFloat)(size - 1);
    for (NSUInteger y = 0; y < size; y++) {
      CGFloat green = (CGFloat)y / (CGFloat)(size - 1);
      for (NSUInteger x = 0; x < size; x++) {
        CGFloat red = (CGFloat)x / (CGFloat)(size - 1);

        CGFloat h, s, l;
        CMRGBToHSL(red, green, blue, &h, &s, &l);
        CGFloat originalHue = h * 360.0f;
        CGFloat originalSat = s;
        CGFloat originalLum = l;

        CGFloat hueDegrees = originalHue;
        CGFloat saturation = s;
        CGFloat luminance = l;

        for (NSValue *value in self.adjustments) {
          CMHSLAdjustment adjustment = value.cm_HSLAdjustmentValue;
          CGFloat startHue = adjustment.startHue;
          CGFloat endHue = adjustment.endHue;
          BOOL wraps = startHue > endHue;
          BOOL inRange = wraps ? (hueDegrees >= startHue || hueDegrees <= endHue)
                               : (hueDegrees >= startHue && hueDegrees <= endHue);
          if (inRange) {
            hueDegrees += adjustment.hueShift;
            saturation *= adjustment.saturationScale;
            luminance += adjustment.luminanceShift;
          }
        }

        while (hueDegrees < 0.0f) {
          hueDegrees += 360.0f;
        }
        while (hueDegrees >= 360.0f) {
          hueDegrees -= 360.0f;
        }
        saturation = CMClamp(saturation, 0.0f, 1.2f);
        luminance = CMClamp(luminance, 0.0f, 1.0f);

        CGFloat hueDistance = fabs(hueDegrees - skinCenter);
        if (hueDistance > 180.0f) {
          hueDistance = 360.0f - hueDistance;
        }
        CGFloat skinWeight = 1.0f - CMSmoothstep(halfWidth, self.skinHueWidth, hueDistance);
        skinWeight = CMClamp(skinWeight, 0.0f, 1.0f) * self.skinPreserveFactor;

        CGFloat blendFactor = 1.0f - skinWeight;
        CGFloat finalHue = (originalHue * skinWeight + hueDegrees * blendFactor) / 360.0f;
        CGFloat finalSat = originalSat * skinWeight + saturation * blendFactor;
        CGFloat finalLum = originalLum * skinWeight + luminance * blendFactor;

        CGFloat finalR, finalG, finalB;
        CMHSLToRGB(finalHue, CMClamp(finalSat, 0.0f, 1.0f), finalLum, &finalR, &finalG,
                   &finalB);

        cube[offset++] = finalR;
        cube[offset++] = finalG;
        cube[offset++] = finalB;
        cube[offset++] = 1.0f;
      }
    }
  }

  return data;
}

- (CIImage *)applyToImage:(CIImage *)image {
  if (!image || !self.cubeData) {
    return image;
  }

  if (!self.colorCubeFilter) {
    self.colorCubeFilter = [CIFilter filterWithName:@"CIColorCube"];
  }
  [self.colorCubeFilter setValue:@(self.cubeDimension) forKey:@"inputCubeDimension"];
  [self.colorCubeFilter setValue:self.cubeData forKey:@"inputCubeData"];
  [self.colorCubeFilter setValue:image forKey:kCIInputImageKey];
  CIImage *output = self.colorCubeFilter.outputImage;
  return output ?: image;
}

@end

#pragma mark - CMFilmGrainOperation

@interface CMFilmGrainOperation ()
@property(nonatomic, assign) CGFloat intensity;
@property(nonatomic, assign) CGFloat shadowWeight;
@property(nonatomic, assign) CGFloat highlightWeight;
@property(nonatomic, assign) CGFloat grainScale;
@property(nonatomic, assign) BOOL monochrome;
@end

@implementation CMFilmGrainOperation

- (instancetype)initWithIntensity:(CGFloat)intensity
                      shadowWeight:(CGFloat)shadowWeight
                   highlightWeight:(CGFloat)highlightWeight
                         grainScale:(CGFloat)grainScale
                         monochrome:(BOOL)monochrome {
  if (self = [super init]) {
    _intensity = CMClamp(intensity, 0.0f, 1.0f);
    _shadowWeight = CMClamp(shadowWeight, 0.0f, 1.0f);
    _highlightWeight = CMClamp(highlightWeight, 0.0f, 1.0f);
    _grainScale = MAX(grainScale, 0.1f);
    _monochrome = monochrome;
  }
  return self;
}

- (CIImage *)applyToImage:(CIImage *)image {
  if (!image || self.intensity <= 0.0f) {
    return image;
  }

  CIFilter *random = [CIFilter filterWithName:@"CIRandomGenerator"];
  CIImage *noise = random.outputImage;
  if (!noise) {
    return image;
  }

  CGFloat scale = 1.0f / self.grainScale;
  CIImage *scaledNoise = [noise imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
  CIImage *croppedNoise = [scaledNoise imageByCroppingToRect:image.extent];

  CIFilter *mono = [CIFilter filterWithName:@"CIColorControls"];
  [mono setValue:croppedNoise forKey:kCIInputImageKey];
  [mono setValue:@(self.monochrome ? 0.0f : 0.4f) forKey:kCIInputSaturationKey];
  [mono setValue:@(1.2f) forKey:kCIInputContrastKey];
  [mono setValue:@(-0.2f) forKey:kCIInputBrightnessKey];
  CIImage *grainBase = mono.outputImage ?: croppedNoise;

  CGFloat amplitude = self.intensity * 0.6f;
  CIFilter *scaleFilter = [CIFilter filterWithName:@"CIColorMatrix"];
  [scaleFilter setValue:grainBase forKey:kCIInputImageKey];
  [scaleFilter setValue:[CIVector vectorWithX:amplitude Y:0 Z:0 W:0] forKey:@"inputRVector"];
  [scaleFilter setValue:[CIVector vectorWithX:0 Y:amplitude Z:0 W:0] forKey:@"inputGVector"];
  [scaleFilter setValue:[CIVector vectorWithX:0 Y:0 Z:amplitude W:0] forKey:@"inputBVector"];
  [scaleFilter setValue:[CIVector vectorWithX:-amplitude * 0.5f Y:-amplitude * 0.5f
                                             Z:-amplitude * 0.5f W:0]
                forKey:@"inputBiasVector"];
  CIImage *balancedNoise = scaleFilter.outputImage ?: grainBase;

  CIVector *lumaVector = [CIVector vectorWithX:0.2126f Y:0.7152f Z:0.0722f W:0.0f];
  CIFilter *lumaFilter = [CIFilter filterWithName:@"CIColorMatrix"];
  [lumaFilter setValue:image forKey:kCIInputImageKey];
  [lumaFilter setValue:lumaVector forKey:@"inputRVector"];
  [lumaFilter setValue:lumaVector forKey:@"inputGVector"];
  [lumaFilter setValue:lumaVector forKey:@"inputBVector"];
  [lumaFilter setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:1] forKey:@"inputAVector"];
  CIImage *luma = lumaFilter.outputImage ?: image;

  CIVector *polyCoefficients =
      [CIVector vectorWithX:self.shadowWeight
                          Y:(self.highlightWeight - self.shadowWeight)
                          Z:0
                          W:0];
  CIFilter *poly = [CIFilter filterWithName:@"CIColorPolynomial"];
  [poly setValue:luma forKey:kCIInputImageKey];
  [poly setValue:polyCoefficients forKey:@"inputRedCoefficients"];
  [poly setValue:polyCoefficients forKey:@"inputGreenCoefficients"];
  [poly setValue:polyCoefficients forKey:@"inputBlueCoefficients"];
  CIImage *maskLuma = poly.outputImage ?: luma;

  CIFilter *maskAlphaFilter = [CIFilter filterWithName:@"CIColorMatrix"];
  [maskAlphaFilter setValue:maskLuma forKey:kCIInputImageKey];
  [maskAlphaFilter setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:0] forKey:@"inputRVector"];
  [maskAlphaFilter setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:0] forKey:@"inputGVector"];
  [maskAlphaFilter setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:0] forKey:@"inputBVector"];
  [maskAlphaFilter setValue:[CIVector vectorWithX:1 Y:0 Z:0 W:0] forKey:@"inputAVector"];
  CIImage *maskAlpha = maskAlphaFilter.outputImage ?: maskLuma;

  CIFilter *overlay = [CIFilter filterWithName:@"CIOverlayBlendMode"];
  [overlay setValue:balancedNoise forKey:kCIInputImageKey];
  [overlay setValue:image forKey:kCIInputBackgroundImageKey];
  CIImage *overlayed = overlay.outputImage ?: image;

  CIFilter *maskedBlend = [CIFilter filterWithName:@"CIBlendWithAlphaMask"];
  [maskedBlend setValue:overlayed forKey:kCIInputImageKey];
  [maskedBlend setValue:image forKey:kCIInputBackgroundImageKey];
  [maskedBlend setValue:maskAlpha forKey:kCIInputMaskImageKey];
  CIImage *result = maskedBlend.outputImage ?: overlayed;

  return result;
}

@end

#pragma mark - CMFilmHalationOperation

@interface CMFilmHalationOperation ()
@property(nonatomic, assign) CGFloat threshold;
@property(nonatomic, assign) CGFloat softness;
@property(nonatomic, assign) CGFloat radius;
@property(nonatomic, assign) CGFloat intensity;
@property(nonatomic, strong) UIColor *tintColor;
@end

@implementation CMFilmHalationOperation

+ (CIColorKernel *)halationKernel {
  static CIColorKernel *kernel = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *kernelString =
        @"kernel vec4 cm_halation(__sample s, float threshold, float softness) {\n"
         "  float luma = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));\n"
         "  float mask = smoothstep(threshold, threshold + softness, luma);\n"
         "  return vec4(mask, mask, mask, mask);\n"
         "}";
    kernel = [CIColorKernel kernelWithString:kernelString];
  });
  return kernel;
}

- (instancetype)initWithThreshold:(CGFloat)threshold
                          softness:(CGFloat)softness
                            radius:(CGFloat)radius
                         intensity:(CGFloat)intensity
                         tintColor:(UIColor *)tintColor {
  if (self = [super init]) {
    _threshold = CMClamp(threshold, 0.0f, 1.0f);
    _softness = MAX(softness, 0.01f);
    _radius = MAX(radius, 0.5f);
    _intensity = CMClamp(intensity, 0.0f, 1.0f);
    _tintColor = tintColor ?: [UIColor colorWithRed:1.0f green:0.6f blue:0.4f alpha:1.0f];
  }
  return self;
}

- (CIImage *)applyToImage:(CIImage *)image {
  if (!image || self.intensity <= 0.0f) {
    return image;
  }

  CIColorKernel *kernel = [CMFilmHalationOperation halationKernel];
  if (!kernel) {
    return image;
  }

  CIImage *mask = [kernel applyWithExtent:image.extent
                                arguments:@[ image, @(self.threshold), @(self.softness) ]];
  if (!mask) {
    return image;
  }

  CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
  [blur setValue:mask forKey:kCIInputImageKey];
  [blur setValue:@(self.radius) forKey:kCIInputRadiusKey];
  CIImage *blurred = blur.outputImage ?: mask;
  CIImage *croppedBlur = [blurred imageByCroppingToRect:image.extent];

  CIColor *tint = [[CIColor alloc] initWithColor:self.tintColor];
  CIFilter *tintFilter = [CIFilter filterWithName:@"CIColorMatrix"];
  [tintFilter setValue:croppedBlur forKey:kCIInputImageKey];
  [tintFilter setValue:[CIVector vectorWithX:tint.red * self.intensity Y:0 Z:0 W:0]
                forKey:@"inputRVector"];
  [tintFilter setValue:[CIVector vectorWithX:0 Y:tint.green * self.intensity Z:0 W:0]
                forKey:@"inputGVector"];
  [tintFilter setValue:[CIVector vectorWithX:0 Y:0 Z:tint.blue * self.intensity W:0]
                forKey:@"inputBVector"];
  [tintFilter setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:self.intensity]
                forKey:@"inputAVector"];
  CIImage *halationColor = tintFilter.outputImage ?: croppedBlur;

  CIFilter *screen = [CIFilter filterWithName:@"CIScreenBlendMode"];
  [screen setValue:halationColor forKey:kCIInputImageKey];
  [screen setValue:image forKey:kCIInputBackgroundImageKey];
  CIImage *blended = screen.outputImage ?: image;

  return blended;
}

@end

#pragma mark - CMFilmVignetteOperation

@interface CMFilmVignetteOperation ()
@property(nonatomic, assign) CGFloat intensity;
@property(nonatomic, assign) CGFloat radius;
@property(nonatomic, assign) CGPoint center;
@end

@implementation CMFilmVignetteOperation

- (instancetype)initWithIntensity:(CGFloat)intensity
                            radius:(CGFloat)radius
                            center:(CGPoint)center {
  if (self = [super init]) {
    _intensity = CMClamp(intensity, 0.0f, 1.0f);
    _radius = CMClamp(radius, 0.0f, 1.5f);
    _center = center;
  }
  return self;
}

- (CIImage *)applyToImage:(CIImage *)image {
  if (!image || self.intensity <= 0.0f) {
    return image;
  }

  CGRect extent = image.extent;
  CGFloat minDimension = MIN(extent.size.width, extent.size.height);
  CGPoint absoluteCenter = CGPointMake(extent.origin.x + extent.size.width * self.center.x,
                                       extent.origin.y + extent.size.height * self.center.y);

  CIFilter *vignette = [CIFilter filterWithName:@"CIVignetteEffect"];
  [vignette setValue:image forKey:kCIInputImageKey];
  [vignette setValue:[CIVector vectorWithX:absoluteCenter.x Y:absoluteCenter.y]
              forKey:@"inputCenter"];
  [vignette setValue:@(self.intensity * 2.0f) forKey:kCIInputIntensityKey];
  [vignette setValue:@(minDimension * MAX(self.radius, 0.01f)) forKey:kCIInputRadiusKey];
  CIImage *output = vignette.outputImage ?: image;
  return output;
}

@end

NS_ASSUME_NONNULL_END
