/*
Copyright (C) 2016-2017, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
// 
//  AZBase64Transcoder.c

#include "AZBase64Transcoder.h"

#include <math.h>

const UInt8 kBase64EncodeTable[64] = {
	/*  0 */ 'A',	/*  1 */ 'B',	/*  2 */ 'C',	/*  3 */ 'D', 
	/*  4 */ 'E',	/*  5 */ 'F',	/*  6 */ 'G',	/*  7 */ 'H', 
	/*  8 */ 'I',	/*  9 */ 'J',	/* 10 */ 'K',	/* 11 */ 'L', 
	/* 12 */ 'M',	/* 13 */ 'N',	/* 14 */ 'O',	/* 15 */ 'P', 
	/* 16 */ 'Q',	/* 17 */ 'R',	/* 18 */ 'S',	/* 19 */ 'T', 
	/* 20 */ 'U',	/* 21 */ 'V',	/* 22 */ 'W',	/* 23 */ 'X', 
	/* 24 */ 'Y',	/* 25 */ 'Z',	/* 26 */ 'a',	/* 27 */ 'b', 
	/* 28 */ 'c',	/* 29 */ 'd',	/* 30 */ 'e',	/* 31 */ 'f', 
	/* 32 */ 'g',	/* 33 */ 'h',	/* 34 */ 'i',	/* 35 */ 'j', 
	/* 36 */ 'k',	/* 37 */ 'l',	/* 38 */ 'm',	/* 39 */ 'n', 
	/* 40 */ 'o',	/* 41 */ 'p',	/* 42 */ 'q',	/* 43 */ 'r', 
	/* 44 */ 's',	/* 45 */ 't',	/* 46 */ 'u',	/* 47 */ 'v', 
	/* 48 */ 'w',	/* 49 */ 'x',	/* 50 */ 'y',	/* 51 */ 'z', 
	/* 52 */ '0',	/* 53 */ '1',	/* 54 */ '2',	/* 55 */ '3', 
	/* 56 */ '4',	/* 57 */ '5',	/* 58 */ '6',	/* 59 */ '7', 
	/* 60 */ '8',	/* 61 */ '9',	/* 62 */ '+',	/* 63 */ '/'
};

/*
 -1 = Base64 end of data marker.
 -2 = White space (tabs, cr, lf, space)
 -3 = Noise (all non whitespace, non-base64 characters) 
 -4 = Dangerous noise
 -5 = Illegal noise (null byte)
 */

const SInt8 kBase64DecodeTable[128] = {
	/* 0x00 */ -5, 	/* 0x01 */ -3, 	/* 0x02 */ -3, 	/* 0x03 */ -3,
	/* 0x04 */ -3, 	/* 0x05 */ -3, 	/* 0x06 */ -3, 	/* 0x07 */ -3,
	/* 0x08 */ -3, 	/* 0x09 */ -2, 	/* 0x0a */ -2, 	/* 0x0b */ -2,
	/* 0x0c */ -2, 	/* 0x0d */ -2, 	/* 0x0e */ -3, 	/* 0x0f */ -3,
	/* 0x10 */ -3, 	/* 0x11 */ -3, 	/* 0x12 */ -3, 	/* 0x13 */ -3,
	/* 0x14 */ -3, 	/* 0x15 */ -3, 	/* 0x16 */ -3, 	/* 0x17 */ -3,
	/* 0x18 */ -3, 	/* 0x19 */ -3, 	/* 0x1a */ -3, 	/* 0x1b */ -3,
	/* 0x1c */ -3, 	/* 0x1d */ -3, 	/* 0x1e */ -3, 	/* 0x1f */ -3,
	/* ' ' */ -2,	/* '!' */ -3,	/* '"' */ -3,	/* '#' */ -3,
	/* '$' */ -3,	/* '%' */ -3,	/* '&' */ -3,	/* ''' */ -3,
	/* '(' */ -3,	/* ')' */ -3,	/* '*' */ -3,	/* '+' */ 62,
	/* ',' */ -3,	/* '-' */ -3,	/* '.' */ -3,	/* '/' */ 63,
	/* '0' */ 52,	/* '1' */ 53,	/* '2' */ 54,	/* '3' */ 55,
	/* '4' */ 56,	/* '5' */ 57,	/* '6' */ 58,	/* '7' */ 59,
	/* '8' */ 60,	/* '9' */ 61,	/* ':' */ -3,	/* ';' */ -3,
	/* '<' */ -3,	/* '=' */ -1,	/* '>' */ -3,	/* '?' */ -3,
	/* '@' */ -3,	/* 'A' */ 0,	/* 'B' */  1,	/* 'C' */  2,
	/* 'D' */  3,	/* 'E' */  4,	/* 'F' */  5,	/* 'G' */  6,
	/* 'H' */  7,	/* 'I' */  8,	/* 'J' */  9,	/* 'K' */ 10,
	/* 'L' */ 11,	/* 'M' */ 12,	/* 'N' */ 13,	/* 'O' */ 14,
	/* 'P' */ 15,	/* 'Q' */ 16,	/* 'R' */ 17,	/* 'S' */ 18,
	/* 'T' */ 19,	/* 'U' */ 20,	/* 'V' */ 21,	/* 'W' */ 22,
	/* 'X' */ 23,	/* 'Y' */ 24,	/* 'Z' */ 25,	/* '[' */ -3,
	/* '\' */ -3,	/* ']' */ -3,	/* '^' */ -3,	/* '_' */ -3,
	/* '`' */ -3,	/* 'a' */ 26,	/* 'b' */ 27,	/* 'c' */ 28,
	/* 'd' */ 29,	/* 'e' */ 30,	/* 'f' */ 31,	/* 'g' */ 32,
	/* 'h' */ 33,	/* 'i' */ 34,	/* 'j' */ 35,	/* 'k' */ 36,
	/* 'l' */ 37,	/* 'm' */ 38,	/* 'n' */ 39,	/* 'o' */ 40,
	/* 'p' */ 41,	/* 'q' */ 42,	/* 'r' */ 43,	/* 's' */ 44,
	/* 't' */ 45,	/* 'u' */ 46,	/* 'v' */ 47,	/* 'w' */ 48,
	/* 'x' */ 49,	/* 'y' */ 50,	/* 'z' */ 51,	/* '{' */ -3,
	/* '|' */ -3,	/* '}' */ -3,	/* '~' */ -3,	/* 0x7f */ -3
};

