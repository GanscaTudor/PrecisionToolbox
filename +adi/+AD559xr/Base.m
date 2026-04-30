classdef (Abstract) Base < adi.common.RxTx & ...
        matlabshared.libiio.base & adi.common.Attribute
    %AD559xr.Base  Base class for AD5592r (SPI) and AD5593r (I2C)
    %
    %   Creates its own IIO context via calllib, bypassing the compiled
    %   setupImpl in matlabshared.libiio.base.  Buffer creation is
    %   skipped (no-op) because these devices use single-value attribute
    %   reads/writes, not DMA streaming.
    %
    %   Attribute methods are overridden to route through the calllib
    %   context so both DAC writes and ADC reads work on every backend
    %   (tinyiiod serial, iiod network).

    properties (Access = private)
        ownCtx  = []
        ownDev  = []
        libAlias = 'libiio_direct'
    end

    %% Required abstract property implementations
    properties (Nontunable, Hidden, Constant)
        Type = 'Rx'
    end

    properties (Hidden, Constant, Logical)
        ComplexData        = false
        EnableCyclicBuffers = false
    end

    properties (Hidden, Logical, Nontunable)
        BufferTypeConversionEnable = false
    end

    properties (Hidden, Nontunable, Access = protected)
        isOutput = false
    end

    properties (Nontunable, Hidden)
        Timeout            = Inf
        kernelBuffersCount = 0
        SamplesPerFrame    = 1
        dataTypeStr        = 'int16'
        phyDevName
        devName
    end

    %% ---- Constructor -------------------------------------------------------
    methods
        function obj = Base(phydev, dev, varargin)
            coder.allowpcode('plain');
            if ~any(strcmpi(varargin(1:2:end), 'uri'))
                varargin = [varargin, {'uri', 'ip:analog.local'}];
            end
            obj = obj@matlabshared.libiio.base(varargin{:});
            obj.enableExplicitPolling = false;
            obj.EnabledChannels  = 1;
            obj.phyDevName       = phydev;
            obj.devName          = dev;
        end

        function delete(obj)
            delete@adi.common.RxTx(obj);
        end
    end

    %% ---- Setup / teardown --------------------------------------------------
    methods (Hidden, Access = protected)
        function setupImpl(obj)
            obj.Count(1, obj);

            if ~libisloaded(obj.libAlias)
                loadlibrary('libiio', obj.findHeader(), ...
                    'alias', obj.libAlias);
            end

            obj.ownCtx = calllib(obj.libAlias, ...
                'iio_create_context_from_uri', obj.uri);
            if isNull(obj.ownCtx)
                error('adi:AD559xr:setup', ...
                    'Failed to create IIO context for: %s', obj.uri);
            end
            calllib(obj.libAlias, ...
                'iio_context_set_timeout', obj.ownCtx, uint32(5000));

            obj.ownDev = calllib(obj.libAlias, ...
                'iio_context_find_device', obj.ownCtx, obj.phyDevName);
            if isNull(obj.ownDev)
                calllib(obj.libAlias, 'iio_context_destroy', obj.ownCtx);
                obj.ownCtx = [];
                error('adi:AD559xr:setup', ...
                    '%s not found. Check connection and firmware.', ...
                    obj.phyDevName);
            end

            obj.ConnectedToDevice = true;
            setupInit(obj);
        end

        function releaseImpl(obj)
            obj.Count(-1, obj);
            if ~isempty(obj.ownCtx) && libisloaded(obj.libAlias)
                calllib(obj.libAlias, 'iio_context_destroy', obj.ownCtx);
            end
            obj.ownCtx = [];
            obj.ownDev = [];
            obj.ConnectedToDevice = false;
        end

        function setupInit(~)
        end
    end

    %% ---- Buffer overrides (no-op) ------------------------------------------
    methods (Hidden, Access = {?handle})
        function status = configureChanBuffers(obj)
            obj.ConnectedToDevice = true;
            status = 0;
        end

        function releaseChanBuffers(obj)
            obj.ConnectedToDevice = false;
        end
    end

    %% ---- Attribute overrides -----------------------------------------------
    methods (Hidden)
        function setAttributeLongLong(obj, id, attr, value, isOut, varargin)
            ch  = obj.findOwnChannel(id, isOut);
            ret = calllib(obj.libAlias, ...
                'iio_channel_attr_write_longlong', ch, attr, int64(value));
            if ret < 0
                error('adi:AD559xr:setAttr', ...
                    'Write failed for %s.%s (ret=%d)', id, attr, ret);
            end
        end

        function v = getAttributeLongLong(obj, id, attr, isOut, varargin)
            ch     = obj.findOwnChannel(id, isOut);
            valPtr = libpointer('int64Ptr', int64(0));
            ret    = calllib(obj.libAlias, ...
                'iio_channel_attr_read_longlong', ch, attr, valPtr);
            if ret < 0
                error('adi:AD559xr:getAttr', ...
                    'Read failed for %s.%s (ret=%d)', id, attr, ret);
            end
            v = valPtr.Value;
        end

        function v = getAttributeDouble(obj, id, attr, isOut, varargin)
            ch     = obj.findOwnChannel(id, isOut);
            valPtr = libpointer('doublePtr', 0.0);
            ret    = calllib(obj.libAlias, ...
                'iio_channel_attr_read_double', ch, attr, valPtr);
            if ret < 0
                error('adi:AD559xr:getAttr', ...
                    'Read failed for %s.%s (ret=%d)', id, attr, ret);
            end
            v = valPtr.Value;
        end
    end

    %% ---- Convenience API ---------------------------------------------------
    methods
        function writeDAC(obj, channel, value)
            %writeDAC  Write a raw DAC code to an output channel.
            obj.setAttributeLongLong(channel, 'raw', value, true);
        end

        function val = readADC(obj, channel)
            %readADC  Read a raw ADC code from an input channel.
            ch     = obj.findOwnChannel(channel, false);
            valPtr = libpointer('int64Ptr', int64(0));
            ret    = calllib(obj.libAlias, ...
                'iio_channel_attr_read_longlong', ch, 'raw', valPtr);
            if ret < 0
                error('adi:AD559xr:readADC', ...
                    'ADC read failed for %s (ret=%d)', channel, ret);
            end
            val = double(valPtr.Value);
        end

        function val = readScale(obj, channel)
            %readScale  Read the mV-per-LSB scale factor for a channel.
            ch = calllib(obj.libAlias, ...
                'iio_device_find_channel', obj.ownDev, channel, int32(1));
            if isNull(ch)
                ch = calllib(obj.libAlias, ...
                    'iio_device_find_channel', obj.ownDev, channel, ...
                    int32(0));
            end
            if isNull(ch)
                error('adi:AD559xr:readScale', ...
                    'Channel %s not found.', channel);
            end
            valPtr = libpointer('doublePtr', 0.0);
            ret    = calllib(obj.libAlias, ...
                'iio_channel_attr_read_double', ch, 'scale', valPtr);
            if ret < 0
                error('adi:AD559xr:readScale', ...
                    'Scale read failed (ret=%d).', ret);
            end
            val = valPtr.Value;
        end
    end

    %% ---- Private helpers ---------------------------------------------------
    methods (Access = private)
        function ch = findOwnChannel(obj, name, isOut)
            ch = calllib(obj.libAlias, ...
                'iio_device_find_channel', obj.ownDev, name, int32(isOut));
            if isNull(ch)
                error('adi:AD559xr:findChannel', ...
                    'Channel %s not found.', name);
            end
        end

        function hdr = findHeader(~)
            classDir   = fileparts(mfilename('fullpath'));
            candidates = {
                fullfile(classDir, 'iio_minimal.h')
                fullfile(classDir, '..', 'iio_minimal.h')
                fullfile(classDir, '..', '..', 'iio_minimal.h')
            };
            for k = 1:numel(candidates)
                if isfile(candidates{k})
                    hdr = candidates{k};
                    return;
                end
            end
            error('adi:AD559xr:setup', ...
                'iio_minimal.h not found. Place it near the +adi folder.');
        end
    end

    %% ---- External dependency stubs -----------------------------------------
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
end
