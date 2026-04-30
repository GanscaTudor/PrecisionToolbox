/*
 * iio_minimal.h - Minimal libiio declarations for MATLAB loadlibrary
 *
 * Provides the subset of libiio v0.x functions needed for attribute-based
 * ADC/DAC access on devices like the AD5592r and AD5593r.
 *
 * Usage:
 *   loadlibrary('libiio', 'iio_minimal.h', 'alias', 'libiio_direct')
 */

/* Context */
void *        iio_create_context_from_uri(const char *uri);
void          iio_context_destroy(void *ctx);
int           iio_context_set_timeout(void *ctx, unsigned int timeout_ms);

/* Device discovery */
unsigned int  iio_context_get_devices_count(void *ctx);
void *        iio_context_get_device(void *ctx, unsigned int index);
void *        iio_context_find_device(void *ctx, const char *name);
const char *  iio_device_get_name(void *dev);

/* Channel discovery */
void *        iio_device_find_channel(void *dev, const char *name, int output);

/* Channel attributes — typed */
int           iio_channel_attr_read_longlong(void *chn, const char *attr, long long *val);
int           iio_channel_attr_write_longlong(void *chn, const char *attr, long long val);
int           iio_channel_attr_read_double(void *chn, const char *attr, double *val);

/* Channel attributes — string */
int           iio_channel_attr_read(void *chn, const char *attr, char *dst, int len);
int           iio_channel_attr_write(void *chn, const char *attr, const char *src);