const UInt8 kBits_00000011 = 0x03;
const UInt8 kBits_00001111 = 0x0F;
const UInt8 kBits_00110000 = 0x30;
const UInt8 kBits_00111100 = 0x3C;
const UInt8 kBits_00111111 = 0x3F;
const UInt8 kBits_11000000 = 0xC0;
const UInt8 kBits_11110000 = 0xF0;
const UInt8 kBits_11111100 = 0xFC;

size_t EstimateBas64EncodedDataSize(size_t inDataSize)
{
	size_t theEncodedDataSize = (int)ceil(inDataSize / 3.0) * 4;
	theEncodedDataSize = theEncodedDataSize / 72 * 74 + theEncodedDataSize % 72;
	return(theEncodedDataSize);
}

size_t EstimateBas64DecodedDataSize(size_t inDataSize)
{
	size_t theDecodedDataSize = (int)ceil(inDataSize / 4.0) * 3;
	//theDecodedDataSize = theDecodedDataSize / 72 * 74 + theDecodedDataSize % 72;
	return(theDecodedDataSize);
}

bool Base64EncodeData(const void *inInputData, size_t inInputDataSize, char *outOutputData, size_t *ioOutputDataSize, BOOL wrapped)
{
	size_t theEncodedDataSize = EstimateBas64EncodedDataSize(inInputDataSize);
	if (*ioOutputDataSize < theEncodedDataSize)
		return(false);
	*ioOutputDataSize = theEncodedDataSize;
	const UInt8 *theInPtr = (const UInt8 *)inInputData;
	UInt32 theInIndex = 0, theOutIndex = 0;
	for (; theInIndex < (inInputDataSize / 3) * 3; theInIndex += 3)
	{
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex] & kBits_11111100) >> 2];
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex] & kBits_00000011) << 4 | (theInPtr[theInIndex + 1] & kBits_11110000) >> 4];
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex + 1] & kBits_00001111) << 2 | (theInPtr[theInIndex + 2] & kBits_11000000) >> 6];
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex + 2] & kBits_00111111) >> 0];
		if (wrapped && (theOutIndex % 74 == 72))
		{
			outOutputData[theOutIndex++] = '\r';
			outOutputData[theOutIndex++] = '\n';
		}
	}
	const size_t theRemainingBytes = inInputDataSize - theInIndex;
	if (theRemainingBytes == 1)
	{
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex] & kBits_11111100) >> 2];
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex] & kBits_00000011) << 4 | (0 & kBits_11110000) >> 4];
		outOutputData[theOutIndex++] = '=';
		outOutputData[theOutIndex++] = '=';
		if (wrapped && (theOutIndex % 74 == 72))
		{
			outOutputData[theOutIndex++] = '\r';
			outOutputData[theOutIndex++] = '\n';
		}
	}
	else if (theRemainingBytes == 2)
	{
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex] & kBits_11111100) >> 2];
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex] & kBits_00000011) << 4 | (theInPtr[theInIndex + 1] & kBits_11110000) >> 4];
		outOutputData[theOutIndex++] = kBase64EncodeTable[(theInPtr[theInIndex + 1] & kBits_00001111) << 2 | (0 & kBits_11000000) >> 6];
		outOutputData[theOutIndex++] = '=';
		if (wrapped && (theOutIndex % 74 == 72))
		{
			outOutputData[theOutIndex++] = '\r';
			outOutputData[theOutIndex++] = '\n';
		}
	}
	*ioOutputDataSize = theOutIndex;
	return(true);
}

