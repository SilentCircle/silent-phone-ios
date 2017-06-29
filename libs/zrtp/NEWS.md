## GNU ZRTP 4.6.4 ##

Some fixes to slience Windows C/C++ compiler, fix a few include
statements when using openSSL, small fixes to check disclosure
flag. Reset valid flags when adding a new cache record to avoid
wrong security message. 


## GNU ZRTP 4.6.3 ##

A small fix inside the ZRTP main module to ignore malformed
DH1 packets and avoid an NULL pointer access. 


## GNU ZRTP 4.6.2 ##

A small fix in the ZrtpCWrapper to fix an issue within 4.6.1
;-)


## GNU ZRTP 4.6.1 ##

A small fix in the ZrtpCWrapper to initialize and use the ZRTP 
master instance in case of multi-stream usage. Does not affect
the main ZRTP usage, only projects that use the wrapper such
as PJSIP or Gstreamer projects.

These project should re-compile if they use the multi-stream
feature.


## GNU ZRTP 4.6.0 ##

Only a small add-on to the code to implement handling of the
disclosure flag. See RFC6189, chapter 11 for more details
about the disclosure flag.

Because the API changed, thus it's necessary to recompile 
applications that use the new library version.


## GNU ZRTP 4.5.0 ##

Added a new SAS algorithm 'B32E' that uses 32 Unicode Emoji
code points instead of 32 ASCII characters. Application that
are able to display Emojis may use this new SAS algorithm to
display nice Emojis instead of 'boring' ASCII letters and
digits.

Some technical details:

* the 32 selected emojis are easily distinguishable, known to
  everyone, not offending etc, and use standard Unicode code
  points
* select colored emojis that look good on white and on black
  backgrounds (most emojis look good on white only)
* select emojis that are available on iOS, Android, Mac OS X
  (Windows not checked)
* the resulting SAS string is UTF-8 encoded, suitable for most
  platforms except Java.

To use the codes for Java the application needs to translate the
UTF-8 encoding into UTF-16 encoding. Because most of the emojis
are Unicode supplementary characters the UTF-8 to UTF-16 conversion
must generate the necessary UTF-16 surrogate pairs.

To support the UTF-8 / UTF-16 conversion the common directory
contains conversion functions that I extracted from ICU C/C++
library source.

Because the API changed, thus it's necessary to recompile 
applications that use the new library version.


## GNU ZRTP 4.4.0 ##

Changes the handling of HMAC and Hash contexts to avoid too
many malloc/free calls and thus memory pointer problems.

Enhance the handling an check the nonce when using multi-stream
mode. This required a modification to the class file and some
modifications on the API. The old functions are now deprecated
but still usable. Nevertheless you should change your application
to use the new fuctions which support the new nonce handling and
checks.

Some bug fixing as well.

Because the API changed, thus it's necessary to recompile 
applications that use the new library version.


## GNU ZRTP 4.3.1 ##

This is a bugfix release. It fixes several compiler issues in
iOS8 Clang, Mircosoft C++ compiler (VS 2012) etc. 

This release also adds a fix to address a possible problem when
using 'memset(...)' on a memory area immediately followed by a
'free(...)' call to free this memory area. Some compilers may
otpimize the code and do not call 'memset(...)'. That's bad for
software that deals with secure keys :-) . The fix removes this
possible vulnerability.


## GNU ZRTP 4.3.0 ##

This version adds some new API that provide to set retry timer 
values and to get some retry counters.

Application may now set some values of the retry counters during 
the discovery (Hello) and the negotiation phase. Applications may
increase the number of retries or modify the capping to support 
slow or bad networks.

To get some idea about the actual number of retries during ZRTP
negotiation an application may now use the new API to get an array
of counters. The ZRTP state engine records how many retries occured
during the different protocol states. 

Note: only the ZRTP initiator performs packet retries after the
discovery (Hello) phase. The responder would always return zero
alues for the other retry counters.

Because we have a new set of functions the API changed, thus it's
necessary to recompile applications that use the new library version.


## GNU ZRTP 4.2.4 ##

Only small changes to enable Android X86 (see clients/tivi/android)
as an example.

Rename functions aes_init() to aes_init_zrtp() to avoid names clashes
with other libraries that may include own AES modules.


## GNU ZRTP 4.2.3 ##

The optional SAS relay feature (refer to RFC6189, chapter 7.3) is
not longer compiled by default. If your project needs this support 
then modify the CMakeLists.txt file and uncomment a 'add_definition'
statements. See comment in the CMakelists.txt file.

