//
//  KSDicomDecoder.m
//  DicomViewer
//
//  Created by LuoZhaohui on 11/11/11.
//  Copyright 2011 kesalin@gmail.com. All rights reserved.
//

#import "KSDicomDecoder.h"

const int AE = 0x4145,
AS = 0x4153,
AT = 0x4154,
CS = 0x4353,
DA = 0x4441,
DS = 0x4453,
DT = 0x4454,
FD = 0x4644,
FL = 0x464C,
IS = 0x4953,
LO = 0x4C4F,
LT = 0x4C54,
PN = 0x504E,
SH = 0x5348,
SL = 0x534C,
SS = 0x5353,
ST = 0x5354,
TM = 0x544D,
UI = 0x5549,
UL = 0x554C,
US = 0x5553,
UT = 0x5554,
OB = 0x4F42,
OW = 0x4F57,
SQ = 0x5351,
UN = 0x554E,
QQ = 0x3F3F;

const int IMPLICIT_VR               = 0x2D2D; // '--'
const int ID_OFFSET                 = 128;  //location of "DICM"

#define ITEM                        @"FFFEE000"
#define ITEM_DELIMITATION           @"FFFEE00D"
#define SEQUENCE_DELIMITATION       @"FFFEE0DD"
#define DICM                        @"DICM"

@interface KSDicomDecoder(PrivateMethods)

- (BOOL) readFileInfo;
- (void) readPixels;

- (NSString *) getString:(NSInteger)length;
- (Byte) getByte;
- (ushort) getShort;
- (int) getInt;
- (double) getDouble;
- (float) getFloat;
- (BOOL) getLut:(NSInteger) length buffer:(Byte *)buf;
- (NSInteger) getLength;

- (int) getNextTag;
- (NSString *) getHeaderInfo:(int)tag withValue:(NSString *)value;
- (void) addinfo:(NSInteger) tag withIntValue:(NSInteger)value;
- (void) addInfo:(NSInteger) tag withStringValue:(NSString *)value;
- (void) getSpatialScale:(NSString *) scale;

@end

@implementation KSDicomDecoder

@synthesize bitDepth, width, height, offset, nImages, samplesPerPixel;
@synthesize pixelDepth, pixelWidth, pixelHeight, windowWidth, windowCenter;
@synthesize dicomFound, dicomFileReadSuccess, compressedImage, dicomDir, signedImage;

- (id) init
{
    self = [super init];
    if (self)
    {
        width           = 1;
        height          = 1;
        offset          = 1;
        nImages         = 1;
        samplesPerPixel = 1;
        
        pixelDepth      = 1.0;
        pixelWidth      = 1.0;
        pixelHeight     = 1.0;
        
        littleEndian    = TRUE;
        
        min8            = CHAR_MIN; // 0
        min16           = SHRT_MIN; // -32768;
        
        dict            = [[KSDicomDictionary alloc] init];
        dicomInfoDict   = [[NSMutableDictionary alloc] init];
        
        dicomFileName   = [[NSString alloc] initWithString:@""];
    }
    
    return self;
}

- (void) dealloc
{
    SAFE_FREE(reds);
    SAFE_FREE(blues);
    SAFE_FREE(greens);
    
    SAFE_FREE(pixels16);
    SAFE_FREE(pixels24);
    SAFE_FREE(pixels8);

    [dicomData release];
    [dict release];
    [dicomInfoDict release];
    
    [dicomFileName release];
    
    [super dealloc];
}

- (void) setDicomFilename:(NSString *)filename
{
    if (NSStringIsNilOrEmpty(filename))
    {
        DLog(@" >> Error: Invalid argument! filename is nil or empty!");
        return;
    }
    
    if ([dicomFileName isEqualToString:filename])
    {
        DLog(@" >> Warning: %@ has been setuped before.", filename);
        return;
    }
    
    [dicomFileName release];
    dicomFileName = [filename copy];
    
    [dicomData release];
    dicomData = [[NSData alloc] initWithContentsOfFile:dicomFileName];
    
    if ([dicomData length] == 0) {
        DLog(@" >> Error: Failed to load file %@", filename);
        return;
    }
    
    DLog(@" >> Info: setup Dicom file %@", filename);
    
    dicomFileReadSuccess    = NO;
    signedImage             = NO;
    dicomDir                = NO;
    
    location                = 0;
    windowCenter            = 0;
    windowWidth             = 0;

    [dicomInfoDict removeAllObjects];
    
    BOOL result = [self readFileInfo];
    if (result)
    {
        DLog(@" >> Info: Succeed to read file data %@", filename);
        
        [self readPixels];
    
        dicomFileReadSuccess = YES;
    }
    else
    {
        DLog(@" >> Info: Failed to read file data %@", filename);
        
        dicomFileReadSuccess = NO;
    }
    
}

