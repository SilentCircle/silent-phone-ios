/*
Created by Janis Narbuts
Copyright (C) 2004-2012, Tivi LTD, www.tiviphone.com. All rights reserved.
Copyright (C) 2012-2017, Silent Circle, LLC.  All rights reserved.

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
#include "../baseclasses/CTBase.h"
#include "../baseclasses/CTEditBase.h"
#include "../os/CTiViSock.h"
#include "../os/CTThread.h"
#include "../os/CTTcp.h"
#include "../encrypt/tls/CTTLS.h"
#include "ratchet/../util/cJSON.h"
#include <stdlib.h>
#include "tivi_log.h"

#ifdef ANDROID
void androidLog(const char* format, ...);
#endif

#ifdef _WIN32
#define snprintf _snprintf
#endif

/*
 * Silent Phone uses the following root certificates to setup TLS with the
 * provisioning servers of the production network.
 */
static const char *productionCert=
// Entrust Certificate Authority ‐ L1M (EV SSL)
// Signing Algorithm: SHA256RSA
// entrust_l1m_sha2.cer, serial number: 61:a1:e7:d2:00:00:00:00:51:d3:66:a6
// SHA1 Fingerprint=CC:13:66:95:63:90:65:FA:B4:70:74:D2:8C:55:31:4C:66:07:7E:90
// Valid until: Oct 15 15:55:03 2030 GMT
"-----BEGIN CERTIFICATE-----\r\n"
"MIIFLTCCBBWgAwIBAgIMYaHn0gAAAABR02amMA0GCSqGSIb3DQEBCwUAMIG+MQsw\r\n"
"CQYDVQQGEwJVUzEWMBQGA1UEChMNRW50cnVzdCwgSW5jLjEoMCYGA1UECxMfU2Vl\r\n"
"IHd3dy5lbnRydXN0Lm5ldC9sZWdhbC10ZXJtczE5MDcGA1UECxMwKGMpIDIwMDkg\r\n"
"RW50cnVzdCwgSW5jLiAtIGZvciBhdXRob3JpemVkIHVzZSBvbmx5MTIwMAYDVQQD\r\n"
"EylFbnRydXN0IFJvb3QgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHMjAeFw0x\r\n"
"NDEyMTUxNTI1MDNaFw0zMDEwMTUxNTU1MDNaMIG6MQswCQYDVQQGEwJVUzEWMBQG\r\n"
"A1UEChMNRW50cnVzdCwgSW5jLjEoMCYGA1UECxMfU2VlIHd3dy5lbnRydXN0Lm5l\r\n"
"dC9sZWdhbC10ZXJtczE5MDcGA1UECxMwKGMpIDIwMTQgRW50cnVzdCwgSW5jLiAt\r\n"
"IGZvciBhdXRob3JpemVkIHVzZSBvbmx5MS4wLAYDVQQDEyVFbnRydXN0IENlcnRp\r\n"
"ZmljYXRpb24gQXV0aG9yaXR5IC0gTDFNMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A\r\n"
"MIIBCgKCAQEA0IHBOSPCsdHs91fdVSQ2kSAiSPf8ylIKsKs/M7WwhAf23056sPuY\r\n"
"Ij0BrFb7cW2y7rmgD1J3q5iTvjOK64dex6qwymmPQwhqPyK/MzlG1ZTy4kwFItln\r\n"
"gJHxBEoOm3yiydJs/TwJhL39axSagR3nioPvYRZ1R5gTOw2QFpi/iuInMlOZmcP7\r\n"
"lhw192LtjL1JcdJDQ6Gh4yEqI3CodT2ybEYGYW8YZ+QpfrI8wcVfCR5uRE7sIZlY\r\n"
"FUj0VUgqtzS0BeN8SYwAWN46lsw53GEzVc4qLj/RmWLoquY0djGqr3kplnjLgRSv\r\n"
"adr7BLlZg0SqCU+01CwBnZuUMWstoc/B5QIDAQABo4IBKzCCAScwDgYDVR0PAQH/\r\n"
"BAQDAgEGMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDATASBgNVHRMBAf8E\r\n"
"CDAGAQH/AgEAMDMGCCsGAQUFBwEBBCcwJTAjBggrBgEFBQcwAYYXaHR0cDovL29j\r\n"
"c3AuZW50cnVzdC5uZXQwMAYDVR0fBCkwJzAloCOgIYYfaHR0cDovL2NybC5lbnRy\r\n"
"dXN0Lm5ldC9nMmNhLmNybDA7BgNVHSAENDAyMDAGBFUdIAAwKDAmBggrBgEFBQcC\r\n"
"ARYaaHR0cDovL3d3dy5lbnRydXN0Lm5ldC9ycGEwHQYDVR0OBBYEFMP30LUqMK2v\r\n"
"DZEhcDlU3byJcMc6MB8GA1UdIwQYMBaAFGpyJnrQHu995ztpUdRsjZ+QEmarMA0G\r\n"
"CSqGSIb3DQEBCwUAA4IBAQC0h8eEIhopwKR47PVPG7SEl2937tTPWa+oQ5YvHVje\r\n"
"pvMVWy7ZQ5xMQrkXFxGttLFBx2YMIoYFp7Qi+8VoaIqIMthx1hGOjlJ+Qgld2dnA\r\n"
"DizvRGsf2yS89byxqsGK5Wbb0CTz34mmi/5e0FC6m3UAyQhKS3Q/WFOv9rihbISY\r\n"
"Jnz8/DVRZZgeO2x28JkPxLkJ1YXYJKd/KsLak0tkuHB8VCnTglTVz6WUwzOeTTRn\r\n"
"4Dh2ZgCN0C/GqwmqcvrOLzWJ/MDtBgO334wlV/H77yiI2YIowAQPlIFpI+CRKMVe\r\n"
"1QzX1CA778n4wI+nQc1XRG5sZ2L+hN/nYNjvv9QiHg3n\r\n"
"-----END CERTIFICATE-----\r\n"