// EA: THE FOLLOWING IS A SIMPLER VERSION THAT WORKS JUST FINE (much easier to understand)
/*
 ** Translation Table as described in RFC1113
 */
static const char cb64[]="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/*
 ** encodeblock
 **
 ** encode 3 8-bit binary bytes as 4 '6-bit' characters
 */
void encodeblock( unsigned char in[3], unsigned char out[4], int len );
void encodeblock( unsigned char in[3], unsigned char out[4], int len )
{
    out[0] = cb64[ in[0] >> 2 ];
    out[1] = cb64[ ((in[0] & 0x03) << 4) | ((in[1] & 0xf0) >> 4) ];
    out[2] = (unsigned char) (len > 1 ? cb64[ ((in[1] & 0x0f) << 2) | ((in[2] & 0xc0) >> 6) ] : '=');
    out[3] = (unsigned char) (len > 2 ? cb64[ in[2] & 0x3f ] : '=');
}

/*
 ** encode
 **
 ** base64 encode a stream adding padding and line breaks as per spec.
 */
BOOL encode( unsigned char * bytesIn, int bytesLength, unsigned char *outBuffer );
BOOL encode( unsigned char * bytesIn, int bytesLength, unsigned char *outBuffer )
{
    unsigned char in[3], out[4];
    int i, len, blocksout = 0;
	
	unsigned char *p = bytesIn, *po = outBuffer, *endP = p+bytesLength+1;
	
	while (p < endP) {
        len = 0;
        for( i = 0; i < 3; i++ ) {
            in[i] = *p++;
			if (p == endP)
				break;
			len++;
        }
        if( len ) {
            encodeblock( in, out, len );
            for( i = 0; i < 4; i++ ) {
				*po++ = out[i];
            }
            blocksout++;
        }
		/*
		 if( blocksout >= (linesize/4) || feof( infile ) ) {
		 if( blocksout ) {
		 fprintf( outfile, "\r\n" );
		 }
		 blocksout = 0;
		 }
		 */
    }
	*po = 0;
	return YES;
}

static const char cd64[]="|$$$}rstuvwxyz{$$$$$$$>?@ABCDEFGHIJKLMNOPQRSTUVW$$$$$$XYZ[\\]^_`abcdefghijklmnopq";

/*
 ** decodeblock
 **
 ** decode 4 '6-bit' characters into 3 8-bit binary bytes
 */
void decodeblock( unsigned char in[4], unsigned char out[3] );
void decodeblock( unsigned char in[4], unsigned char out[3] )
{   
    out[ 0 ] = (unsigned char ) (in[0] << 2 | in[1] >> 4);
    out[ 1 ] = (unsigned char ) (in[1] << 4 | in[2] >> 2);
    out[ 2 ] = (unsigned char ) (((in[2] << 6) & 0xc0) | in[3]);
}

/*
 ** decode
 **
 ** decode a base64 encoded stream discarding padding, line breaks and noise
 */
