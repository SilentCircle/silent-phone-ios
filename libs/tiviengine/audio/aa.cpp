/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Initial Developer of the Original Code is
 * CSIRO
 * Portions created by the Initial Developer are Copyright (C) 2007
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s): Michael Martin
 *                 Michael Wu <mwu@mozilla.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** *
 */

#include <stdlib.h>
#include <time.h>
#include <jni.h>
#include "sydney_audio.h"

#include "android/log.h"

#ifndef ALOG
#if defined(DEBUG) || defined(FORCE_ALOG)
#define ALOG(args...)  __android_log_print(ANDROID_LOG_INFO, "Gecko - SYDNEY_AUDIO" , ## args)
#else
#define ALOG(args...)
#endif
#endif

/* Android implementation based on sydney_audio_mac.c */

#define NANOSECONDS_IN_MILLISECOND 1000000
#define MILLISECONDS_PER_SECOND    1000

/* android.media.AudioTrack */
struct AudioTrack {
  jclass    class;
  jmethodID constructor;
  jmethodID flush;
  jmethodID pause;
  jmethodID play;
  jmethodID setvol;
  jmethodID stop;
  jmethodID write;
  jmethodID getpos;
};

enum AudioTrackMode {
  MODE_STATIC = 0,
  MODE_STREAM = 1
};

/* android.media.AudioManager */
enum AudioManagerStream {
  STREAM_VOICE_CALL = 0,
  STREAM_SYSTEM = 1,
  STREAM_RING = 2,
  STREAM_MUSIC = 3,
  STREAM_ALARM = 4,
  STREAM_NOTIFICATION = 5,
  STREAM_DTMF = 8
};

/* android.media.AudioFormat */
enum AudioFormatChannel {
  CHANNEL_OUT_MONO = 4,
  CHANNEL_OUT_STEREO = 12
};

enum AudioFormatEncoding {
  ENCODING_PCM_16BIT = 2,
  ENCODING_PCM_8BIT = 3
};

struct sa_stream {
  jobject output_unit;

  unsigned int rate;
  unsigned int channels;
  unsigned int isPaused;

  int64_t lastStartTime;
  int64_t timePlaying;
  int64_t amountWritten;
  unsigned int bufferSize;

  jclass at_class;
};

static struct AudioTrack at;
extern JNIEnv * GetJNIForThread();

static jclass
init_jni_bindings(JNIEnv *jenv) {
  jclass class =
    (*jenv)->NewGlobalRef(jenv,
                          (*jenv)->FindClass(jenv,
                                             "android/media/AudioTrack"));
  at.constructor = (*jenv)->GetMethodID(jenv, class, "<init>", "(IIIIII)V");
  at.flush       = (*jenv)->GetMethodID(jenv, class, "flush", "()V");
  at.pause       = (*jenv)->GetMethodID(jenv, class, "pause", "()V");
  at.play        = (*jenv)->GetMethodID(jenv, class, "play",  "()V");
  at.setvol      = (*jenv)->GetMethodID(jenv, class, "setStereoVolume",  "(FF)I");
  at.stop        = (*jenv)->GetMethodID(jenv, class, "stop",  "()V");
  at.write       = (*jenv)->GetMethodID(jenv, class, "write", "([BII)I");
  at.getpos      = (*jenv)->GetMethodID(jenv, class, "getPlaybackHeadPosition", "()I");

  return class;
}

/*
 * -----------------------------------------------------------------------------
 * Startup and shutdown functions
 * -----------------------------------------------------------------------------
 */