// Entrust Root Certificate Authority—G2
// Signing Algorithm: SHA256RSA
// entrust_g2_ca.cer, serial number: 4a 53 8c 28
// SHA1 Fingerprint=8C:F4:27:FD:79:0C:3A:D1:66:06:8D:E8:1E:57:EF:BB:93:22:72:D4
// Valid Until: 12/7/2030
"-----BEGIN CERTIFICATE-----\r\n"
"MIIEPjCCAyagAwIBAgIESlOMKDANBgkqhkiG9w0BAQsFADCBvjELMAkGA1UEBhMC\r\n"
"VVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50\r\n"
"cnVzdC5uZXQvbGVnYWwtdGVybXMxOTA3BgNVBAsTMChjKSAyMDA5IEVudHJ1c3Qs\r\n"
"IEluYy4gLSBmb3IgYXV0aG9yaXplZCB1c2Ugb25seTEyMDAGA1UEAxMpRW50cnVz\r\n"
"dCBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRzIwHhcNMDkwNzA3MTcy\r\n"
"NTU0WhcNMzAxMjA3MTc1NTU0WjCBvjELMAkGA1UEBhMCVVMxFjAUBgNVBAoTDUVu\r\n"
"dHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVnYWwt\r\n"
"dGVybXMxOTA3BgNVBAsTMChjKSAyMDA5IEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0\r\n"
"aG9yaXplZCB1c2Ugb25seTEyMDAGA1UEAxMpRW50cnVzdCBSb290IENlcnRpZmlj\r\n"
"YXRpb24gQXV0aG9yaXR5IC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK\r\n"
"AoIBAQC6hLZy254Ma+KZ6TABp3bqMriVQRrJ2mFOWHLP/vaCeb9zYQYKpSfYs1/T\r\n"
"RU4cctZOMvJyig/3gxnQaoCAAEUesMfnmr8SVycco2gvCoe9amsOXmXzHHfV1IWN\r\n"
"cCG0szLni6LVhjkCsbjSR87kyUnEO6fe+1R9V77w6G7CebI6C1XiUJgWMhNcL3hW\r\n"
"wcKUs/Ja5CeanyTXxuzQmyWC48zCxEXFjJd6BmsqEZ+pCm5IO2/b1BEZQvePB7/1\r\n"
"U1+cPvQXLOZprE4yTGJ36rfo5bs0vBmLrpxR57d+tVOxMyLlbc9wPBr64ptntoP0\r\n"
"jaWvYkxN4FisZDQSA/i2jZRjJKRxAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAP\r\n"
"BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRqciZ60B7vfec7aVHUbI2fkBJmqzAN\r\n"
"BgkqhkiG9w0BAQsFAAOCAQEAeZ8dlsa2eT8ijYfThwMEYGprmi5ZiXMRrEPR9RP/\r\n"
"jTkrwPK9T3CMqS/qF8QLVJ7UG5aYMzyorWKiAHarWWluBh1+xLlEjZivEtRh2woZ\r\n"
"Rkfz6/djwUAFQKXSt/S1mja/qYh2iARVBCuch38aNzx+LaUa2NSJXsq9rD1s2G2v\r\n"
"1fN2D807iDginWyTmsQ9v4IbZT+mD12q/OWyFcq1rca8PdCE6OoGcrBNOTJ4vz4R\r\n"
"nAuknZoh8/CbCzB428Hch0P+vGOaysXCHMnHjf87ElgI5rY97HosTvuDls4MPGmH\r\n"
"VHOkc8KT/1EQrBVUAdj8BbGJoX90g5pJ19xOe4pIb4tF9g==\r\n"
"-----END CERTIFICATE-----\r\n"

// Entrust Root Certificate Authority, serial number 45:6b:50:54, SHA1: B3:1E:B1:B7
// Signing Algorithm: SHA1RSA
// Valid Until: 11/27/2026
// https://www.entrust.com/get-support/ssl-certificate-support/root-certificate-downloads/
"-----BEGIN CERTIFICATE-----\r\n"
"MIIEkTCCA3mgAwIBAgIERWtQVDANBgkqhkiG9w0BAQUFADCBsDELMAkGA1UEBhMC\r\n"
"VVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4xOTA3BgNVBAsTMHd3dy5lbnRydXN0\r\n"
"Lm5ldC9DUFMgaXMgaW5jb3Jwb3JhdGVkIGJ5IHJlZmVyZW5jZTEfMB0GA1UECxMW\r\n"
"KGMpIDIwMDYgRW50cnVzdCwgSW5jLjEtMCsGA1UEAxMkRW50cnVzdCBSb290IENl\r\n"
"cnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTA2MTEyNzIwMjM0MloXDTI2MTEyNzIw\r\n"
"NTM0MlowgbAxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMTkw\r\n"
"NwYDVQQLEzB3d3cuZW50cnVzdC5uZXQvQ1BTIGlzIGluY29ycG9yYXRlZCBieSBy\r\n"
"ZWZlcmVuY2UxHzAdBgNVBAsTFihjKSAyMDA2IEVudHJ1c3QsIEluYy4xLTArBgNV\r\n"
"BAMTJEVudHJ1c3QgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTCCASIwDQYJ\r\n"
"KoZIhvcNAQEBBQADggEPADCCAQoCggEBALaVtkNC+sZtKm9I35RMOVcF7sN5EUFo\r\n"
"Nu3s/poBj6E4KPz3EEZmLk0eGrEaTsbRwJWIsMn/MYszA9u3g3s+IIRe7bJWKKf4\r\n"
"4LlAcTfFy0cOlypowCKVYhXbR9n10Cv/gkvJrT7eTNuQgFA/CYqEAOwwCj0Yzfv9\r\n"
"KlmaI5UXLEWeH25DeW0MXJj+SKfFI0dcXv1u5x609mhF0YaDW6KKjbHjKYD+JXGI\r\n"
"rb68j6xSlkuqUY3kEzEZ6E5Nn9uss2rVvDlUccp6en+Q3X0dgNmBu1kmwhH+5pPi\r\n"
"94DkZfs0Nw4pgHBNrziGLp5/V6+eF67rHMsoIV+2HNjnogQi+dPa2MsCAwEAAaOB\r\n"
"sDCBrTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zArBgNVHRAEJDAi\r\n"
"gA8yMDA2MTEyNzIwMjM0MlqBDzIwMjYxMTI3MjA1MzQyWjAfBgNVHSMEGDAWgBRo\r\n"
"kORnpKZTgMeGZqTx90tD+4S9bTAdBgNVHQ4EFgQUaJDkZ6SmU4DHhmak8fdLQ/uE\r\n"
"vW0wHQYJKoZIhvZ9B0EABBAwDhsIVjcuMTo0LjADAgSQMA0GCSqGSIb3DQEBBQUA\r\n"
"A4IBAQCT1DCw1wMgKtD5Y+iRDAUgqV8ZyntyTtSx29CW+1RaGSwMCPeyvIWonX9t\r\n"
"O1KzKtvn1ISMY/YPyyYBkVBs9F8U4pN0wBOeMDpQ47RgxRzwIkSNcUesyBrJ6Zua\r\n"
"AGAT/3B+XxFNSRuzFVJ7yVTav52Vr2ua2J7p8eRDjeIRRDq/r72DQnNSi6q7pynP\r\n"
"9WQcCk3RvKqsnyrQ/39/2n3qse0wJcGE2jTSW3iDVuycNsMm4hH2Z0kdkquM++v/\r\n"
"eu6FSqdQgPCnXEqULl8FmTxSQeDNtGPPAUO6nIPcj2A781q0tHuu2guQOHXvgR1m\r\n"
"0vdXcDazv/wor3ElhVsT/h5/WrQ8\r\n"
"-----END CERTIFICATE-----\r\n" ;

/*
 * Silent Phone uses the following certificate to setup TLS with the
 * provisioning servers of the development network.
 */
static const char *developmentCert =