- (Byte *) getPixels8
{
    return pixels8;
}

- (ushort *) getPixels16
{
    return pixels16;
}

- (Byte *) getPixels24
{
    return pixels24;
}

#pragma mark -
#pragma mark Read data fuction

- (NSString *) getString:(NSInteger)length
{
    char *buf = (char *)calloc((length + 1), sizeof(char));
    NSRange range;
    range.location = location;
    range.length = length;
    
    [dicomData getBytes:buf range:range];
    location += length;

    NSString *retValue = [[NSString alloc] initWithCString:buf encoding:NSUTF8StringEncoding];
    SAFE_FREE(buf);

    return [retValue autorelease];
}

- (Byte) getByte
{
    Byte b = 0;
    const NSInteger length = 1;
    NSRange range;
    range.location = location;
    range.length = length;
    
    [dicomData getBytes:&b range:range];
    location += length;
    
    return b;
}

- (ushort) getShort
{
    Byte b[2];
    const NSInteger length = 2;
    NSRange range;
    range.location = location;
    range.length = length;
    
    [dicomData getBytes:b range:range];
    location += length;
    
    ushort retValue = 0;
    if (littleEndian)
        retValue = (ushort)((b[1] << 8) + b[0]);
    else
        retValue = (ushort)((b[0] << 8) + b[1]);
    
    return retValue;
}

- (int) getInt
{
    Byte b[4];
    const NSInteger length = 4;
    NSRange range;
    range.location = location;
    range.length = length;
    
    [dicomData getBytes:b range:range];
    location += length;
    
    int retValue = 0;
    if (littleEndian)
        retValue = ((b[3] << 24) + (b[2] << 16) + (b[1] << 8) + b[0]);
    else
        retValue = ((b[0] << 24) + (b[1] << 16) + (b[2] << 8) + b[3]);
    
    return retValue;
}

- (double) getDouble
{
    Byte b[8];
    const NSInteger length = 8;
    
    NSRange range;
    range.location = location;
    range.length = length;
    
    [dicomData getBytes:b range:range];
    location += length;
    
    double retValue = 0;
    if (littleEndian)
    {
        long long high = (b[7] << 24) + (b[6] << 16) + (b[5] << 8) + b[4];
        long long low = (b[3] << 24) + (b[2] << 16) + (b[1] << 8) + b[0];
        
        retValue = (high << 32) + low;

    }
    else {
        long long high = (b[4] << 24) + (b[5] << 16) + (b[6] << 8) + b[7];
        long long low = (b[0] << 24) + (b[1] << 16) + (b[2] << 8) + b[3];
        
        retValue = (high << 32) + low;
    }
    
    return retValue;
}

- (float) getFloat
{
    Byte b[4];
    const NSInteger length = 4;
    NSRange range;
    range.location = location;
    range.length = length;
    
    [dicomData getBytes:b range:range];
    location += length;
    
    int retValue = 0;
    if (littleEndian)
        retValue = ((b[3] << 24) + (b[2] << 16) + (b[1] << 8) + (int)b[0]);
    else
        retValue = (int)((b[0] << 24) + (b[1] << 16) + (b[2] << 8) + (int)b[3]);
    
    return (float)retValue;
}

- (BOOL) getLut:(NSInteger)length buffer:(Byte *)buf
{
    if ((length & 1) != 0) {
        //NSString *dummy = [self getString:length];
        location += length;
        return NO;
    }
    
    length = length/2;
    for (NSInteger i = 0; i < length; ++i) {
        buf[i] = (Byte)([self getShort] >> 8);
    }
    
    return YES;
}

