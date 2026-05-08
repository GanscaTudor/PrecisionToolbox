%% AD5592r NPN Curve Tracer using PrecisionToolbox
%% Sweeps base and collector voltages on the ADALM-LSMSPG board
%% and plots Ic vs Vc family of curves.
clc
clear

% Instantiate the system object and connect
rx = adi.AD5592r.Rx();
rx.uri = 'serial:COM12,115200,8n1n';
rx.EnabledChannels = 2;
rx.SamplesPerFrame = 1;
rx();

% Circuit constants (NPN curve tracer on ADALM-LSMSPG)
Rsense = 47.0;       % 47 Ohms - collector sense resistor
Rbase  = 47.0e3;     % 47 kOhms - base resistor
Vbe    = 0.7;         % Approximate base-emitter voltage

% Read scale (mV per LSB) - identical for all AD5592r channels
mV_per_lsb = rx.getAttributeDouble('voltage0', 'scale', true);
fprintf('Scale: %.6f mV/LSB\n', mV_per_lsb);

% Initialize DAC outputs to a safe starting point
rx.setAttributeRAW('voltage0', 'raw', num2str(round(500 / mV_per_lsb)), true);
rx.setAttributeRAW('voltage2', 'raw', num2str(round(500 / mV_per_lsb)), true);

% Sweep parameters
base_mv  = 499:500:2499;
coll_mv  = 0:50:2450;
n_base   = length(base_mv);
n_coll   = length(coll_mv);

% Preallocate results
curves_vc = zeros(n_base, n_coll);
curves_ic = zeros(n_base, n_coll);
labels    = cell(1, n_base);

for bi = 1:n_base
    vb_raw = round(base_mv(bi) / mV_per_lsb);
    rx.setAttributeRAW('voltage0', 'raw', num2str(vb_raw), true);

    ib = ((vb_raw * mV_per_lsb / 1000) - Vbe) / Rbase;
    fprintf('Base Drive: %.3f V, %.1f uA\n', vb_raw * mV_per_lsb / 1000, ib * 1e6);
    labels{bi} = sprintf('I_b = %.1f \\muA', ib * 1e6);

    for ci = 1:n_coll
        vc_raw = round(coll_mv(ci) / mV_per_lsb);
        rx.setAttributeRAW('voltage2', 'raw', num2str(vc_raw), true);

        vc_drive_raw = str2double(rx.getAttributeRAW('voltage2', 'raw', false));
        vc_sense_raw = str2double(rx.getAttributeRAW('voltage1', 'raw', false));

        ic = (vc_drive_raw - vc_sense_raw) * mV_per_lsb / Rsense;
        vc = vc_sense_raw * mV_per_lsb / 1000.0;

        curves_vc(bi, ci) = vc;
        curves_ic(bi, ci) = ic;
    end
end

% Plot
figure('Name', 'AD5592r NPN Curve Tracer');
hold on;
for bi = 1:n_base
    plot(curves_vc(bi, :), curves_ic(bi, :), 'LineWidth', 1.5);
end
hold off;
title('ADALM-LSMSPG NPN Curve Tracer (MATLAB)');
xlabel('Collector Voltage (V)');
ylabel('Collector Current (mA)');
legend(labels, 'Location', 'northwest');
grid on;

% Cleanup
release(rx);