// Entrust Root Certificate Authority—G2
// Signing Algorithm: SHA256RSA
// entrust_g2_ca.cer, serial number: 4a 53 8c 28
// SHA1 Fingerprint=8C:F4:27:FD:79:0C:3A:D1:66:06:8D:E8:1E:57:EF:BB:93:22:72:D4
// Valid Until: 12/7/2030
// https://www.entrust.com/get-support/ssl-certificate-support/root-certificate-downloads/
"-----BEGIN CERTIFICATE-----\r\n"
"MIIEPjCCAyagAwIBAgIESlOMKDANBgkqhkiG9w0BAQsFADCBvjELMAkGA1UEBhMC\r\n"
"VVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50\r\n"
"cnVzdC5uZXQvbGVnYWwtdGVybXMxOTA3BgNVBAsTMChjKSAyMDA5IEVudHJ1c3Qs\r\n"
"IEluYy4gLSBmb3IgYXV0aG9yaXplZCB1c2Ugb25seTEyMDAGA1UEAxMpRW50cnVz\r\n"
"dCBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRzIwHhcNMDkwNzA3MTcy\r\n"
"NTU0WhcNMzAxMjA3MTc1NTU0WjCBvjELMAkGA1UEBhMCVVMxFjAUBgNVBAoTDUVu\r\n"
"dHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVnYWwt\r\n"
"dGVybXMxOTA3BgNVBAsTMChjKSAyMDA5IEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0\r\n"
"aG9yaXplZCB1c2Ugb25seTEyMDAGA1UEAxMpRW50cnVzdCBSb290IENlcnRpZmlj\r\n"
"YXRpb24gQXV0aG9yaXR5IC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK\r\n"
"AoIBAQC6hLZy254Ma+KZ6TABp3bqMriVQRrJ2mFOWHLP/vaCeb9zYQYKpSfYs1/T\r\n"
"RU4cctZOMvJyig/3gxnQaoCAAEUesMfnmr8SVycco2gvCoe9amsOXmXzHHfV1IWN\r\n"
"cCG0szLni6LVhjkCsbjSR87kyUnEO6fe+1R9V77w6G7CebI6C1XiUJgWMhNcL3hW\r\n"
"wcKUs/Ja5CeanyTXxuzQmyWC48zCxEXFjJd6BmsqEZ+pCm5IO2/b1BEZQvePB7/1\r\n"
"U1+cPvQXLOZprE4yTGJ36rfo5bs0vBmLrpxR57d+tVOxMyLlbc9wPBr64ptntoP0\r\n"
"jaWvYkxN4FisZDQSA/i2jZRjJKRxAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAP\r\n"
"BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRqciZ60B7vfec7aVHUbI2fkBJmqzAN\r\n"
"BgkqhkiG9w0BAQsFAAOCAQEAeZ8dlsa2eT8ijYfThwMEYGprmi5ZiXMRrEPR9RP/\r\n"
"jTkrwPK9T3CMqS/qF8QLVJ7UG5aYMzyorWKiAHarWWluBh1+xLlEjZivEtRh2woZ\r\n"
"Rkfz6/djwUAFQKXSt/S1mja/qYh2iARVBCuch38aNzx+LaUa2NSJXsq9rD1s2G2v\r\n"
"1fN2D807iDginWyTmsQ9v4IbZT+mD12q/OWyFcq1rca8PdCE6OoGcrBNOTJ4vz4R\r\n"
"nAuknZoh8/CbCzB428Hch0P+vGOaysXCHMnHjf87ElgI5rY97HosTvuDls4MPGmH\r\n"
"VHOkc8KT/1EQrBVUAdj8BbGJoX90g5pJ19xOe4pIb4tF9g==\r\n"
"-----END CERTIFICATE-----\r\n"

// Entrust Root Certificate Authority, serial number 45:6b:50:54
// Signing Algorithm: SHA1RSA
// SHA1 Fingerprint=B3:1E:B1:B7:40:E3:6C:84:02:DA:DC:37:D4:4D:F5:D4:67:49:52:F9
// Valid Until: 11/27/2026
// https://www.entrust.com/get-support/ssl-certificate-support/root-certificate-downloads/
"-----BEGIN CERTIFICATE-----\r\n"
"MIIEkTCCA3mgAwIBAgIERWtQVDANBgkqhkiG9w0BAQUFADCBsDELMAkGA1UEBhMC\r\n"
"VVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4xOTA3BgNVBAsTMHd3dy5lbnRydXN0\r\n"
"Lm5ldC9DUFMgaXMgaW5jb3Jwb3JhdGVkIGJ5IHJlZmVyZW5jZTEfMB0GA1UECxMW\r\n"
"KGMpIDIwMDYgRW50cnVzdCwgSW5jLjEtMCsGA1UEAxMkRW50cnVzdCBSb290IENl\r\n"
"cnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTA2MTEyNzIwMjM0MloXDTI2MTEyNzIw\r\n"
"NTM0MlowgbAxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMTkw\r\n"
"NwYDVQQLEzB3d3cuZW50cnVzdC5uZXQvQ1BTIGlzIGluY29ycG9yYXRlZCBieSBy\r\n"
"ZWZlcmVuY2UxHzAdBgNVBAsTFihjKSAyMDA2IEVudHJ1c3QsIEluYy4xLTArBgNV\r\n"
"BAMTJEVudHJ1c3QgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTCCASIwDQYJ\r\n"
"KoZIhvcNAQEBBQADggEPADCCAQoCggEBALaVtkNC+sZtKm9I35RMOVcF7sN5EUFo\r\n"
"Nu3s/poBj6E4KPz3EEZmLk0eGrEaTsbRwJWIsMn/MYszA9u3g3s+IIRe7bJWKKf4\r\n"
"4LlAcTfFy0cOlypowCKVYhXbR9n10Cv/gkvJrT7eTNuQgFA/CYqEAOwwCj0Yzfv9\r\n"
"KlmaI5UXLEWeH25DeW0MXJj+SKfFI0dcXv1u5x609mhF0YaDW6KKjbHjKYD+JXGI\r\n"
"rb68j6xSlkuqUY3kEzEZ6E5Nn9uss2rVvDlUccp6en+Q3X0dgNmBu1kmwhH+5pPi\r\n"
"94DkZfs0Nw4pgHBNrziGLp5/V6+eF67rHMsoIV+2HNjnogQi+dPa2MsCAwEAAaOB\r\n"
"sDCBrTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zArBgNVHRAEJDAi\r\n"
"gA8yMDA2MTEyNzIwMjM0MlqBDzIwMjYxMTI3MjA1MzQyWjAfBgNVHSMEGDAWgBRo\r\n"
"kORnpKZTgMeGZqTx90tD+4S9bTAdBgNVHQ4EFgQUaJDkZ6SmU4DHhmak8fdLQ/uE\r\n"
"vW0wHQYJKoZIhvZ9B0EABBAwDhsIVjcuMTo0LjADAgSQMA0GCSqGSIb3DQEBBQUA\r\n"
"A4IBAQCT1DCw1wMgKtD5Y+iRDAUgqV8ZyntyTtSx29CW+1RaGSwMCPeyvIWonX9t\r\n"
"O1KzKtvn1ISMY/YPyyYBkVBs9F8U4pN0wBOeMDpQ47RgxRzwIkSNcUesyBrJ6Zua\r\n"
"AGAT/3B+XxFNSRuzFVJ7yVTav52Vr2ua2J7p8eRDjeIRRDq/r72DQnNSi6q7pynP\r\n"
"9WQcCk3RvKqsnyrQ/39/2n3qse0wJcGE2jTSW3iDVuycNsMm4hH2Z0kdkquM++v/\r\n"
"eu6FSqdQgPCnXEqULl8FmTxSQeDNtGPPAUO6nIPcj2A781q0tHuu2guQOHXvgR1m\r\n"
"0vdXcDazv/wor3ElhVsT/h5/WrQ8\r\n"
"-----END CERTIFICATE-----\r\n"

// ISRG Root X1 - Let's Encrypt
// https://letsencrypt.org/certs/isrgrootx1.pem.txt
// Serial number: 82:10:cf:b0:d2:40:e3:59:44:63:e0:bb:63:82:8b:00
// Fingerprint SHA1: CA:BD:2A:79:A1:07:6A:31:F2:1D:25:36:35:CB:03:9D:43:29:A5:E8
// Used for https://sentry.silentcircle.org
//"-----BEGIN CERTIFICATE-----\r\n"
//"MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw\r\n"
//"TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh\r\n"
//"cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4\r\n"
//"WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu\r\n"
//"ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY\r\n"
//"MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc\r\n"
//"h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+\r\n"
//"0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U\r\n"
//"A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW\r\n"
//"T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH\r\n"
//"B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC\r\n"
//"B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv\r\n"
//"KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn\r\n"
//"OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn\r\n"
//"jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw\r\n"
//"qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI\r\n"
//"rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV\r\n"
//"HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq\r\n"
//"hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL\r\n"
//"ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ\r\n"
//"3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK\r\n"
//"NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5\r\n"
//"ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur\r\n"
//"TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC\r\n"
//"jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc\r\n"
//"oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq\r\n"
//"4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA\r\n"
//"mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d\r\n"
//"emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=\r\n"
//"-----END CERTIFICATE-----\r\n"

