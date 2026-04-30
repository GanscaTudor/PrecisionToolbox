%% NPN Curve Tracer using AD5592r on ADALM-LSMSPG
%
% Demonstrates DAC writes and ADC reads on the AD5592r using the
% Precision Toolbox class adi.AD5592r.Rx.
%
% Hardware:
%   - ADALM-LSMSPG board with NPN transistor circuit
%   - MAX32666FTHR running tinyiiod firmware (serial), or
%   - Raspberry Pi running iiod (network)
%
% Circuit:
%   voltage0 (DAC) -> 47k resistor -> transistor base
%   voltage2 (DAC) -> 47 ohm sense resistor -> transistor collector
%   voltage1 (ADC) <- collector (after sense resistor)
%
% Usage:
%   >> ad5592r_CurveTracer                                   % default URI
%   >> ad5592r_CurveTracer('serial:COM12,115200,8n1n')       % Feather
%   >> ad5592r_CurveTracer('ip:analog.local')                % RPi

function ad5592r_CurveTracer(uri)
    if nargin < 1
        uri = 'ip:analog.local';
    end

    fprintf('Connecting to %s ...\n', uri);

    dev = adi.AD5592r.Rx('uri', uri);
    dev.setup();
    cleanup = onCleanup(@() dev.release());

    mV_per_lsb = dev.readScale('voltage2');
    fprintf('Scale: %.6f mV/LSB\n', mV_per_lsb);

    % Circuit constants
    Rsense = 47.0;       % Ohms — collector sense resistor
    Rbase  = 47.0e3;     % Ohms — base drive resistor
    Vbe    = 0.7;        % Volts — assumed base-emitter drop

    % Initialize DAC outputs to a safe level
    dev.writeDAC('voltage0', round(500.0 / mV_per_lsb));
    dev.writeDAC('voltage2', round(500.0 / mV_per_lsb));

    % Sweep base voltage in 5 steps, collector voltage in 50 mV steps
    curves = {};

    for vb = 499:500:2499
        vb_raw = round(vb / mV_per_lsb);
        dev.writeDAC('voltage0', vb_raw);

        ib = ((vb_raw * mV_per_lsb / 1000) - Vbe) / Rbase;
        fprintf('Base Drive: %.3f V, Ib = %.1f uA\n', ...
                vb_raw * mV_per_lsb / 1000, ib * 1e6);

        vcs = [];
        ics = [];

        for vcv = 0:50:2499
            dev.writeDAC('voltage2', round(vcv / mV_per_lsb));

            vc_drive_raw = dev.readADC('voltage2');
            vc_sense_raw = dev.readADC('voltage1');

            ic = (vc_drive_raw - vc_sense_raw) * mV_per_lsb / Rsense;
            vc = vc_sense_raw * mV_per_lsb / 1000.0;

            vcs = [vcs, vc]; %#ok<AGROW>
            ics = [ics, ic]; %#ok<AGROW>
        end

        curves{end+1} = {vcs, ics}; %#ok<AGROW>
    end

    % Plot the family of curves
    figure(1); clf;
    hold on;
    labels = {};
    for c = 1:length(curves)
        plot(curves{c}{1}, curves{c}{2}, 'LineWidth', 1.5);
        vb_mV = 499 + (c - 1) * 500;
        labels{end+1} = sprintf('Vb = %.1f V', vb_mV / 1000); %#ok<AGROW>
    end
    hold off;
    grid on;
    title('ADALM-LSMSPG NPN Curve Tracer');
    xlabel('Collector Voltage (V)');
    ylabel('Collector Current (mA)');
    legend(labels, 'Location', 'southeast');
end