- (NSInteger) getLength
{
    // Get 4 bytes
    //
    Byte b[4];
    const NSInteger length = 4;
    NSRange range;
    range.location = location;
    range.length = length;
    
    [dicomData getBytes:b range:range];
    location += length;
    
    // Cannot know whether the VR is implicit or explicit without the 
    // complete Dicom Data Dictionary. 
    //
    vr = (b[0] << 8) + b[1];
    
    NSInteger retValue = 0;
    switch (vr)
    {
        case OB:
        case OW:
        case SQ:
        case UN:
        case UT:
            if ((b[2] == 0) || (b[3] == 0))
            {
                // Explicit VR with 32-bit length if other two bytes are zero
                //
                retValue = [self getInt];
            }
            else
            {
                // Implicit VR with 32-bit length
                //
                vr = IMPLICIT_VR;

                if (littleEndian)
                    retValue = ((b[3] << 24) + (b[2] << 16) + (b[1] << 8) + b[0]);
                else
                    retValue = ((b[0] << 24) + (b[1] << 16) + (b[2] << 8) + b[3]);
            }
            
            break;

        case AE:
        case AS:
        case AT:
        case CS:
        case DA:
        case DS:
        case DT:
        case FD:
        case FL:
        case IS:
        case LO:
        case LT:
        case PN:
        case SH:
        case SL:
        case SS:
        case ST:
        case TM:
        case UI:
        case UL:
        case US:
        case QQ:
            // Explicit vr with 16-bit length
            //
            if (littleEndian)
                retValue = ((b[3] << 8) + b[2]);
            else
                retValue = ((b[2] << 8) + b[3]);
            
            break;
            
        default:
            // Implicit VR with 32-bit length...
            //
            vr = IMPLICIT_VR;
            
            if (littleEndian)
                retValue = ((b[3] << 24) + (b[2] << 16) + (b[1] << 8) + b[0]);
            else
                retValue = ((b[0] << 24) + (b[1] << 16) + (b[2] << 8) + b[3]);
            
            break;
    }
    
    return retValue;
}

- (int) getNextTag
{
    int groupWord = [self getShort];
    if (groupWord == 0x0800 && bigEndianTransferSyntax)
    {
        littleEndian = false;
        groupWord = 0x0008;
    }
    
    int elementWord = [self getShort];
    int tag = groupWord << 16 | elementWord;
    
    elementLength = [self getLength];
    
    // Hack to read some GE files
    //
    if (elementLength == 13 && !oddLocations)
        elementLength = 10;
    
    // "Undefined" element length.
    // This is a sort of bracket that encloses a sequence of elements.
    //
    if (elementLength == -1)
    {
        elementLength = 0;
        inSequence = true;
    }
    return tag;
}

