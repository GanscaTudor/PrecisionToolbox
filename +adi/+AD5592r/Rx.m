classdef Rx < adi.common.Rx & adi.common.RxTx ...
        & adi.AD559xr.Base
    %AD5592r.Rx  8-channel multifunction ADC/DAC/GPIO via SPI
    %   The adi.AD5592r.Rx System object can receive data from the
    %   AD5592r and write DAC outputs via attribute access.
    %
    %   rx = adi.AD5592r.Rx;
    %   rx = adi.AD5592r.Rx('uri','ip:192.168.2.1');
    %
    %   <a href="https://www.analog.com/media/en/technical-documentation/data-sheets/ad5592r.pdf">AD5592r Datasheet</a>

    properties (Nontunable, Hidden)
        channel_names = {'voltage0','voltage1','voltage2', ...
            'voltage3','voltage4','voltage5','voltage6','voltage7'}
    end

    methods
        %% Constructor
        function obj = Rx(varargin)
            obj = obj@adi.AD559xr.Base('ad5592r', 'ad5592r', varargin{:});
        end
    end

    methods (Hidden, Access = protected)
        function setupImpl(obj)
            if startsWith(obj.uri, 'serial:')
                obj.useSerial = true;
                obj.loadLibiio();

                obj.serialCtx = calllib('libiio', ...
                    'iio_create_context_from_uri', obj.uri);
                if isNull(obj.serialCtx)
                    error('adi:AD5592r:setup', ...
                        'Failed to create context for: %s', obj.uri);
                end
                calllib('libiio', 'iio_context_set_timeout', ...
                    obj.serialCtx, uint32(5000));

                obj.serialDev = calllib('libiio', ...
                    'iio_context_find_device', ...
                    obj.serialCtx, obj.phyDevName);
                if isNull(obj.serialDev)
                    calllib('libiio', 'iio_context_destroy', ...
                        obj.serialCtx);
                    obj.serialCtx = [];
                    error('adi:AD5592r:setup', ...
                        '%s not found. Check connection.', obj.phyDevName);
                end
                obj.ConnectedToDevice = true;
            else
                setupImpl@adi.common.RxTx(obj);
            end
        end

        function releaseImpl(obj)
            obj.cleanupSerial();
            releaseImpl@adi.common.RxTx(obj);
        end
    end

    methods (Hidden, Access = {?handle})
        function status = configureChanBuffers(obj)
            obj.ConnectedToDevice = true;
            status = 0;
        end
    end
end
