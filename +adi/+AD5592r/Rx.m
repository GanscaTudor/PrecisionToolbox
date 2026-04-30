classdef Rx < adi.AD559xr.Base
    %AD5592r.Rx  8-channel multifunction ADC/DAC/GPIO via SPI
    %
    %   Works with tinyiiod serial and iiod network backends.
    %
    %   Example (Feather / tinyiiod):
    %     rx = adi.AD5592r.Rx('uri','serial:COM12,115200,8n1n');
    %     rx.setup();
    %     scale = rx.readScale('voltage2');
    %     rx.writeDAC('voltage0', round(500 / scale));
    %     val   = rx.readADC('voltage1');
    %     rx.release();
    %
    %   Example (Raspberry Pi / iiod):
    %     rx = adi.AD5592r.Rx('uri','ip:analog.local');
    %
    %   <a href="https://www.analog.com/media/en/technical-documentation/data-sheets/ad5592r.pdf">AD5592r Datasheet</a>

    properties (Nontunable, Hidden)
        channel_names = { ...
            'voltage0','voltage1','voltage2','voltage3', ...
            'voltage4','voltage5','voltage6','voltage7'}
    end

    methods
        function obj = Rx(varargin)
            obj = obj@adi.AD559xr.Base('ad5592r', 'ad5592r', varargin{:});
        end
    end
end