The reasons to disable this optional feature in the default build:
it's rarely used and some concerns about misusing this feature.


## GNU ZRTP 4.2.2 ##

A small enhancement in SRTP handling to provide a longer bit-shift 
register with 128 bits. The replay check now accepts packets which
are up to 127 sequence number behind the current packet. The upper
layer (codecs) gets more packets on slower/bad networks that we may
see on mobile 3G/4G connections.

If the codecs do not remove silence then this may lead to some longer
audio replay, similar to satellite communication.


## GNU ZRTP 4.2.1 ##

Bug fixes in the SRTP part that checks for replay and updates the ROC.

The wrong computations lead to false replay indications and to wrong
HMAC, thus they dropped to much packets, in particular under bad network
conditions.

Changed the handling the the zrtp_getSasType function the the ZrtpCWrapper.
Please check the inline documentation and the compiler warning how to
use the return value of the function.


## GNU ZRTP 4.2.0 ##

Implemented a new function to read the ZID file if the ZID file backend
is SQlite3. This is not a security problem because the ZRTP cache was 
always public and readable, refer to RFC6189.

SQL statement returns all ZID records, sorted by date, newest on top. The 
function can then step thru the DB cursor and read the records.

The version also include several fixes, usually compiler warnings, some
small problems reported by 'cppcheck' analyser.

Because we have a new set of functions the API changed, thus it's necessary
to recompile applications that use the new library version.


## GNU ZRTP 4.1.2 ##

Fix the library's name in libzrtpcpp.pc.make

## GNU ZRTP 4.1.1 ##

Is a bug fix release that fixes some problems when building a standalone
version of the library, i.e. with embedded crypto algorithms and not using
on openSSL.

Another fix was necessary for NetBSD thread handling.


## GNU ZRTP 4.1.0 ##

Small enhancements when dealing with non-NIST algorithms. An application may
set a ''algorithm selection policy'' to control the selection behaviour. In
addition the the standrad selection policy (as per RFC6189) this version
provides a _non-NIST_ selection policy: if the selected public key algorithm
is a non-NIST ECC algorithm then the other selection functions prefer non-NIST
HASH algorithms (Skein etc).


## GNU ZRTP 4.0.0 ##

For this version I added some new algorithms for the DH key agreement
and the Skein Hash for ZRTP. Not further functional enhancements.

Added a new (old) build parameter -DCORE_LIB that will build a ZRTP core
library. This was available in V2.3 but I somehow lost this for 3.0
You may add other build parameters, such as SQLITE and CRYPTO_STANDALONE
if you build the core library.


## GNU ZRTP 3.2.0 ##

The main ZRTP modules contain fixes for three vulnerabilities found by Mark
Dowd. Thus we advise application developers to use this version of the
library. The vulnerabilities may lead to application crashes during ZRTP
negotiation if an attacker sends prepared ZRTP packets. The fixes remove these
attack vectors.

Some small other enhancements and cleanup, mainly inside client code.

Some enhancements in cache handling and the handling of retained shared
secrets. This change was proposed by Phil, is a slight security enhancement and
is fully backward compatible.

Because of some API changes clients must be compiled and linked with the new
library.

For details please refer to the Git logs.


## GNU ZRTP 3.1.0 ##

This version adds some new features and code that supports some other
client and this accounts for the most changes inside this release. 

The ZRTP core functionality was not changed as much (bug fixes, cleanup
mainly) and remains fully backward compatible with older library
versions. However, one nice enhancement was done: the addition of a standalone
SDES support module. This module supports basic SDES only without the fancy
stuff like many other SDES implementations. Thus it's pretty interoperable.

Some other features are:

* add some android support for a client, may serve as template for others
* documentation and code cleanup

Because of some API changes clients must be compiled and linked with the new
library.


## GNU ZRTP 3.0.0 ##

This is a major enhancement and restructuring of the overall ZRTP
distribution. This was necessary because more and more other clients use ZRTP
and add their specific glue code. Also some clients are not prepared to use
openSSL or other crypto libraries to their code and distributions. 

Here a summary of the changes

* a new directory layout to accommodate various clients
* add standalone crypto modules, for example for AES, to have a real
  standalone ZRTP/SRTP library that does not require any other crypto library
  (optional via CMake configuration)
* Re-structure ZRTP cache and add SQlite3 as optional storage backend

The default settings for CMake build the normal ZRTP library that use openSSL
as crypto backend, use the normal file based cache and include the GNU ccRTP
modules. This is a librray that is to a large degree compatible with the
earlier builds.