// IdenTrust DST Root CA X3
// https://www.identrust.com/certificates/trustid/root-download-x3.html
// Serial number: 44:af:b0:80:d6:a3:27:ba:89:30:39:86:2e:f8:40:6b
// Fingerprint SHA1: DA:C9:02:4F:54:D8:F6:DF:94:93:5F:B1:73:26:38:CA:6A:D7:7C:13
// Used for https://sentry.silentcircle.org
"-----BEGIN CERTIFICATE-----\r\n"
"MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/\r\n"
"MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT\r\n"
"DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow\r\n"
"PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD\r\n"
"Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB\r\n"
"AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O\r\n"
"rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq\r\n"
"OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b\r\n"
"xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw\r\n"
"7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD\r\n"
"aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV\r\n"
"HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG\r\n"
"SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69\r\n"
"ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr\r\n"
"AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz\r\n"
"R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5\r\n"
"JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo\r\n"
"Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ\r\n"
"-----END CERTIFICATE-----\r\n"

;

// Default certificate: use the production network
static const char *provisioningCert = productionCert;

/*
 * Silent Phone uses two links: the first to use the production server,
 * the second one to use the development server.
 */
static const char *productionApiLink = "https://sccps.silentcircle.com";
static const char *productionWebLink = "https://accounts.silentcircle.com";
static const char *developmentApiLink = "https://sccps-dev.silentcircle.com";
static const char *developmentWebLink = "https://accounts-dev.silentcircle.com";

// Default link: use the production network
static const char *provisioningApiLink = productionApiLink;
static const char *provisioningWebLink = productionWebLink;

/**
 * @brief Set provisioning link and certificate for use in development network.
 */
void setProvisioningToDevelop() {
    provisioningApiLink = developmentApiLink;
    provisioningWebLink = developmentWebLink;
    provisioningCert = developmentCert;
}

/**
 * @brief Set provisioning link and certificate for use in production network.
 */
void setProvisioningToProduction() {
    provisioningApiLink = productionApiLink;
    provisioningWebLink = productionWebLink;
    provisioningCert = productionCert;
}

/**
* @brief Returns current provisioning server
*/
const char* getCurrentProvSrv()
{
	return provisioningApiLink;
}

/**
* @brief Returns current web server
*/
const char* getCurrentWebSrv()
{
	return provisioningWebLink;
}

int retryConnectProvServ(){
#ifdef _WIN32
   return IDRETRY==::MessageBoxA(NULL,"Could not connect to the server. Check your internet connection and try again.","Info",MB_ICONERROR|MB_RETRYCANCEL);
#else
   return 1;
#endif
}

#ifdef _WIN32
int showSSLErrorMsg(void *ret, const char *p){
   MessageBoxA(NULL,"Server's security certificate validation has failed, phone will exit.","SSL TLS error",MB_ICONERROR|MB_OK);
   exit(1);
   return 0;
}
#else
int showSSLErrorMsg(void *ret, const char *p);
#endif

void tmp_log(const char *p);

static int respF(void *p, int i){

   int *rc=(int*)p;
   *rc=1;

   return 0;
}

void tivi_log(const char* format, ...);


typedef struct{
   void (*cb)(void *p, int ok, const char *pMsg);
   void *ptr;
}SSL_RET;

int showSSLErrorMsg2(void *ret, const char *p){

   SSL_RET *s=(SSL_RET*)ret;
#if defined(_WIN32) || defined(_WIN64)
   //#OZ-299, this part should be off.
   if(!s || !s->cb){
      const char *pErr="Server's security certificate validation has failed, phone will exit.";
      MessageBoxA(NULL,pErr,"SSL TLS error",MB_ICONERROR|MB_OK);
      exit(1);
      return 0;
   }
#endif
   const char *pErr="Server's security certificate validation has failed.";

   if(s){
      s->cb(s->ptr,-2,pErr);
   }
   return 0;
}



static char* download_page2Loc(const char *url, char *buf, int iMaxLen, int &iRespContentLen,
                    void (*cb)(void *p, int ok, const char *pMsg), void *cbRet, const char *pReq="GET", const char *pContent=NULL){

   char bufU[1024];
   char bufA[1024];
   memset(buf,0,iMaxLen);

   //CTSockTcp
   CTTHttp<CTTLS> *s=new CTTHttp<CTTLS>(buf,iMaxLen);
   CTTLS *tls=s->createSock();
#if  defined(__APPLE__) || defined(ANDROID_NDK)
   //TODO getInfo("get.prefLang");
   const char *getPrefLang(void);
   s->setLang(getPrefLang());
#endif
   //const char *getPrefLang()

   int r = s->splitUrl((char*)url, (int)strlen(url), &bufA[0], &bufU[0]);
   if(r < 0) {
      cb(cbRet,-1,"Malformed request.\n(Error Code: 201)"); // Malformed url
      return 0;
   }

   SSL_RET ssl_ret;
   ssl_ret.cb = cb;
   ssl_ret.ptr = cbRet;

   int iLen = (int)strlen(provisioningCert);

   if (iLen > 0) {
       tls->errMsg = &showSSLErrorMsg2;
       tls->pRet = &ssl_ret;

       char bufZ[256];
       int i = 0;
       int iMaxL = sizeof(bufZ)-1;

       for (; i < iMaxL; i++){
           if (bufA[i] == ':' || !bufA[i]) {
               break;
           }
           bufZ[i] = bufA[i];
       }
       bufZ[i] = 0;
       printf("path ptr= %p l= %d addr=[%s]\n", provisioningCert, iLen, &bufZ[0]);
       tls->setCert(const_cast<char *>(provisioningCert), iLen, &bufZ[0]);
   }
   else {
       cb(cbRet,-1,"Malformed request.\n(Error Code: 202)"); // No certificate
       return 0;
   }

   int iRespCode=0;

   CTTHttp<CTTLS>::HTTP_W_TH wt;
   wt.ptr=&iRespCode;
   wt.respFnc=respF;
   s->waitResp(&wt,60);
   cb(cbRet,1,"Downloading...");
   s->getUrl(tls,&bufU[0],&bufA[0],pReq,pContent, pContent?(int)strlen(pContent):0,pContent?"application/json":"");//locks

   iRespContentLen=0;
   char *p=s->getContent(iRespContentLen);

   if(p)cb(cbRet,1,"Downloading ok");

   int c=0;
   while(iRespCode==0){Sleep(100);c++;if(c>600)break;}//wait for waitResp thread


   delete s;
   return p;
}

char* download_page2(const char *url, char *buf, int iMaxLen, int &iRespContentLen,
                     void (*cb)(void *p, int ok, const char *pMsg), void *cbRet) {
   return download_page2Loc(url, buf, iMaxLen, iRespContentLen, cb, cbRet, "GET", NULL);
}

static void dummy_cb(void *p, int ok, const char *pMsg){

}

