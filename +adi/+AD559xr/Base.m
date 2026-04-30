classdef Base < adi.common.Rx & adi.common.RxTx & ...
         matlabshared.libiio.base & adi.common.Attribute & ...
         adi.common.RegisterReadWrite & adi.common.Channel
    % AD559xr Precision ADC Class
    % AD5592r is a SPI Interface ADC
    % AD5593r is an I2C Interface ADC
    %
    %   Multifunction 8-channel ADC/DAC/GPIO devices.
    %   Supports iiod network and tinyiiod serial backends.

    properties (Nontunable)
        SamplesPerFrame = 400
    end

    properties (Hidden, Nontunable, Access = protected)
        isOutput = false
    end

    properties (Nontunable, Hidden, Constant)
        Type = 'Rx'
    end

    properties (Nontunable, Hidden)
        Timeout = Inf
        kernelBuffersCount = 1
        dataTypeStr = 'int16'
        phyDevName
        devName
    end

    properties (Hidden, Constant)
        ComplexData = false
    end

    properties (Access = protected)
        useSerial = false
        serialCtx = []
        serialDev = []
    end

    methods
        %% Constructor
        function obj = Base(phydev, dev, varargin)
            coder.allowpcode('plain');
            obj = obj@matlabshared.libiio.base(varargin{:});
            obj.enableExplicitPolling = false;
            obj.EnabledChannels = 1;
            obj.BufferTypeConversionEnable = true;
            obj.phyDevName = phydev;
            obj.devName = dev;
            if ~any(strcmpi(varargin(1:2:end), 'uri'))
                obj.uri = 'ip:analog.local';
            end
        end

        function flush(obj)
            flushBuffers(obj);
        end

        function delete(obj)
            obj.cleanupSerial();
            delete@adi.common.RxTx(obj);
        end

        %% Convenience API for attribute-based access
        function writeDAC(obj, channel, value)
            %writeDAC  Write a raw DAC code to an output channel.
            if obj.useSerial
                ch = calllib('libiio', ...
                    'iio_device_find_channel', ...
                    obj.serialDev, channel, int32(true));
                ret = calllib('libiio', ...
                    'iio_channel_attr_write_longlong', ...
                    ch, 'raw', int64(value));
                if ret < 0
                    error('adi:AD559xr:writeDAC', ...
                        'DAC write failed for %s (ret=%d)', channel, ret);
                end
            else
                obj.setAttributeLongLong(channel, 'raw', value, true);
            end
        end

        function val = readADC(obj, channel)
            %readADC  Read a raw ADC code from an input channel.
            if obj.useSerial
                ch = calllib('libiio', ...
                    'iio_device_find_channel', ...
                    obj.serialDev, channel, int32(false));
                valPtr = libpointer('int64Ptr', int64(0));
                ret = calllib('libiio', ...
                    'iio_channel_attr_read_longlong', ...
                    ch, 'raw', valPtr);
                if ret < 0
                    error('adi:AD559xr:readADC', ...
                        'ADC read failed for %s (ret=%d)', channel, ret);
                end
                val = double(valPtr.Value);
            else
                val = double(obj.getAttributeLongLong( ...
                    channel, 'raw', false));
            end
        end

        function val = readScale(obj, channel)
            %readScale  Read the mV-per-LSB scale factor for a channel.
            if obj.useSerial
                ch = calllib('libiio', ...
                    'iio_device_find_channel', ...
                    obj.serialDev, channel, int32(true));
                if isNull(ch)
                    ch = calllib('libiio', ...
                        'iio_device_find_channel', ...
                        obj.serialDev, channel, int32(false));
                end
                valPtr = libpointer('doublePtr', 0.0);
                ret = calllib('libiio', ...
                    'iio_channel_attr_read_double', ...
                    ch, 'scale', valPtr);
                if ret < 0
                    error('adi:AD559xr:readScale', ...
                        'Scale read failed (ret=%d)', ret);
                end
                val = valPtr.Value;
            else
                val = obj.getAttributeDouble(channel, 'scale', true);
            end
        end
    end

    %% API Functions
    methods (Hidden, Access = protected)
        function setupInit(~)
        end
    end

    %% External Dependency Methods
    methods (Hidden, Static)
        function tf = isSupportedContext(bldCfg)
            tf = matlabshared.libiio.ExternalDependency ...
                .isSupportedContext(bldCfg);
        end

        function updateBuildInfo(buildInfo, bldCfg)
            matlabshared.libiio.ExternalDependency ...
                .updateBuildInfo(buildInfo, bldCfg);
        end

        function bName = getDescriptiveName(~)
            bName = 'AD559xr';
        end
    end

    methods (Access = protected)
        function cleanupSerial(obj)
            if ~isempty(obj.serialCtx) && libisloaded('libiio')
                calllib('libiio', 'iio_context_destroy', obj.serialCtx);
            end
            obj.serialCtx = [];
            obj.serialDev = [];
            obj.useSerial = false;
        end

        function loadLibiio(~)
            if libisloaded('libiio')
                return;
            end
            hdr = fullfile(tempdir, 'iio_ad559xr.h');
            if ~isfile(hdr)
                fid = fopen(hdr, 'w');
                fprintf(fid, 'void * iio_create_context_from_uri(const char *uri);\n');
                fprintf(fid, 'void   iio_context_destroy(void *ctx);\n');
                fprintf(fid, 'int    iio_context_set_timeout(void *ctx, unsigned int timeout_ms);\n');
                fprintf(fid, 'void * iio_context_find_device(void *ctx, const char *name);\n');
                fprintf(fid, 'void * iio_device_find_channel(void *dev, const char *name, int output);\n');
                fprintf(fid, 'int    iio_channel_attr_read_longlong(void *chn, const char *attr, long long *val);\n');
                fprintf(fid, 'int    iio_channel_attr_write_longlong(void *chn, const char *attr, long long val);\n');
                fprintf(fid, 'int    iio_channel_attr_read_double(void *chn, const char *attr, double *val);\n');
                fclose(fid);
            end
            loadlibrary('libiio', hdr);
        end
    end
end