int
sa_stream_create_pcm(
  sa_stream_t      ** _s,
  const char        * client_name,
  sa_mode_t           mode,
  sa_pcm_format_t     format,
  unsigned  int       rate,
  unsigned  int       channels
) {

  /*
   * Make sure we return a NULL stream pointer on failure.
   */
  if (_s == NULL) {
    return SA_ERROR_INVALID;
  }
  *_s = NULL;

  if (mode != SA_MODE_WRONLY) {
    return SA_ERROR_NOT_SUPPORTED;
  }
  if (format != SA_PCM_FORMAT_S16_NE) {
    return SA_ERROR_NOT_SUPPORTED;
  }
  if (channels != 1 && channels != 2) {
    return SA_ERROR_NOT_SUPPORTED;
  }

  /*
   * Allocate the instance and required resources.
   */
  sa_stream_t *s;
  if ((s = malloc(sizeof(sa_stream_t))) == NULL) {
    return SA_ERROR_OOM;
  }

  s->output_unit = NULL;
  s->rate        = rate;
  s->channels    = channels;
  s->isPaused    = 0;

  s->lastStartTime = 0;
  s->timePlaying = 0;
  s->amountWritten = 0;

  s->bufferSize = rate * channels;

  *_s = s;
  return SA_SUCCESS;
}


int
sa_stream_open(sa_stream_t *s) {

  if (s == NULL) {
    return SA_ERROR_NO_INIT;
  }
  if (s->output_unit != NULL) {
    return SA_ERROR_INVALID;
  }

  JNIEnv *jenv = GetJNIForThread();
  if (!jenv)
    return SA_ERROR_NO_DEVICE;

  if ((*jenv)->PushLocalFrame(jenv, 4)) {
    return SA_ERROR_OOM;
  }

  s->at_class = init_jni_bindings(jenv);

  int32_t chanConfig = s->channels == 1 ?
    CHANNEL_OUT_MONO : CHANNEL_OUT_STEREO;

  jobject obj =
    (*jenv)->NewObject(jenv, s->at_class, at.constructor,
                       STREAM_MUSIC,
                       s->rate,
                       chanConfig,
                       ENCODING_PCM_16BIT,
                       s->bufferSize,
                       MODE_STREAM);

  if (!obj) {
    (*jenv)->DeleteGlobalRef(jenv, s->at_class);
    (*jenv)->PopLocalFrame(jenv, NULL);
    return SA_ERROR_OOM;
  }

  s->output_unit = (*jenv)->NewGlobalRef(jenv, obj);
  (*jenv)->PopLocalFrame(jenv, NULL);

  ALOG("%x - New stream %d %d", s,  s->rate, s->channels);
  return SA_SUCCESS;
}


int
sa_stream_destroy(sa_stream_t *s) {

  if (s == NULL) {
    return SA_ERROR_NO_INIT;
  }

  JNIEnv *jenv = GetJNIForThread();
  if (!jenv)
    return SA_SUCCESS;

  (*jenv)->DeleteGlobalRef(jenv, s->output_unit);
  (*jenv)->DeleteGlobalRef(jenv, s->at_class);
  free(s);

  ALOG("%x - Stream destroyed", s);
  return SA_SUCCESS;
}


/*
 * -----------------------------------------------------------------------------
 * Data read and write functions
 * -----------------------------------------------------------------------------
 */

int
sa_stream_write(sa_stream_t *s, const void *data, size_t nbytes) {

  if (s == NULL || s->output_unit == NULL) {
    return SA_ERROR_NO_INIT;
  }
  if (nbytes == 0) {
    return SA_SUCCESS;
  }
  JNIEnv *jenv = GetJNIForThread();
  if ((*jenv)->PushLocalFrame(jenv, 2)) {
    return SA_ERROR_OOM;
  }

  jbyteArray bytearray = (*jenv)->NewByteArray(jenv, nbytes);
  if (!bytearray) {
    (*jenv)->ExceptionClear(jenv);
    (*jenv)->PopLocalFrame(jenv, NULL);
    return SA_ERROR_OOM;
  }

  jbyte *byte = (*jenv)->GetByteArrayElements(jenv, bytearray, NULL);
  if (!byte) {
    (*jenv)->PopLocalFrame(jenv, NULL);
    return SA_ERROR_OOM;
  }

  memcpy(byte, data, nbytes);

  size_t wroteSoFar = 0;
  jint retval;

  do {
    retval = (*jenv)->CallIntMethod(jenv,
                                    s->output_unit,
                                    at.write,
                                    bytearray,
                                    wroteSoFar,
                                    nbytes - wroteSoFar);
    if (retval < 0) {
      ALOG("%x - Write failed %d", s, retval);
      break;
    }

    wroteSoFar += retval;

    if (wroteSoFar != nbytes) {

      /* android doesn't start playing until we explictly call play. */
      if (!s->isPaused)
        sa_stream_resume(s);

      struct timespec ts = {0, 100000000}; /* .10s */
      nanosleep(&ts, NULL);
    }
  } while(wroteSoFar < nbytes);

  s->amountWritten += nbytes;

  (*jenv)->ReleaseByteArrayElements(jenv, bytearray, byte, 0);

  (*jenv)->PopLocalFrame(jenv, NULL);

  return retval < 0 ? SA_ERROR_INVALID : SA_SUCCESS;
}