char* t_post_json(const char *url, char *bufResp, int iMaxLen, int &iRespContentLen, const char *pContent) {

   static int x = 1; //random
   return download_page2Loc(url, bufResp, iMaxLen, iRespContentLen, dummy_cb, &x, "POST", pContent);
}

char* t_send_http_json(const char *url, const char *meth,  char *bufResp, int iMaxLen, int &iRespContentLen, const char *pContent) {
    char bufReq[1024];
    static int x = 2; //random
    snprintf(bufReq, sizeof(bufReq)-10, "%s%s", provisioningApiLink, url);

    return download_page2Loc(bufReq, bufResp, iMaxLen, iRespContentLen, dummy_cb, &x, meth, pContent);
}



//#define PROV_TEST

int findJSonToken(const char *p, int iPLen, const char *key, char *resp, int iMaxLen){

   int iKeyLen=(int)strlen(key);
   resp[0]=0;

   for(int i=0;i<iPLen;i++){
      if(i+iKeyLen+3>iPLen)return -1;
      if(p[i]=='"' && p[i+iKeyLen+1]=='"' && p[i+iKeyLen+2]==':'
         && strncmp(key,&p[i+1],iKeyLen)==0){

         i+=iKeyLen+2;
         while(p[i] && p[i]!='"' && i<iPLen)i++;
         if(i>=iPLen)return -2;
         i++;

         int l=0;
         iMaxLen--;

         while(p[i] && p[i]!='"' && l<iMaxLen && i<iPLen){resp[l]=p[i];i++;l++;}
         if(i>=iPLen)return -2;
         resp[l]=0;

         return l;
      }
   }

   return 0;
}

/*
 * getDomainAuthURL() - Queries the SC server with a user-provided domainname.
 * Returns the authentication URL, typically for an ADFS server, to be loaded
 * into a WebView.
 */

int getDomainAuthURL(const char *pLink,
                     const char *pUsername,
                     char *auth_url, int auth_sz,
                     char *redirect_url, int redirect_sz,
                     char *auth_type, int auth_type_sz,
                     void (*cb)(void *p, int ok, const char *pMsg), void *cbRet)
{
    int iRespContentLen=0;
    char bufResp[4096];
    char *p=NULL;
    char *pUN=NULL;
    int  len=0;

    memset(bufResp, 0, sizeof(bufResp));
    p = download_page2Loc(pLink, bufResp, sizeof(bufResp) - 1, iRespContentLen, cb, cbRet, "GET", NULL);

    cb(cbRet, 1, "JSON from ");
    cb(cbRet, 1, pLink);

    // Failed to download JSON
    if (p == NULL)
    {
        cb(cbRet, 0, "Please check network connection.\n(Error Code: 301)");
        return -4;
    }

    /* FIXME: We should *really* be using a proper JSON library in tiviengine/. */

    /*
    * Example JSON response:
    *
    * {
    *   "auth_type": "adfs",
    *   "can_do_username": true,
    *   "auth_url": "https://ad.lakedaemon.net/adfs/oauth2/authorize?client_id=myclientid3&resource=https://enterprise.silentcircle.com/adfs/trust&response_type=code&redirect_uri=silentcircle-entapi://redirect"
    * }
    */

    /* check auth_type */
    len = findJSonToken(p, iRespContentLen, "auth_type", auth_type, auth_type_sz - 1);

    if(len <= 0)
    {
        // JSON field 'auth_type' not found
       cb(cbRet, -1, "Incomplete sign in, please enter a correct domain.");
       return -3;
    }

    if (strcmp(auth_type, "ADFS") != 0 && strcmp(auth_type, "OIDC") != 0)
    {
        // Server reported unknown auth_type
       cb(cbRet, -1, "Single sign on not supported for this domain.");
       return -2;
    }

    /* get the authentication URL */
    int authuri_len = findJSonToken(p, iRespContentLen, "auth_uri", auth_url, auth_sz - 1);

    /* get the redirect URL */
    int redirecturi_len = findJSonToken(p, iRespContentLen, "redirect_uri", redirect_url, redirect_sz - 1);

    if(authuri_len <= 0 || redirecturi_len < 0)
    {
        // TODO: Return the contents of the 'error' token
        // and if this token does not exist then return the
        // contents of the 'msg' token
        
        // no url
        cb(cbRet, -1, "Malformed response.\n(Error Code: 408)");
        return -1;
    }

    pUN = auth_url + authuri_len;

    return 0;
}

static int getToken(const char *pLink, char *resp, int iMaxLen, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet, const char *pReq="GET", const char *pContent=NULL){

   int iRespContentLen=0;

   char bufResp[4096];

#if 0
   const char *pTest="{\"api_key\": \"z46d3856f8ff292f2eb8dab4e5e51edf5b951fb6e6eb01c80662157z\", \"result\": \"success\"}";

   iRespContentLen=strlen(pTest);
   l=findJSonToken(pTest,iRespContentLen,"api_key",&bufResp[0],1023);
   if(l>0)printf("token=[%.*s]\n",l,bufResp);

   l=findJSonToken(pTest,iRespContentLen,"result",&bufResp[0],4095);
   if(l>0)printf("token=[%.*s]\n",l,bufResp);
   exit(1);
#endif


   memset(bufResp,0,sizeof(bufResp));


   char *p=download_page2Loc(pLink, &bufResp[0], sizeof(bufResp)-50, iRespContentLen,cb,cbRet, pReq, pContent);
    
   if(!p){
       t_logf(log_events, "prov.cpp_getToken() ", "NULL returned from download_page2Loc() (Error Code: 302)");
      cb(cbRet,0,"Please check network connection.\n(Error Code: 302)");//download json fail
      return -1;
   }
#if 1//def PROV_TEST

    //09/08/15 per JC in Messages
    printf("pLink = [%s]\n", pLink);
    printf("pContent = [%s]\n", pContent);
    //------------------------------------

   printf("rec[%.*s]\n",iRespContentLen,p);//rem
   printf("rec-t[%s]\n",bufResp);//rem
#endif

    cJSON* root = cJSON_Parse(p);

    if(!root) {
        
        t_logf(log_events, "prov.cpp_getToken() ", "Bad JSON. (Malformed response. Error Code: 401) -> %s", p);
        
        cb(cbRet, 0, "Malformed response.\n(Error Code: 401)");
        
        cJSON_Delete(root);

        return -1;
    }

    cJSON *result = cJSON_GetObjectItem(root,"result");

    if(!result) {

        t_logf(log_events, "prov.cpp_getToken() ", "No 'result' in JSON. (Malformed response. Error Code: 402) -> %s", p);        
        // Result is not found
        cb(cbRet, 0, "Malformed response.\n(Error Code: 402)");

        cJSON_Delete(root);

        return -1;
    }

    if(strcmp(result->valuestring, "success")) {

        cJSON *error_msg = cJSON_GetObjectItem(root, "error_msg");

        if(error_msg) {

            cJSON *error_code = cJSON_GetObjectItem(root, "error_code");

            int code = -1;

            // If the user is required to enter his two factor authentication code
            if(error_code != NULL && error_code->valueint == 4)
                code = -4;

            t_logf(log_events, "prov.cpp_getToken() ", "Error Code: %i) -> %s", code, error_msg->valuestring);
            cb(cbRet, code, error_msg->valuestring);
        }
        else {
            
            t_logf(log_events, "prov.cpp_getToken() ", "Could not download configuration. (Malformed response. Error Code: 101) -> %s", p);
            cb(cbRet, -1, "Could not download configuration.\n(Error Code: 101)");
        }

        cJSON_Delete(root);

        return -1;
    }

    cJSON *apiKey = cJSON_GetObjectItem(root, "api_key");

    if(!apiKey) {

        t_logf(log_events, "prov.cpp_getToken() ", "API key not found. (Malformed response. Error Code: 403) -> %s", p);        
        // API key not found
        cb(cbRet, 0, "Malformed response.\n(Error Code: 403)");

        cJSON_Delete(root);

        return -1;
    }

    char *apiKeyStr = apiKey->valuestring;

    if(strlen(apiKeyStr) <= 0 || strlen(apiKeyStr) > 256 || strlen(apiKeyStr) > iMaxLen) {

        t_logf(log_events, "prov.cpp_getToken() ", "Find api_key failed. (Malformed response. Error Code: 404) -> %s", p);
        // Find api_key failed
        cb(cbRet, 0, "Malformed response.\n(Error Code: 404)");

        cJSON_Delete(root);

        return -1;
    }

    int ret=snprintf(resp,iMaxLen,"%s", &apiKeyStr[0]);
    resp[iMaxLen]=0;

    cJSON_Delete(root);

#if defined(__APPLE__)
#ifndef PROV_TEST
    int storeProvAPIKey(const char *p);
    storeProvAPIKey(resp);
#endif
#endif

   t_logf(log_events, "prov.cpp_getToken() ", "Success"); 
   return ret;
}