Please refer to the top level CMakeFile.txt for options how to switch on the
standalone crypto mode or the SQlite3 based cache storage.


## GNU ZRTP 2.3.0 ##

Add a "paranoid" mode to ZRTP. If and applications switches to this mode then
the ZRTP stack _always_ asks the user to confirm the SAS thus ZRTP behaves as
if it does not have a cache to store the retained secrets. However, setting
the paranoid mode does not disable the cache, only the GUI behaviour.

Enhance the CMake scripts to build a ZRTP library that does not contain GNU
ccRTP modules and does not require ccRTP dependencies.

## GNU ZRTP 2.2.0 ##

Add stubs, callbacks and other provisions to prepare the full implementation
of the SAS signing feature, see RFC6189, section 7.2. This feature needs
support from applications and is rarely used if at all.

As usual smaller fixes, code clean up etc.

Because of some API changes clients must be compiled and linked with the new
library.

## GNU ZRTP 2.1.2 ##

The main topic of this release was to add SRTCP support and some missing
optional features of ZRTP. 

As such I've added some new API and classes that applications may use to add
SRTCP or to use the new ZRTP features. the ZRTP stack now supports PBX
handling, refer to RFC6189 section 7.3ff.

Because of some API changes clients must be compiled and linked with the new
library.

## GNU ZRTP 2.0.0 ##

Modify some files to use the new uCommon/commoncpp libraries instead
of the GNU CC++ commoncpp2. This affects the ccRTP depended modules
such as ZrtpQueue and the Timeout stuff.

Updated to version 2.0.0 to be in synch with the ccRTP version number
scheme.


## GNU ZRTP 1.6.0 ##

This version implements the Elliptic Curve Diffie-Helman (ECDH) 
public-key algorithm. 

ZRTP also supports new algorithms which are defined as optional
in the ZRTP RFC. These are:

* Skein Hash
* Skein MAC for authentication
* Twofish symmetric ciphers

Twofish ciphers and Skein MAC are supported by GNU ccRTP SRTP 
implementation as well.


## GNU ZRTP 1.5.4 ##

The changes in this release affect the ZRTP Configure mechanism only.
Some housekeeping stuff (destructors) was added and the C Wrapper
how support ZRTP configure as well.

Because of some API changes (added destructors) clients must be compiled 
and linked with the new library.


## GNU ZRTP 1.5.2 ##

Quite a lot of enhancements:

* a CMake based build process was added
* a C wrapper was added to enable C programs to use GNU ZRTP
* some fixes in the code (race condition solved)
* better support of multi-stream mode
* change the old cxx file extension to cpp, some build system don't
  like the old cxx (Android NDK for example)
* and much more

Because of API changes clients must be compiled and linked with the new 
library.


## GNU ZRTP 1.5.0 ##

Adds a first version of a ZrtpConfigure class that provides applications
to select which crypto and hash methods to use.

Because of API changes clients must be compiled and linked with the new 
library.


## GNU ZRTP 1.4.5 ##

Modify the Hello repeat timer handling to accommodate slow connections and/or
slow devices. 

Fix a problem when the other party sends only ZRTP packets at the beginning
of a RTP session.


### Interface changes in 1.4.5 ###

No external interfaces were changed, external API and ABI remain stable.
Internal interface modifications only to implement Ping/PingAck handling.


## GNU ZRTP 1.4.4 ##

Implement the Ping/PingAck packets and associated protocol extensions
as defined in [RFC6189][].

### Interface changes in 1.4.4 ###

No external interfaces were changed, external API and ABI remain stable.
Internal interface modifications only to implement Ping/PingAck handling.


## GNU ZRTP 1.4.2 ##

Introduce the Key Derivation Function (KDF) as defined in [RFC6189][]

The ZRTP protocol version was updated to 1.10.

### Interface changes in 1.4.2 ###

No interfaces were changed, API and ABI remain stable.


## GNU ZRTP 1.4.0 ##

This is the first release that conforms to the ZRTP specification
that eventually will become a [RFC6189][]. 

The ZRTP protocol version was updated to 1.00.

[RFC6189]: https://tools.ietf.org/html/rfc6189

### Interface changes in 1.4.0 ###

The ZrtpQueue and ZRtp classes implement a new method to get the other
party's ZID (ZRTP identifier). An application, for example a SIP or XMPP
client, may use this method to get the other party's ZID and store it
together in a contact list. This enable the application to check the ZID
if the user calls the other party again. A client shall implement such
a feature to enhance security if user's don't compare the SAS on every
call after they confirmed a SAS once.