/*
 * -----------------------------------------------------------------------------
 * General query and support functions
 * -----------------------------------------------------------------------------
 */

int
sa_stream_get_write_size(sa_stream_t *s, size_t *size) {

  if (s == NULL || s->output_unit == NULL) {
    return SA_ERROR_NO_INIT;
  }

  /* No android API for this, so estimate based on how much we have played and
   * how much we have written.
   */
  *size = s->bufferSize - ((s->timePlaying * s->channels * s->rate /
                            MILLISECONDS_PER_SECOND) - s->amountWritten);
  ALOG("%x - Write Size %d", s, *size);

  return SA_SUCCESS;
}


int
sa_stream_get_position(sa_stream_t *s, sa_position_t position, int64_t *pos) {

  if (s == NULL || s->output_unit == NULL) {
    return SA_ERROR_NO_INIT;
  }

  ALOG("%x - get position", s);

  JNIEnv *jenv = GetJNIForThread();
  *pos  = (*jenv)->CallIntMethod(jenv, s->output_unit, at.getpos);

  /* android returns number of frames, so:
     position = frames * (PCM_16_BIT == 2 bytes) * channels
  */
  *pos *= s->channels * sizeof(int16_t);
  return SA_SUCCESS;
}


int
sa_stream_pause(sa_stream_t *s) {

  if (s == NULL || s->output_unit == NULL) {
    return SA_ERROR_NO_INIT;
  }

  JNIEnv *jenv = GetJNIForThread();
  s->isPaused = 1;

  /* Update stats */
  if (s->lastStartTime != 0) {
    /* if lastStartTime is not zero, so playback has started */
    struct timespec current_time;
    clock_gettime(CLOCK_REALTIME, &current_time);
    int64_t ticker = current_time.tv_sec * 1000 + current_time.tv_nsec / 1000000;
    s->timePlaying += ticker - s->lastStartTime;
  }
  ALOG("%x - Pause total time playing: %lld total written: %lld", s,  s->timePlaying, s->amountWritten);

  (*jenv)->CallVoidMethod(jenv, s->output_unit, at.pause);
  return SA_SUCCESS;
}


int
sa_stream_resume(sa_stream_t *s) {

  if (s == NULL || s->output_unit == NULL) {
    return SA_ERROR_NO_INIT;
  }

  ALOG("%x - resume", s);

  JNIEnv *jenv = GetJNIForThread();
  s->isPaused = 0;

  /* Update stats */
  struct timespec current_time;
  clock_gettime(CLOCK_REALTIME, &current_time);
  int64_t ticker = current_time.tv_sec * 1000 + current_time.tv_nsec / 1000000;
  s->lastStartTime = ticker;

  (*jenv)->CallVoidMethod(jenv, s->output_unit, at.play);
  return SA_SUCCESS;
}