const char *pFN_to_save[]  ={"settings.txt","tivi_cfg10555.xml","tivi_cfg.xml",NULL};
int isFileExistsW(const short *fn);
void setCfgFN(CTEditBase &b, int iIndex);
void setCfgFN(CTEditBase &b, const char *fn);

void delProvFiles(const int *p, int iCnt){
   CTEditBase b(1024);
   for(int i=0;i<2;i++){
      if(!pFN_to_save[i])break;
      setCfgFN(b,pFN_to_save[i]);
      deleteFileW(b.getText());
   }

   char buf[64];

   for(int i=0;i<iCnt;i++){
      printf("del prov %d\n",p[i]);
      if(p[i]==1)continue;//dont delete if created by user
      if(i)snprintf(buf, sizeof(buf)-1, "tivi_cfg%d.xml", i); else strcpy(buf,"tivi_cfg.xml");
      setCfgFN(b,buf);
      deleteFileW(b.getText());
   }
}

static int iProvisioned=-1;//unknown


static char bufAPIKey[1024]="";

const char *getAPIKey(){
#if defined(__APPLE__)

   if(!bufAPIKey[0]){

       const char * getAPIKeyForProv(void);
       const char *k = getAPIKeyForProv();

      if(k && k[0]){
        puts("key-KC ok");
        strncpy(bufAPIKey, k, sizeof(bufAPIKey));
        bufAPIKey[sizeof(bufAPIKey)-1]=0;
      }
      else{
          
          //ET 04/21/16
          printf("prov.cpp getAPIKey() invoked.");
          printf("APIKey not found in NSUserDefaults or keychain.");

          printf("Generate out of bounds crash instead of returning NULL apiKey");
          char wtf[] = {'w','t','f'}; int whuh = 1000;
          printf("WTF?? -> %c", wtf[whuh]);
          
          return NULL;
      }
      return &bufAPIKey[0];
   }

#endif
   return &bufAPIKey[0];
}

int provClearAPIKey(){
   int ret=bufAPIKey[0];
   memset(bufAPIKey, 0, sizeof(bufAPIKey));
   return ret?0:-1;//if we had a key return 0
}

int checkProvWithAPIKey(const char *aAPIKey, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);


int checkProv(const char *pUserCode, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet){
   /*
    http://sccps.silentcircle.com/provisioning/silent_phone/tivi_cfg.xml?api_key=12345
    http://sccps.silentcircle.com/provisioning/silent_phone/settings.txt?api_key=12345
    http://sccps.silentcircle.com/provisioning/silent_phone/tivi_cfg_glob.txt?api_key=12345
    */
   char bufReq[1024];
   extern const char *t_getDevID_md5();
   extern const char *t_getDev_name();

   const char *dev_id=t_getDevID_md5();
   const char *dev_name=t_getDev_name();


#define CHK_BUF \
   if(l+100>sizeof(bufReq)){\
      return -1;\
   }

   int l=snprintf(bufReq, sizeof(bufReq)-10, "%s/provisioning/use_code/?provisioning_code=", provisioningApiLink);

   CHK_BUF

   l+=fixPostEncodingToken(&bufReq[l],sizeof(bufReq)-10-l,pUserCode,(int)strlen(pUserCode));

   CHK_BUF

   l+=snprintf(&bufReq[l],sizeof(bufReq)-10-l,"&device_id=%s&device_name=",dev_id);

   CHK_BUF

   l+=fixPostEncodingToken(&bufReq[l],sizeof(bufReq)-10-l, dev_name,(int)strlen(dev_name));

   CHK_BUF

#undef CHK_BUF


   int r=getToken(&bufReq[0], &bufAPIKey[0],255,cb,cbRet);
   if(r<0){

      return -1;
   }

   cb(cbRet,1,"Configuration code ok");

   return checkProvWithAPIKey(&bufAPIKey[0],cb, cbRet);;
}

static void copyJSON_value(char *dst, const char *src, int iMax){
   iMax--;
   for(int i=0;i<iMax;i++){
      if(!*src)break;
      if(*src=='"' || *src=='\\'){*dst='\\';dst++;i++;}
      *dst=*src;
      dst++;
      src++;
   }
   *dst=0;
}

int checkProvAuthCookie(const char *pUN, const char *auth_code, const char *auth_type, const char *auth_state, const char *pdevID, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet){
   /*
    /v1/me/device/[device_id]/
    http://sccps.silentcircle.com/provisioning/silent_phone/tivi_cfg.xml?api_key=12345
    http://sccps.silentcircle.com/provisioning/silent_phone/settings.txt?api_key=12345
    http://sccps.silentcircle.com/provisioning/silent_phone/tivi_cfg_glob.txt?api_key=12345
    */
   char bufReq[1024];
   char bufContent[4096];
   extern const char *t_getDevID_md5();
   extern const char *t_getDev_name();
   extern const char *t_getVersion();
   const char *dev_id=t_getDevID_md5();
   const char *dev_name=t_getDev_name();

#define CHK_BUF \
if(l+100>sizeof(bufReq)){\
return -1;\
}

   int l=snprintf(bufReq,sizeof(bufReq)-10,"%s/v1/me/device/%s/",provisioningApiLink,dev_id);

   CHK_BUF

#ifdef __APPLE__
   const char *dev_class = "ios";
#endif

#if defined(_WIN32) || defined(_WIN64)
   const char *dev_class = "windows";
#endif

#if defined(ANDROID_NDK)
   const char *dev_class = "android";
#endif

#if defined(__linux__) && !defined(ANDROID_NDK)
   const char *dev_class = "Linux";
#endif

    char locAuthCode[2048];
    char locAuthType[2048];
    char locAuthState[2048];

    char locUN[128];

    copyJSON_value(locAuthCode, auth_code, sizeof(locAuthCode)-1);
    copyJSON_value(locAuthType, auth_type, sizeof(locAuthType)-1);
    copyJSON_value(locAuthState, auth_state, sizeof(locAuthState)-1);
    copyJSON_value(locUN, pUN, sizeof(locUN)-1);

   l = snprintf(bufContent, sizeof(bufContent),
                "{\r\n"
                   "\"username\": \"%s\",\r\n"
                   "\"auth_type\": \"%s\",\r\n"
                   "\"auth_code\": \"%s\",\r\n"
                   "\"state\": \"%s\",\r\n"
                   "\"device_name\": \"%s\",\r\n"
#if defined (_WIN32) || defined(_WIN64)
				   "\"app\": \"silent_phone_free\",\r\n"
#else
				   "\"app\": \"silent_phone\",\r\n"
#endif
                 "\"persistent_device_id\": \"%s\",\r\n"
                   "\"device_class\": \"%s\",\r\n"
                   "\"version\": \"%s\"\r\n"
                "}\r\n", locUN, locAuthType, locAuthCode, locAuthState, dev_name, pdevID, dev_class, t_getVersion());

#undef CHK_BUF

    // 09/08/15 for logging per JC in Messages
    cb(cbRet,1,bufContent);

   int r=getToken(&bufReq[0], &bufAPIKey[0],255,cb,cbRet,"PUT",bufContent);
   if(r<0){
      return -1;
   }

   cb(cbRet,1,"Configuration code ok");

   return checkProvWithAPIKey(&bufAPIKey[0],cb, cbRet);;
}