BOOL decode( unsigned char * bytesIn, int bytesLength, unsigned char *outBuffer, int *outBufferLength );
BOOL decode( unsigned char * bytesIn, int bytesLength, unsigned char *outBuffer, int *outBufferLength )
{
    unsigned char in[4], out[3], v;
    int i, len;
	
	unsigned char *p = bytesIn, *po = outBuffer, *endP = p+bytesLength;
	
	while (p < endP) {
		in[0] = in[1] = in[2] = in[3] = 0;
        for( len = 0, i = 0; i < 4 && (p < endP); i++ ) {
            v = 0;
            while( (p < endP) && v == 0 ) {
                v = (unsigned char) *p++;
                v = (unsigned char) ((v < 43 || v > 122) ? 0 : cd64[ v - 43 ]);
                if( v ) {
                    v = (unsigned char) ((v == '$') ? 0 : v - 61);
                }
            }
            if( p <= endP ) {
                len++;
                if( v ) {
                    in[ i ] = (unsigned char) (v - 1);
                }
            }
            else {
                in[i] = 0;
            }
        }
        if( len ) {			
            decodeblock( in, out );
            for( i = 0; i < len - 1; i++ ) {
                *po++ = out[i];
            }
			//NSLog(@"IN: %d,%d,%d,%d OUT: %02x%02x%02x", in[0], in[1], in[2], in[3], out[0], out[1], out[2]);
        }
    }
	*outBufferLength = (int)(po - outBuffer);
	return YES;
}

NSData *base64DecodeData(NSData *data)
{
	if ( (!data) || (data.length < 1) )
		return nil;
	
	size_t outBufferEstLength = EstimateBas64DecodedDataSize([data length]) + 1;
	
	// this should get freed by NSString!
	char *outBuffer = NSZoneMalloc([data zone], outBufferEstLength);
	if (!outBuffer) {
		NSLog(@"base64 encoder: unable to allocate %ld bytes", outBufferEstLength);
		return nil;
	}	
	
	//NSString *str = nil;
	int outBufferLength = 0;
    //size_t encodedDataLength = outBufferEstLength;
	//if (Base64EncodeData([data bytes], [data length], outBuffer, &encodedDataLength, FALSE)) {
	if (decode((unsigned char *)[data bytes], (int)[data length], (unsigned char *)outBuffer, &outBufferLength)) {
		
		// test the other way
		//Base64EncodeData([data bytes], [data length], outBuffer, &encodedDataLength, FALSE);
		//*(outBuffer+encodedDataLength) = 0x0;
		NSData *result = [NSData dataWithBytes:outBuffer length:outBufferLength];
		NSZoneFree([data zone], outBuffer);
		return result;
	}
	NSZoneFree([data zone], outBuffer);
	return nil;
	/*		
	 str = (NSString *)CFStringCreateWithCStringNoCopy(kCFAllocatorDefault,
	 outBuffer,
	 kCFStringEncodingASCII, 
	 kCFAllocatorMallocZone); // kCFAllocatorNull);
	 if (!str) {
	 NSLog(@"base64 decoder:  failed to create NSString from bytes");
	 NSZoneFree([data zone], outBuffer);
	 return nil;
	 } else {
	 NSLog(@"base64 decoder: decoder %d bytes into %d", [data length], [str length]);
	 }
	 
	 }
	 else {
	 // gotta release it here
	 NSLog(@"base64 decoder:  failed to decoder data");
	 NSZoneFree([data zone], outBuffer);
	 return nil;
	 }
	 
	 return [str autorelease];
	 */
}

NSString *base64EncodeData(NSData *data)
{
	if ( (!data) || (data.length < 1) )
		return nil;
	
	size_t outBufferEstLength = EstimateBas64EncodedDataSize([data length]) + 1;
	
	// this should get freed by NSString!
	char *outBuffer = NSZoneMalloc([data zone], outBufferEstLength);
	if (!outBuffer) {
		NSLog(@"base64 encoder: unable to allocate %ld bytes", outBufferEstLength);
		return nil;
	}	
	
	NSString *str = nil;
    //size_t encodedDataLength = outBufferEstLength;
	//if (Base64EncodeData([data bytes], [data length], outBuffer, &encodedDataLength, FALSE)) {
	if (encode((unsigned char *)[data bytes], (int)[data length], (unsigned char *)outBuffer)) {
		
		// test the other way
		//Base64EncodeData([data bytes], [data length], outBuffer, &encodedDataLength, FALSE);
		//*(outBuffer+encodedDataLength) = 0x0;
		str = (NSString *)CFStringCreateWithCStringNoCopy(kCFAllocatorDefault,
														  outBuffer,
														  kCFStringEncodingASCII, 
														  kCFAllocatorMallocZone); // kCFAllocatorNull);
		if (!str) {
			NSLog(@"base64 encoder:  failed to create NSString from bytes");
			NSZoneFree([data zone], outBuffer);
			return nil;
		} else {
			NSLog(@"base64 encoder: encoded %d bytes into %d", (int)[data length], (int)[str length]);
		}
		
	}
	else {
		// gotta release it here
		NSLog(@"base64 encoder:  failed to encode data");
		NSZoneFree([data zone], outBuffer);
		return nil;
	}
	
	return [str autorelease];
}