- (NSString *)getHeaderInfo:(int)tag withValue:(NSString *)inValue;
{
    NSString *str = [NSString stringWithFormat:@"%08X", tag];
    if ([str isEqualToString:ITEM_DELIMITATION] || [str isEqualToString:SEQUENCE_DELIMITATION])
    {
        inSequence = false;
        return nil;
    }
    
    NSString *tmp = [dict valueForKey:str];
    
    if (tmp)
    {
        if (vr == IMPLICIT_VR)
        {
            const char *cstr = [tmp UTF8String];
            vr = (cstr[0] << 8) + cstr[1];
        }

        tmp = [tmp substringFromIndex:2];
    }

    if ([str isEqualToString:ITEM])
    {
        tmp = (tmp != nil ? tmp : @":null");
        NSString * retValue = [[[NSString alloc] initWithString:tmp] autorelease];
        return retValue ;
    }
    
    if (inValue != nil)
    {
        NSString * retValue = [[[NSString alloc] initWithFormat:@"%@: %@", tmp, inValue] autorelease];
        return retValue;
    }
    
    NSString *value = nil;
    BOOL privateTag = NO;

    switch (vr)
    {
        case FD:
            for (int i = 0; i < elementLength; ++i)
                [self getByte];
            break;

        case FL:
            for (int i = 0; i < elementLength; i++)
                [self getByte];
            break;
    
        case AE:
        case AS:
        case AT:
        case CS:
        case DA:
        case DS:
        case DT:
        case IS:
        case LO:
        case LT:
        case PN:
        case SH:
        case ST:
        case TM:
        case UI:
            
            value = [self getString:elementLength];
            break;
            
        case US:
            if (elementLength == 2)
            {
                ushort s = [self getShort];
                value = [NSString stringWithFormat:@"%d", s];
            }
            else
            {
                value = @"";
                int n = elementLength / 2;
                for (int i = 0; i < n; i++)
                {
                    ushort s = [self getShort];
                    value = [NSString stringWithFormat:@"%@%d ", value, s];
                }
            }

            break;
            
        case IMPLICIT_VR:
            value = [self getString:elementLength];
            if (elementLength > 44)
                value = nil;
            
            break;
    
        case SQ:
            value = @"";
            privateTag = (((tag >> 16) & 1) != 0);
            if (tag != ICON_IMAGE_SEQUENCE && !privateTag)
                break;
            
            location += elementLength;
            break;

        default:
            location += elementLength;
            value = @"";
            break;
    }
    
    if (!NSStringIsNilOrEmpty(value) && tmp == nil)
    {
        NSString *retValue = [[[NSString alloc] initWithFormat:@"---: %@", value] autorelease];
        return retValue;
    }
    
    else if (tmp == nil)
    {
        return nil;
    }
     
    NSString *retValue = [[[NSString alloc] initWithFormat:@"%@: %@", tmp, value] autorelease];
    return retValue;
}

- (void) addInfo:(NSInteger) tag withStringValue:(NSString *)value
{
    NSString *info = [self getHeaderInfo:tag withValue:value];
    //DLog(@"     info: %@", info);
    
    NSString *str = [NSString stringWithFormat:@"%X", tag];
    NSString *strInfo = nil;;
    if (inSequence && info != nil && vr != SQ)
    {
        info = [NSString stringWithFormat:@">%@", info];
    }
    
    if (info != nil && ![str isEqualToString:ITEM])
    {
        NSRange range = [info rangeOfString:@"---"];
        if (range.location != NSNotFound)
            strInfo = [info stringByReplacingOccurrencesOfString:@"---" withString:@"Private Tag"];
        else
            strInfo = info;

        //DLog(@" >> 0X%08x - %@", tag, strInfo);
        [dicomInfoDict setObject:strInfo forKey:[NSNumber numberWithInteger:tag]];
    }
}

- (void) addInfo:(NSInteger) tag withIntValue:(NSInteger)value
{
    NSString *str = [NSString stringWithFormat:@"%d", value];
    [self addInfo:tag withStringValue:str];
}