int
sa_stream_drain(sa_stream_t *s)
{
  if (s == NULL || s->output_unit == NULL) {
    return SA_ERROR_NO_INIT;
  }

  /* There is no way with the Android SDK to determine exactly how
     long to playback.  So estimate and sleep for the long.
  */

  size_t available;
  sa_stream_get_write_size(s, &available);

  long x = (s->bufferSize - available) * 1000 / s->channels / s->rate / sizeof(int16_t) * NANOSECONDS_IN_MILLISECOND;
  ALOG("%x - Drain - sleep for %f ns", s, x);

  struct timespec ts = {0, x};
  nanosleep(&ts, NULL);

  return SA_SUCCESS;
}


/*
 * -----------------------------------------------------------------------------
 * Extension functions
 * -----------------------------------------------------------------------------
 */

int
sa_stream_set_volume_abs(sa_stream_t *s, float vol) {

  if (s == NULL || s->output_unit == NULL) {
    return SA_ERROR_NO_INIT;
  }

  JNIEnv *jenv = GetJNIForThread();
  (*jenv)->CallIntMethod(jenv, s->output_unit, at.setvol,
                         (jfloat)vol, (jfloat)vol);

  return SA_SUCCESS;
}

/*
 * -----------------------------------------------------------------------------
 * Unsupported functions
 * -----------------------------------------------------------------------------
 */
#define UNSUPPORTED(func)   func { return SA_ERROR_NOT_SUPPORTED; }

