//
//  KSDicomDictionary.h
//  DicomViewer
//
//  Created by LuoZhaohui on 11/17/11.
//  Copyright 2011 LuoZhaohui. All rights reserved.
//  Contact:    kesalin@gmail.com
//              http://blog.csdn.net/kesalin
//
// DicomDecoder is provided by LuoZhaohui on an "AS IS" basis. LuoZhaohui MAKES NO
// WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
// WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
// COMBINATION WITH YOUR PRODUCTS. 
//

#ifndef __DICOM_DICTIONARY_H__
#define __DICOM_DICTIONARY_H__

#import <Foundation/Foundation.h>

@interface KSDicomDictionary : NSObject
{
    NSDictionary *dictionary;
}

+ (id) sharedInstance;

- (NSString *) valueForKey:(NSString *)key;

@end

#endif //__DICOM_DICTIONARY_H__