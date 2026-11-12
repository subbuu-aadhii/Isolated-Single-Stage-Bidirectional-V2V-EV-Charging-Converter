%% ============================================================
%  Comparison Plots: Fuzzy vs PI vs ISMC
%  Window: First 0.1 s only
%% ============================================================

%% --- 1. Load workspaces -------------------------------------
S_fz = load('fuzzy_steadystate.mat');
S_pi = load('pi_steadystate.mat');
S_is = load('ismc_steadystate.mat');

out_fz = S_fz.out;
out_pi = S_pi.out;
out_is = S_is.out;

%% --- 2. Helper: extract timeseries --------------------------
function [t, y] = getTS(simOut, fieldName)
    ts = simOut.(fieldName);
    t  = ts.Time;
    y  = squeeze(double(ts.Data));
end

%% --- 3. Signal mapping table --------------------------------
sigMap = {
    'IB1 (Battery 1 Current)',  'IB1_data',  'ib1_pi',  'ib1_ismc';
    'IB2 (Battery 2 Current)',  'IB2_data',  'ib2_pi',  'ib2_ismc';
    'PB1 (Battery 1 Power)',    'PB1_data',  'pb1_pi',  'pb1_ismc';
    'PB2 (Battery 2 Power)',    'PB2_data',  'pb2_pi',  'pb2_ismc';
    'SOC1',                     'SOC_data',  'soc1_pi', 'soc1_ismc';
    'SOC2',                     'SOC_data1', 'soc2_pi', 'soc2_ismc';
    'VB1 (Battery 1 Voltage)',  'VB1_data',  'vb1_pi',  'vb1_ismc';
    'VB2 (Battery 2 Voltage)',  'VB2_data',  'vb2_pi',  'vb2_ismc';
};

%% --- 4. Settings --------------------------------------------
T_START  = 0;
T_ZOOM   = 0.1;          % first 0.1 s
colors   = {'#0072BD', '#D95319', '#77AC30'};
labels   = {'Fuzzy', 'PI', 'ISMC'};
lw       = 1.5;

%% --- 5. Close all previous figures --------------------------
close all;

%% --- 6. Generate figures (first 0.1 s only) -----------------
nSig = size(sigMap, 1);

for s = 1 : nSig
    dispName = sigMap{s, 1};
    fz_field = sigMap{s, 2};
    pi_field = sigMap{s, 3};
    is_field = sigMap{s, 4};

    [t_fz, y_fz] = getTS(out_fz, fz_field);
    [t_pi, y_pi] = getTS(out_pi, pi_field);
    [t_is, y_is] = getTS(out_is, is_field);

    figure('Name', sprintf('%s – first 0.1 s', dispName), ...
           'NumberTitle', 'off', ...
           'Units', 'normalized', 'Position', [0.05 0.3 0.55 0.35]);

    plot(t_fz, y_fz, 'Color', colors{1}, 'LineWidth', lw); hold on
    plot(t_pi, y_pi, 'Color', colors{2}, 'LineWidth', lw);
    plot(t_is, y_is, 'Color', colors{3}, 'LineWidth', lw);
    hold off

    xlim([T_START, T_ZOOM]);
    xlabel('Time (s)', 'FontSize', 11);
    ylabel(dispName, 'FontSize', 11, 'Interpreter', 'none');
    title(sprintf('[0 – 0.1 s]  %s', dispName), ...
          'Interpreter', 'none', 'FontSize', 12);
    legend(labels, 'Location', 'best', 'FontSize', 10);
    grid on; box on;
end

fprintf('Done. %d figures generated.\n', nSig);