UNSUPPORTED(int sa_stream_create_opaque(sa_stream_t **s, const char *client_name, sa_mode_t mode, const char *codec))
UNSUPPORTED(int sa_stream_set_write_lower_watermark(sa_stream_t *s, size_t size))
UNSUPPORTED(int sa_stream_set_read_lower_watermark(sa_stream_t *s, size_t size))
UNSUPPORTED(int sa_stream_set_write_upper_watermark(sa_stream_t *s, size_t size))
UNSUPPORTED(int sa_stream_set_read_upper_watermark(sa_stream_t *s, size_t size))
UNSUPPORTED(int sa_stream_set_channel_map(sa_stream_t *s, const sa_channel_t map[], unsigned int n))
UNSUPPORTED(int sa_stream_set_xrun_mode(sa_stream_t *s, sa_xrun_mode_t mode))
UNSUPPORTED(int sa_stream_set_non_interleaved(sa_stream_t *s, int enable))
UNSUPPORTED(int sa_stream_set_dynamic_rate(sa_stream_t *s, int enable))
UNSUPPORTED(int sa_stream_set_driver(sa_stream_t *s, const char *driver))
UNSUPPORTED(int sa_stream_start_thread(sa_stream_t *s, sa_event_callback_t callback))
UNSUPPORTED(int sa_stream_stop_thread(sa_stream_t *s))
UNSUPPORTED(int sa_stream_change_device(sa_stream_t *s, const char *device_name))
UNSUPPORTED(int sa_stream_change_read_volume(sa_stream_t *s, const int32_t vol[], unsigned int n))
UNSUPPORTED(int sa_stream_change_write_volume(sa_stream_t *s, const int32_t vol[], unsigned int n))
UNSUPPORTED(int sa_stream_change_rate(sa_stream_t *s, unsigned int rate))
UNSUPPORTED(int sa_stream_change_meta_data(sa_stream_t *s, const char *name, const void *data, size_t size))
UNSUPPORTED(int sa_stream_change_user_data(sa_stream_t *s, const void *value))
UNSUPPORTED(int sa_stream_set_adjust_rate(sa_stream_t *s, sa_adjust_t direction))
UNSUPPORTED(int sa_stream_set_adjust_nchannels(sa_stream_t *s, sa_adjust_t direction))
UNSUPPORTED(int sa_stream_set_adjust_pcm_format(sa_stream_t *s, sa_adjust_t direction))
UNSUPPORTED(int sa_stream_set_adjust_watermarks(sa_stream_t *s, sa_adjust_t direction))
UNSUPPORTED(int sa_stream_get_mode(sa_stream_t *s, sa_mode_t *access_mode))
UNSUPPORTED(int sa_stream_get_codec(sa_stream_t *s, char *codec, size_t *size))
UNSUPPORTED(int sa_stream_get_pcm_format(sa_stream_t *s, sa_pcm_format_t *format))
UNSUPPORTED(int sa_stream_get_rate(sa_stream_t *s, unsigned int *rate))
UNSUPPORTED(int sa_stream_get_nchannels(sa_stream_t *s, int *nchannels))
UNSUPPORTED(int sa_stream_get_user_data(sa_stream_t *s, void **value))
UNSUPPORTED(int sa_stream_get_write_lower_watermark(sa_stream_t *s, size_t *size))
UNSUPPORTED(int sa_stream_get_read_lower_watermark(sa_stream_t *s, size_t *size))
UNSUPPORTED(int sa_stream_get_write_upper_watermark(sa_stream_t *s, size_t *size))
UNSUPPORTED(int sa_stream_get_read_upper_watermark(sa_stream_t *s, size_t *size))
UNSUPPORTED(int sa_stream_get_channel_map(sa_stream_t *s, sa_channel_t map[], unsigned int *n))
UNSUPPORTED(int sa_stream_get_xrun_mode(sa_stream_t *s, sa_xrun_mode_t *mode))
UNSUPPORTED(int sa_stream_get_non_interleaved(sa_stream_t *s, int *enabled))
UNSUPPORTED(int sa_stream_get_dynamic_rate(sa_stream_t *s, int *enabled))
UNSUPPORTED(int sa_stream_get_driver(sa_stream_t *s, char *driver_name, size_t *size))
UNSUPPORTED(int sa_stream_get_device(sa_stream_t *s, char *device_name, size_t *size))
UNSUPPORTED(int sa_stream_get_read_volume(sa_stream_t *s, int32_t vol[], unsigned int *n))
UNSUPPORTED(int sa_stream_get_write_volume(sa_stream_t *s, int32_t vol[], unsigned int *n))
UNSUPPORTED(int sa_stream_get_meta_data(sa_stream_t *s, const char *name, void*data, size_t *size))
UNSUPPORTED(int sa_stream_get_adjust_rate(sa_stream_t *s, sa_adjust_t *direction))
UNSUPPORTED(int sa_stream_get_adjust_nchannels(sa_stream_t *s, sa_adjust_t *direction))
UNSUPPORTED(int sa_stream_get_adjust_pcm_format(sa_stream_t *s, sa_adjust_t *direction))
UNSUPPORTED(int sa_stream_get_adjust_watermarks(sa_stream_t *s, sa_adjust_t *direction))
UNSUPPORTED(int sa_stream_get_state(sa_stream_t *s, sa_state_t *state))
UNSUPPORTED(int sa_stream_get_event_error(sa_stream_t *s, sa_error_t *error))
UNSUPPORTED(int sa_stream_get_event_notify(sa_stream_t *s, sa_notify_t *notify))
UNSUPPORTED(int sa_stream_read(sa_stream_t *s, void *data, size_t nbytes))
UNSUPPORTED(int sa_stream_read_ni(sa_stream_t *s, unsigned int channel, void *data, size_t nbytes))
UNSUPPORTED(int sa_stream_write_ni(sa_stream_t *s, unsigned int channel, const void *data, size_t nbytes))
UNSUPPORTED(int sa_stream_pwrite(sa_stream_t *s, const void *data, size_t nbytes, int64_t offset, sa_seek_t whence))
UNSUPPORTED(int sa_stream_pwrite_ni(sa_stream_t *s, unsigned int channel, const void *data, size_t nbytes, int64_t offset, sa_seek_t whence))
UNSUPPORTED(int sa_stream_get_read_size(sa_stream_t *s, size_t *size))
UNSUPPORTED(int sa_stream_get_volume_abs(sa_stream_t *s, float *vol))

const char *sa_strerror(int code) { return NULL; }