Clients must be compiled and linked with the new library.


## GNU ZRTP 1.3.1 ##

This is an update to version 1.3.0 and implements the ZRTP multi-stream
mode handshake. The ZRTP protocl version was updated to 0.90 and
interoperability tests using the latest Zfone build and Zfone Beta
(dated September 6, 2008) were successful.

No changes in the external API and ABI with respect to 1.3.0 - thus no
recompile or rebuild of clients are necessary if they use 1.3.0.

To checkout version 1.3.1 specify revision 494 (-r 494).


## GNU ZRTP 1.3.0 ##

This version is and update to version 1.1.0 an implements the latest
changes define in the ZRTP draft. The changes resulted in an update of the
API, therefore existing applications must be recompiled.

This version of GNU ZRTP is compatible to and was tested to work with
the latest Zfone beta (dated June, 10, see Zfone project site). Only
in one specific error case is a slight incompatibility that will be
fixed with the next Zfone beta. This incompatibility results in a 
severe error information at the client. The error only happens if
someone modified the first retained shared secret entry in the
retained secret cache, for example disk/storage read error. This is
a very unlikely situation.

### Interface changes in Version 1.3.0 ###

The Method ''setSipsSecret(...)'' is no longer available. ZRTP does
not support this additional secret anymore.

The method ''setOtherSecret(...)'' was renamed to ''setPbxSecret(...)''
to reflect the modification in the draft.

The method ''setSrtpsSecret(...)'' was renamed to ''setAuxSecret(...)''
to reflect the modification in the draft.


## GNU ZRTP 1.1.0 ##

GNU ZRTP 1.1.0 implements the basic ZRTP as specificied in the document
''draft-zimmermann-avt-zrtp-06x''. You may access this document at[URL][]

This version of GNU ZRTP does not support the additional featurs of ZRTP
such as Multi-stream mode, Pre-shared mode, PBX enrollment, and SAS
Signature.  However, to keep the external interface as stable as
possible I already implemented stubs for the additional features. Some
later versions may have these features implemented, depending if they
are required by the community.

The current version of GNU ZRTP is compatible and was tested to work
with the latest Zfone beta (dated April, 2nd) (see Zfone project
site).

[URL]: http://zfoneproject.com/zrtp_ietf.html

### Interface changes ###

The ''SymmetricZRTPSession'' implements some new methods to control
ZRTP and its new features. An application usually uses only a few
methods to setup GNU ZRTP. All others are optional and an application
may use them only if it requires a special feature (which are not yet
implemented :-) ).

The ''ZrtpUserCallback'' class was modified as well. From an
application's point of view

 * The methods in ''ZrtpUserCallback'' are not pure virtual anymore
   but just virtual and have a default implementation, usually a
   simple return. An application may extend this class and overwrite
   only those methods it requires.

 * Change of the constructor - remove the queue parameter thus we have
  a very simple standard constructor. This modifcation may requires a
  small change in the application or class that uses or extends
  ''ZrtpUserCallback''.

 * The method showSAS has an additional parameter:

     showSAS(std::string sas, bool verified);

  the verified flag is set to true in SAS is verified, false if not verified.
  This allows a more flexible support to display the SAS even if SAS is
  verified. Formerly ZRTP did not call "showSAS()" if SAS was verified. Now
  ZRTP always calls showSAS and provides the verification information
  explicitly.

* The signature of the following user callback methods was changed:

        showMessage(GnuZrtpCodes::MessageSeverity sev, int32_t subCode)

        zrtpNegotiationFailed(GnuZrtpCodes::MessageSeverity severity,
                                           int32_t subCode)

  The GNU ZRTP core and the ZRTP ccRTP extension do not contain
  message strings anymore. Both use codes to inform an application
  about events, problems or failure. The folder ''demo'' contains a
  small demo program that shows one way how to map the codes to
  strings. Delegating string handling and formating to the application
  simplifies internationalization etc.

Please note: some new callback methods and ''SymmetricZRTPSession''
methods are only stubs in the current version. The real implementation
(filling the stubs with real code) will be done some time later (see
above about unsupported features).

### Header files ###

The new version greatly reduces the number of header files installed
in the include directory. In the new version I decoupled the internal
header files and implementation from the external classes and
interfaces an application requires. Only six header files are
installed in GNU ZRTP's include directory (libzrtpcpp subdirectory in
the usual include paths)

### Demo program ###

The new folder ''demo'' contains a small demo program that shows
various ways how to use GNU ZRTP to setup secure RTP (SRTP) sessions
even without signaling protocols