int checkProvUserPass(const char *pUN, const char *pPWD, const char *pTFA, const char *pdevID, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet){
   /*
    /v1/me/device/[device_id]/
    http://sccps.silentcircle.com/provisioning/silent_phone/tivi_cfg.xml?api_key=12345
    http://sccps.silentcircle.com/provisioning/silent_phone/settings.txt?api_key=12345
    http://sccps.silentcircle.com/provisioning/silent_phone/tivi_cfg_glob.txt?api_key=12345
    */
   char bufReq[1024];
//   char bufContent[1024];
   extern const char *t_getDevID_md5();
   extern const char *t_getDev_name();
   extern const char *t_getVersion();
   const char *dev_id=t_getDevID_md5();
   const char *dev_name=t_getDev_name();


#define CHK_BUF \
if(l+100>sizeof(bufReq)){\
return -1;\
}

   int l=snprintf(bufReq,sizeof(bufReq)-10,"%s/v1/me/device/%s/?enable_tfa=1",provisioningApiLink,dev_id);

   CHK_BUF

#ifdef __APPLE__
   const char *dev_class = "ios";
#endif

#if defined(_WIN32) || defined(_WIN64)
   const char *dev_class = "windows";
#endif

#if defined(ANDROID_NDK)
   const char *dev_class = "android";
#endif

#if defined(__linux__) && !defined(ANDROID_NDK)
   const char *dev_class = "Linux";
#endif

   char locPassword[128];
   copyJSON_value(locPassword, pPWD, sizeof(locPassword)-1);
   char locUN[128];
   copyJSON_value(locUN, pUN, sizeof(locUN)-1);

    cJSON *root;
    root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "username", locUN);
    cJSON_AddStringToObject(root, "password", pPWD);//locPassword);//TODO encode pwd
    cJSON_AddStringToObject(root, "device_name", dev_name);
#if defined (_WIN32) || defined(_WIN64)
    cJSON_AddStringToObject(root, "app", "silent_phone_free");
#else
    cJSON_AddStringToObject(root, "app", "silent_phone");
#endif
    cJSON_AddStringToObject(root, "persistent_device_id", pdevID);
    cJSON_AddStringToObject(root, "device_class", dev_class);
    cJSON_AddStringToObject(root, "version", t_getVersion());

    if(pTFA != NULL)
        cJSON_AddStringToObject(root, "tfa_code", pTFA);

   char * rendered = cJSON_Print(root);

    cJSON_Delete(root);

   CHK_BUF

#undef CHK_BUF


   int r=getToken(&bufReq[0], &bufAPIKey[0],255,cb,cbRet,"PUT",rendered);

    free(rendered);

   if(r<0){
      return -1;
   }

   cb(cbRet,1,"Configuration code ok");

   return checkProvWithAPIKey(&bufAPIKey[0],cb, cbRet);;
}

static int t_addJSON(int canTrim, char *pos, int iSize, const char *tag, const char *value){

   char bufJSonValue[1024];
   copyJSON_value(bufJSonValue, value, sizeof(bufJSonValue)-1);

   if(canTrim)trim(bufJSonValue);

   if(!bufJSonValue[0] || iSize < 120 || strlen(value) > 80)return 0;

   return snprintf(pos, iSize, "\"%s\":\"%s\",", tag, bufJSonValue);
}

int createUserOnWeb(const char *pUN, const char *pPWD,
                    const char *pEM, const char *pFN, const char *pLN,
                    void (*cb)(void *p, int ok, const char *pMsg), void *cbRet){

   int c, l = 0;
   int iRespContentLen=0;

   char bufResp[4096];
   char bufBody[4096];



   char url[1024];
   int ul = snprintf(url,sizeof(url)-10,"%s/v1/user/",provisioningApiLink);

   ul+=fixPostEncodingToken(&url[ul],sizeof(url)-10-ul,pUN,(int)strlen(pUN));
   url[ul] = '/'; ul++; url[ul]=0;

   bufBody[0]='{';l = 1;

   c = t_addJSON(1, &bufBody[l], sizeof(bufBody)-l, "username", pUN);
   if(!c){
      cb(cbRet,0,"Please check Username field.");
      return -1;
   }
   l+=c;

   c = t_addJSON(0 , &bufBody[l], sizeof(bufBody)-l, "password", pPWD);
   if(!c){
      cb(cbRet,0,"Please check Password field.");
      return -1;
   }
   l+=c;

   c = t_addJSON(1 , &bufBody[l], sizeof(bufBody)-l, "email", pEM);
   if(!c){
      cb(cbRet,0,"Please check Email field.");
      return -1;
   }
   l+=c;

   c = t_addJSON(1 , &bufBody[l], sizeof(bufBody)-l, "first_name", pFN); l+=c;
   c = t_addJSON(1 , &bufBody[l], sizeof(bufBody)-l, "last_name", pLN); l+=c;

   bufBody[l - 1] = '}';//remove last , from JSON

   memset(bufResp,0,sizeof(bufResp));

   char *p=download_page2Loc(url, &bufResp[0], sizeof(bufResp)-50, iRespContentLen,cb,cbRet, "PUT", bufBody);

   if(!p){
      cb(cbRet,0,"Please check network connection.\n(Error Code: 303)");//download json fail
      return -1;
   }
#ifdef PROV_TEST
   printf("rec[%.*s]\n",iRespContentLen,p);//rem
   printf("rec-t[%s]\n",bufResp);//rem
#endif

   /*
    {"last_name": "N", "hash": "7c4219a8bcdbfe71aaa7381a72c0b57d3471ee39", "keys": [], "active_st_device": null, "country_code": "", "silent_text": true, "subscription": {"expires": "1900-01-01T00:00:00Z", "has_expired": true}, "first_name": "J", "display_name": "J N", "avatar_url": null, "silent_phone": false, "force_password_change": false, "permissions": {"can_send_media": true, "silent_text": true, "can_receive_voicemail": false, "silent_desktop": false, "silent_phone": false, "conference_create"
    */

   char bufJSonValue[1024];
   l=findJSonToken(p,iRespContentLen,"result",&bufJSonValue[0],1023);
   if(l<=0){
      cb(cbRet,0,"Malformed response.\n(Error Code: 405)");
      return -1;
   }
   if(strcmp(&bufJSonValue[0],"success")){
      l=findJSonToken(p,iRespContentLen,"error_msg",&bufJSonValue[0],1023);
      if(l>0)
         cb(cbRet,-1,&bufJSonValue[0]);
      else{
         cb(cbRet,-1,"Could not download configuration.\n(Error Code: 102)");
      }
      return -1;
   }

   void saveCfgFile(const char *fn, void *p, int iLen);
   saveCfgFile("userData.json", bufResp, iRespContentLen);

   return 0;
}