NSString *base64EncodeString(NSString *inString)
{
	NSData *stringData = [inString dataUsingEncoding:NSASCIIStringEncoding];
	if (stringData.length < 1)
		return nil;
	size_t outBufferEstLength = EstimateBas64EncodedDataSize([stringData length]) + 1;
	
	// this should get freed by NSString!
	char *outBuffer = NSZoneMalloc([inString zone], outBufferEstLength);
	if (!outBuffer) {
		NSLog(@"base64 encoder: unable to allocate %ld bytes", outBufferEstLength);
		return nil;
	}	
	
	
	NSString *str = nil;
    size_t encodedDataLength = outBufferEstLength;
	if (Base64EncodeData([stringData bytes], [stringData length], outBuffer, &encodedDataLength, FALSE))
	{
		*(outBuffer+encodedDataLength) = 0x0;
		str = (NSString *)CFStringCreateWithCStringNoCopy(kCFAllocatorDefault,
														  outBuffer,
														  kCFStringEncodingASCII, 
														  kCFAllocatorMallocZone); // kCFAllocatorNull);
		if (!str)
		{
			NSLog(@"base64 encoder:  failed to create NSString from bytes");
			NSZoneFree([inString zone], outBuffer);
			return nil;
		}
	}
	else
	{
		// gotta release it here
		NSLog(@"base64 encoder:  failed to encode data");
		NSZoneFree([inString zone], outBuffer);
		return nil;
	}
	
	return [str autorelease];
}

bool Base64DecodeData(const void *inInputData, size_t inInputDataSize, void *ioOutputData, size_t *ioOutputDataSize)
{
	memset(ioOutputData, '.', *ioOutputDataSize);
	
	size_t theDecodedDataSize = EstimateBas64DecodedDataSize(inInputDataSize);
	if (*ioOutputDataSize < theDecodedDataSize)
		return(false);
	*ioOutputDataSize = 0;
	const UInt8 *theInPtr = (const UInt8 *)inInputData;
	UInt8 *theOutPtr = (UInt8 *)ioOutputData;
	size_t theInIndex = 0, theOutIndex = 0;
	UInt8 theOutputOctet = 0;
	size_t theSequence = 0;
	for (; theInIndex < inInputDataSize; )
	{
		SInt8 theSextet = 0;
		
		SInt8 theCurrentInputOctet = theInPtr[theInIndex];
		theSextet = kBase64DecodeTable[theCurrentInputOctet];
		if (theSextet == -1)
			break;
		while (theSextet == -2)
		{
			theCurrentInputOctet = theInPtr[++theInIndex];
			theSextet = kBase64DecodeTable[theCurrentInputOctet];
		}
		while (theSextet == -3)
		{
			theCurrentInputOctet = theInPtr[++theInIndex];
			theSextet = kBase64DecodeTable[theCurrentInputOctet];
		}
		if (theSequence == 0)
		{
			theOutputOctet = (theSextet >= 0 ? theSextet : 0) << 2 & kBits_11111100;
		}
		else if (theSequence == 1)
		{
			theOutputOctet |= (theSextet >- 0 ? theSextet : 0) >> 4 & kBits_00000011;
			theOutPtr[theOutIndex++] = theOutputOctet;
		}
		else if (theSequence == 2)
		{
			theOutputOctet = (theSextet >= 0 ? theSextet : 0) << 4 & kBits_11110000;
		}
		else if (theSequence == 3)
		{
			theOutputOctet |= (theSextet >= 0 ? theSextet : 0) >> 2 & kBits_00001111;
			theOutPtr[theOutIndex++] = theOutputOctet;
		}
		else if (theSequence == 4)
		{
			theOutputOctet = (theSextet >= 0 ? theSextet : 0) << 6 & kBits_11000000;
		}
		else if (theSequence == 5)
		{
			theOutputOctet |= (theSextet >= 0 ? theSextet : 0) >> 0 & kBits_00111111;
			theOutPtr[theOutIndex++] = theOutputOctet;
		}
		theSequence = (theSequence + 1) % 6;
		if (theSequence != 2 && theSequence != 4)
			theInIndex++;
	}
	*ioOutputDataSize = theOutIndex;
	return(true);
}