- (NSString *)infoFor:(NSInteger) tag
{
    NSNumber * numTag = [NSNumber numberWithInteger:tag];
    NSString * info = [dicomInfoDict objectForKey:numTag];
    if (NSStringIsNilOrEmpty(info))
        return @"";

    NSRange range = [info rangeOfString:@":"];
    if (range.location == NSNotFound) {
        return [[info retain] autorelease];
    }
    
    NSString * retValue = [info substringFromIndex:(range.location + 1)];
    if (NSStringIsNilOrEmpty(retValue))
        return @"";
    
    retValue = [retValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [[retValue retain] autorelease];
}

- (void) getSpatialScale:(NSString *) scale
{
    double xscale = 0, yscale = 0;
    NSRange range = [scale rangeOfString:@"\\"];
    int i = range.location;
    if (i > 0)
    {
        NSString *ystr = [scale substringToIndex:i];
        NSString *xstr = [scale substringFromIndex:(i + 1)];
        yscale = [ystr doubleValue];
        xscale = [xstr doubleValue];
    }
    
    if (xscale != 0.0 && yscale != 0.0)
    {
        pixelWidth = xscale;
        pixelHeight = yscale;
    }
}

- (BOOL)readFileInfo
{
    bitDepth = 16;
    compressedImage = NO;
    
    location += ID_OFFSET;
    
    NSString *fileMark = [self getString:4];
    if (![fileMark isEqualToString:DICM])
    {
        // Return gracefully indicating that this is not a DICOM file
        //
        dicomFound = NO;
        return NO;
    }
    else
    {
        dicomFound = YES;
    }
    
    samplesPerPixel = 1;
    
    BOOL decodingTags = YES;
    int planarConfiguration = 0;
    NSString *modality = nil;
    
    while (decodingTags)
    {
        int tag = [self getNextTag];
        if ((location & 1) != 0)
            oddLocations = YES;
        
        if (inSequence)
        {   
            [self addInfo:tag withStringValue:nil];                     
            continue;
        }
        
        NSString *s = nil;
        switch (tag)
        {
            case TRANSFER_SYNTAX_UID:
                {
                    s = [self getString:elementLength];
                    [self addInfo:tag withStringValue:s];
                    
                    NSRange r1 = [s rangeOfString:@"1.2.4"];
                    NSRange r2 = [s rangeOfString:@"1.2.5"];  
                    if (r1.location != NSNotFound || r2.location != NSNotFound)
                    {
                        compressedImage = YES;
                        // Return gracefully indicating that this type of 
                        // Transfer Syntax cannot be handled
                        //
                        return NO;
                    }
                    
                    r1 = [s rangeOfString:@"1.2.840.10008.1.2.2"];
                    if (r1.location != NSNotFound)
                        bigEndianTransferSyntax = true;
                }
            break;

            case  MODALITY:  // 8 Aug 2010
                modality = [self getString:elementLength];
                [self addInfo:tag withStringValue:modality];
                break;

            case (NUMBER_OF_FRAMES):
                {
                    s = [self getString:elementLength];
                    [self addInfo:tag withStringValue:s];
                    
                    double frames = [s doubleValue]; // s2d(s);
                    if (frames > 1.0)
                        nImages = (int)frames;
                }
            break;
                
            case (SAMPLES_PER_PIXEL):
                samplesPerPixel = [self getShort];
                [self addInfo:tag withIntValue:samplesPerPixel];
                break;
                
            case (PHOTOMETRIC_INTERPRETATION):
                s = [self getString:elementLength];
                [self addInfo:tag withStringValue:s];
                break;
                
            case (PLANAR_CONFIGURATION):
                planarConfiguration = [self getShort];
                [self addInfo:tag withIntValue:planarConfiguration];
                break;
                
            case (ROWS):
                height = [self getShort];
                [self addInfo:tag withIntValue:height];
                break;
                
            case (COLUMNS):
                width = [self getShort];
                [self addInfo:tag withIntValue:width];
                break;
                
            case (PIXEL_SPACING):
                {
                    NSString *scale = [self getString:elementLength];
                    [self getSpatialScale:scale];
                    [self addInfo:tag withStringValue:scale];
                }
                break;
                
            case (SLICE_THICKNESS):
            case (SLICE_SPACING):
                {
                    NSString *spacing = [self getString:elementLength];
                    pixelDepth = [spacing doubleValue];
                    [self addInfo:tag withStringValue:spacing];
                }
                break;
                
            case (BITS_ALLOCATED):
                bitDepth = [self getShort];
                [self addInfo:tag withIntValue:bitDepth];
                break;
                
            case PIXEL_REPRESENTATION:
                pixelRepresentation = [self getShort];
                [self addInfo:tag withIntValue:pixelRepresentation];
                break;
                
            case (WINDOW_CENTER):
                {
                    NSString *center = [self getString:elementLength];
                    NSRange range = [center rangeOfString:@"\\"];
                    int index = range.location;
                    if (index != NSNotFound)
                        center = [center substringFromIndex:index + 1];
                    
                    windowCenter = [center doubleValue];
                    [self addInfo:tag withStringValue:center];
                }
                break;
                
            case (WINDOW_WIDTH):
                {
                    NSString *widthS = [self getString:elementLength];
                    NSRange range = [widthS rangeOfString:@"\\"];
                    int index = range.location;
                    if (index != NSNotFound)
                        widthS = [widthS substringFromIndex:index + 1];
                    
                    windowWidth = [widthS doubleValue];
                    [self addInfo:tag withStringValue:widthS];
                }
                break;
                
            case (RESCALE_INTERCEPT):
                {
                    NSString *intercept = [self getString:elementLength];
                    rescaleIntercept = [intercept doubleValue];
                    [self addInfo:tag withStringValue:intercept];
                }
                break;
                
            case (RESCALE_SLOPE): 
                {
                    NSString *slop = [self getString:elementLength];
                    rescaleSlope = [slop doubleValue];
                    [self addInfo:tag withStringValue:slop];
                }
                break;
                
            case (RED_PALETTE):
                {
                    reds = (Byte *)calloc(elementLength, sizeof(Byte));
                    BOOL succeed = [self getLut:elementLength buffer:reds];
                    if (succeed) {
                        [self addInfo:tag withIntValue:(elementLength/2)];
                    }
                    else {
                        SAFE_FREE(reds);
                    }
                }
                break;
            
            case (GREEN_PALETTE):
                {
                    greens = (Byte *)calloc(elementLength, sizeof(Byte));
                    BOOL succeed = [self getLut:elementLength buffer:greens];
                    if (succeed) {
                        [self addInfo:tag withIntValue:(elementLength/2)];
                    }
                    else {
                        SAFE_FREE(greens);
                    }
                }
                break;
    
            case (BLUE_PALETTE):
                {
                    blues = (Byte *)calloc(elementLength, sizeof(Byte));
                    BOOL succeed = [self getLut:elementLength buffer:blues];
                    if (succeed) {
                        [self addInfo:tag withIntValue:(elementLength/2)];
                    }
                    else {
                        SAFE_FREE(blues);
                    }
                }
                break;

            case (PIXEL_DATA):
                // Start of image data...
                //
                if (elementLength != 0)
                {
                    offset = location;
                    [self addInfo:tag withIntValue:location];
                    decodingTags = false;
                }
                else {
                    [self addInfo:tag withStringValue:nil];
                }
                break;
                
            default:
                [self addInfo:tag withStringValue:nil];
                break;
        }
    }
    
    return YES;
}

- (short) convertToShort:(Byte *)bytes
{
    short value = (short)((bytes[0]) + (bytes[1] << 8));
    return value;
}

- (void) readPixels
{
    SAFE_FREE(pixels16);
    SAFE_FREE(pixels24);
    SAFE_FREE(pixels8);
    
    if (samplesPerPixel == 1 && bitDepth == 8)
    {
        NSInteger numPixels = width * height;
        pixels8 = (Byte *)calloc(numPixels, sizeof(Byte));

        NSRange range;
        range.location = offset;
        range.length = numPixels;
        [dicomData getBytes:pixels8 range:range];
    }
    
    if (samplesPerPixel == 1 && bitDepth == 16)
    {
        NSInteger numPixels = width * height;
        pixels16 = (ushort *)calloc(numPixels, sizeof(ushort));
        
        NSInteger numBytes = numPixels * 2;
        Byte *buf = (Byte *)calloc(numBytes, sizeof(Byte));
        NSRange range;
        range.location = offset;
        range.length = numBytes;
        [dicomData getBytes:buf range:range];
        
        NSInteger j = 0;
        ushort u1 = 0, u2 = 0;
        Byte b0 = 0, b1 = 0;
        Byte signedData[2];
        
        for (NSInteger i = 0; i < numPixels; ++i)
        {
            j   = (i << 1);
            b0  = buf[j];
            b1  = buf[j + 1];
            u2  = (b1 << 8) + b0;
            
            if (pixelRepresentation == 0)   // Unsigned
            {
                signedImage = NO;
                u1 = u2;
            }
            else                            // Pixel representation is 1, indicating a 2s complement image
            {
                signedImage     = YES;
                signedData[0]   = b0;
                signedData[1]   = b1;
                
                short s8 = [self convertToShort:signedData];
                int s4 = s8 - min16;
                u1 = (ushort)(s4);
            }

            pixels16[i] = u1;
        }
        
        SAFE_FREE(buf);
    }
    
    // 30 July 2010 - to account for Ultrasound images
    if (samplesPerPixel == 3 && bitDepth == 8)
    {
        signedImage = NO;

        NSInteger numBytes = width * height * 3;
        pixels24 = (Byte *)calloc(numBytes, sizeof(Byte));
        
        NSRange range;
        range.location = offset;
        range.length = numBytes;
        [dicomData getBytes:pixels24 range:range];
    }
}

@end