int checkUserCreate(const char *pUN, const char *pPWD, const char *pdevID,
                    const char *pEM, const char *pFN, const char *pLN,
                    void (*cb)(void *p, int ok, const char *pMsg), void *cbRet){

   int r = createUserOnWeb(pUN, pPWD, pEM, pFN, pLN, cb, cbRet);
   if(r < 0)return r;

   return checkProvUserPass(pUN, pPWD, NULL, pdevID, cb, cbRet);
}

int checkProvWithAPIKey(const char *pAPIKey, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet){


   char bufReq[1024];
   char bufCfg[4096];

   const char *pFN_to_download[]   = {"settings.txt","tivi_cfg_glob.txt","tivi_cfg.xml",NULL};

//   const char *pFNErr[]={"D-Err1","D-Err2","D-Err3","D-Err4","D-Err5","D-Err6",NULL};

   const char *p10_200ok="HTTP/1.0 200 OK";
   const char *p11_200ok="HTTP/1.1 200 OK";

   int iLen200ok=(int)strlen(p10_200ok);

   int iCfgPos=0;

   for(int i=0;;i++){
      if(!pFN_to_download[i] || !pFN_to_save[i])break;
      snprintf(bufReq,sizeof(bufReq)-1,"%s/provisioning/silent_phone/%s?api_key=%s",provisioningApiLink,pFN_to_download[i],pAPIKey);
#ifdef ANDROID
      androidLog("++++ Provisioning request: %s", bufReq);
#endif
      int iRespContentLen=0;
      char* p=download_page2(&bufReq[0], &bufCfg[0], sizeof(bufCfg)-100, iRespContentLen,cb,cbRet);
      if(!p && i>2){
         // we have 1 account
         break;
      }

      if(!p || (strncmp(&bufCfg[0],p10_200ok,iLen200ok) && strncmp(&bufCfg[0],p11_200ok,iLen200ok))){
         if(i>2){
            // we have 1 account
            break;
         }
         char b[1000]; snprintf(b, sizeof(b), "Cannot load: %s, code: %.*s", pFN_to_download[i], 990, bufCfg);
        cb(cbRet,0, b);
//         cb(cbRet,0,pFNErr[i]);
         return -2;
      }
      cb(cbRet,1,pFN_to_save[i]);

      void saveCfgFile(const char *fn, void *p, int iLen);
      int saveCfgFile(int iNextPosToTest, void *p, int iLen);
#if 0
#ifndef PROV_TEST
      saveCfgFile(pFN_to_save[i],p,iRespContentLen);
#endif

      printf("Saving %s content=[%.*s]\n",pFN_to_save[i], iRespContentLen,p);
#else

      if(strncmp("tivi_cfg", pFN_to_save[i],8) || 0==strcmp("tivi_cfg_glob.txt", pFN_to_download[i])){
#ifndef PROV_TEST
         saveCfgFile(pFN_to_save[i],p,iRespContentLen);
#endif

       //  printf("Saving %s content=[%.*s]\n",pFN_to_save[i], iRespContentLen,p);
      }
      else{
         iCfgPos=saveCfgFile(iCfgPos, p,iRespContentLen);
         //printf("Saving pos=%d content=[%.*s]\n",iCfgPos-1, iRespContentLen,p);
      }

#endif
   }
   cb(cbRet,1,"OK");
   iProvisioned=1;
   return 0;
}

void setFileBackgroundReadable(CTEditBase &b);
void setOwnerAccessOnly(const short *fn);

int saveCfgFile(int iNextPosToTest, void *p, int iLen){

   char fn[64];
   CTEditBase b(1024);
#define MAX_CFG_FILES 10000

   for(int i=iNextPosToTest;i<MAX_CFG_FILES;i++){
      if(i)snprintf(fn, sizeof(fn)-1, "tivi_cfg%d.xml", i); else strcpy(fn,"tivi_cfg.xml");
      setCfgFN(b, fn);
      if(!isFileExistsW(b.getText())){
         //save into i pos
         iNextPosToTest=i+1;
         break;
      }
   }

   saveFileW(b.getText(),p,iLen);
   setOwnerAccessOnly(b.getText());
   setFileBackgroundReadable(b);

   return iNextPosToTest;
}



void saveCfgFile(const char *fn, void *p, int iLen){

   CTEditBase b(1024);
   setCfgFN(b,fn);
   saveFileW(b.getText(),p,iLen);

   setOwnerAccessOnly(b.getText());
   setFileBackgroundReadable(b);
}
void tivi_log1(const char *p, int val);

int isProvisioned(int iCheckNow){

#ifdef PROV_TEST
   return 0;
#endif

   if(iProvisioned!=-1 && !iCheckNow)return iProvisioned;

   CTEditBase b(1024);

//   setCfgFN(b,0);

   do{
      iProvisioned=0;
      /*
      if(isFileExistsW(b.getText())){
         iProvisioned=1;
         break;
      }
      */
      extern int getGCfgFileID();
      setCfgFN(b,getGCfgFileID());
      if(isFileExistsW(b.getText())){
         setCfgFN(b,0);
         if(isFileExistsW(b.getText())){
            iProvisioned=1;
            break;
         }
         setCfgFN(b,1);
         if(isFileExistsW(b.getText())){
            iProvisioned=1;
            break;
         }
         break;
      }

      tivi_log1("isProvisioned fail ",getGCfgFileID());

   }while(0);
   //int isFileExists(const char *fn);
   return iProvisioned;
}

//-----------------android-------------------

class CTProvNoCallBack{
   int iSteps;
public:
   int iHasData;
   int iProvStat;
   int okCode;
   char bufMsg[256];


   CTProvNoCallBack(){
      reset();
   }
   void setSteps(int i){iSteps=i;}
   void reset(){

      memset(bufMsg, 0, sizeof(bufMsg));
      iHasData=0;
      okCode=0;
      iProvStat=0;

   }
   void provCallBack(void *p, int ok, const char *pMsg){

      //if(pMsg)tmp_log(pMsg);
      if(ok<=0){
         if(okCode<ok)return;
         okCode=ok;
         strncpy(bufMsg,pMsg,sizeof(bufMsg)-2);
         bufMsg[sizeof(bufMsg)-1]=0;

      }
      else{
         if(!iSteps)iSteps=14;
         iProvStat++;
         int res=iProvStat*100/iSteps;
         if(res>100)res=100;
         sprintf(bufMsg,"%d %% done",res);
         //progress
      }
      iHasData++;
   }
   const char *getInfo(){
      iHasData=0;
      return &bufMsg[0];
   }

};

CTProvNoCallBack provNCB;

static void provCallBack(void *p, int ok, const char *pMsg){
   provNCB.provCallBack(p, ok, pMsg);
}

const char* getProvNoCallBackResp(){
   return provNCB.getInfo();
}
//prov.tryGetResult
//porv.start=code
int checkProvNoCallBack(const char *pUserCode){
   provNCB.reset();
   provNCB.setSteps(14);
   return checkProv(pUserCode, provCallBack, &provNCB);
}

int checkProvAPIKeyNoCallBack(const char *pApiKey){
   provNCB.reset();
   provNCB.setSteps(11);
   return checkProvWithAPIKey(pApiKey, provCallBack, &provNCB);
}
