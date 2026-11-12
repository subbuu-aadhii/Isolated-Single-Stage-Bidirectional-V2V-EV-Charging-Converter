
%% COMBINED CONDUCTION AND SWITCHING LOSS ANALYSIS
% EV1: Pcond1...Pcond8, Psw1...Psw8
% EV2: Pcond1_2...Pcond8_2, Psw1_2...Psw8_2
%
% Conduction signals: instantaneous power in W.
% Switching signals: cumulative switching energy in J by default.
%
% Supports standalone workspace variables and Simulink.SimulationOutput.

%% SETTINGS
t_start = 0.2;
t_end_requested = 10.0;

% Choose ONE:
pswMode = 'cumulativeEnergy';  % Psw signals are cumulative energy in J
% pswMode = 'power';           % Psw signals are instantaneous power in W

%% VARIABLE NAMES
condNames = cell(16,1);
swNames   = cell(16,1);
sideNames = cell(16,1);
switchNames = cell(16,1);

for k = 1:8
    condNames{k} = sprintf('Pcond%d', k);
    swNames{k}   = sprintf('Psw%d', k);
    sideNames{k} = 'EV1';
    switchNames{k} = sprintf('S%d', k);

    condNames{k+8} = sprintf('Pcond%d_2', k);
    swNames{k+8}   = sprintf('Psw%d_2', k);
    sideNames{k+8} = 'EV2';
    switchNames{k+8} = sprintf('S%d', k);
end

%% LOAD ALL SIGNALS
CondSignals = cell(16,1);
SwSignals = cell(16,1);

for k = 1:16
    try
        CondSignals{k} = getLoggedVariable(condNames{k});
    catch ME
        warning('Could not load %s: %s', condNames{k}, ME.message);
    end

    try
        SwSignals{k} = getLoggedVariable(swNames{k});
    catch ME
        warning('Could not load %s: %s', swNames{k}, ME.message);
    end
end

%% DETERMINE A COMMON MEASUREMENT WINDOW
% Using a common interval makes switch-to-switch comparisons fair.
allSignals = [CondSignals; SwSignals];
allTimes = [];

for k = 1:numel(allSignals)
    sig = allSignals{k};

    if isa(sig, 'timeseries')
        tt = sig.Time(:);
        if ~isempty(tt) && all(isfinite(tt))
            allTimes = [allTimes; tt(1); tt(end)]; %#ok<AGROW>
        end
    end
end

if isempty(allTimes)
    error('No timeseries data found. Check workspace variable names.');
end

% Use the latest signal start and earliest signal end to ensure
% all logged timeseries use the same measurement window.
signalStarts = [];
signalEnds = [];

for k = 1:numel(allSignals)
    sig = allSignals{k};
    if isa(sig, 'timeseries')
        tt = sig.Time(:);
        if ~isempty(tt)
            signalStarts(end+1,1) = tt(1); %#ok<SAGROW>
            signalEnds(end+1,1) = tt(end); %#ok<SAGROW>
        end
    end
end

t_measure_start = max(t_start, max(signalStarts));
t_measure_end = min(t_end_requested, min(signalEnds));

if t_measure_end <= t_measure_start
    error('No common measurement window available for all signals.');
end

fprintf('\nMeasurement window: %.6f to %.6f s\n', ...
    t_measure_start, t_measure_end);
fprintf('Duration: %.6f s\n', t_measure_end-t_measure_start);

%% CALCULATE AVERAGE CONDUCTION AND SWITCHING LOSSES
ConductionLoss_W = nan(16,1);
SwitchingLoss_W = nan(16,1);
TotalLoss_W = nan(16,1);

for k = 1:16

    % Conduction signal: instantaneous power in watts
    try
        ConductionLoss_W(k) = averageLoggedSignal( ...
            CondSignals{k}, 'power', ...
            t_measure_start, t_measure_end);
    catch ME
        warning('%s: conduction loss unavailable: %s', ...
            condNames{k}, ME.message);
    end

    % Switching signal: cumulative energy or instantaneous power
    try
        SwitchingLoss_W(k) = averageLoggedSignal( ...
            SwSignals{k}, pswMode, ...
            t_measure_start, t_measure_end);
    catch ME
        warning('%s: switching loss unavailable: %s', ...
            swNames{k}, ME.message);
    end

    if isfinite(ConductionLoss_W(k)) && ...
            isfinite(SwitchingLoss_W(k))
        TotalLoss_W(k) = ...
            ConductionLoss_W(k) + SwitchingLoss_W(k);
    end
end

%% CREATE SWITCH-WISE TABLE
Results = table( ...
    string(sideNames), ...
    string(switchNames), ...
    string(condNames), ...
    ConductionLoss_W, ...
    string(swNames), ...
    SwitchingLoss_W, ...
    TotalLoss_W, ...
    repmat(t_measure_start,16,1), ...
    repmat(t_measure_end,16,1), ...
    'VariableNames', { ...
    'Side', 'Switch', 'ConductionVariable', 'ConductionLoss_W', ...
    'SwitchingVariable', 'SwitchingLoss_W', 'TotalLoss_W', ...
    'WindowStart_s', 'WindowEnd_s'});

fprintf('\n========== SWITCH-WISE LOSS SUMMARY ==========\n');
disp(Results);

%% SIDE-WISE TOTALS
EV1_cond = sumComplete(ConductionLoss_W(1:8));
EV1_sw   = sumComplete(SwitchingLoss_W(1:8));
EV1_total = sumComplete(TotalLoss_W(1:8));

EV2_cond = sumComplete(ConductionLoss_W(9:16));
EV2_sw   = sumComplete(SwitchingLoss_W(9:16));
EV2_total = sumComplete(TotalLoss_W(9:16));

SideTotals = table( ...
    ["EV1"; "EV2"], ...
    [EV1_cond; EV2_cond], ...
    [EV1_sw; EV2_sw], ...
    [EV1_total; EV2_total], ...
    'VariableNames', { ...
    'Side', 'TotalConductionLoss_W', ...
    'TotalSwitchingLoss_W', 'TotalSemiconductorLoss_W'});

fprintf('\n========== SIDE-WISE TOTALS ==========\n');
disp(SideTotals);

%% EXPORT RESULTS
writetable(Results, 'IGBT_Combined_Loss_Summary.csv');
writetable(SideTotals, 'IGBT_Side_Loss_Totals.csv');

fprintf('\nSaved: IGBT_Combined_Loss_Summary.csv\n');
fprintf('Saved: IGBT_Side_Loss_Totals.csv\n');

%% STACKED BAR CHART
% Each bar is one switch.
% Lower segment: conduction loss.
% Upper segment: switching loss.

labels = strings(16,1);

for k = 1:8
    labels(k) = sprintf('EV1-S%d', k);
    labels(k+8) = sprintf('EV2-S%d', k);
end

figure('Color','w','Name','Switch-wise Combined Losses');

barData = [ConductionLoss_W, SwitchingLoss_W];
h = bar(1:16, barData, 'stacked');

h(1).FaceColor = [0.15 0.45 0.75]; % Blue: conduction
h(2).FaceColor = [0.90 0.40 0.20]; % Orange: switching

xticks(1:16);
xticklabels(labels);
xtickangle(45);

xlabel('Switch');
ylabel('Average loss (W)');
title('Conduction and Switching Loss Contribution per Switch');
legend({'Conduction loss','Switching loss'}, ...
    'Location','northoutside','Orientation','horizontal');

grid on;
box on;

% Save high-resolution figure
exportgraphics(gcf, 'IGBT_Combined_Loss_Barchart.png', ...
    'Resolution', 300);

fprintf('Saved: IGBT_Combined_Loss_Barchart.png\n');

%% ================= LOCAL FUNCTIONS =================

function value = getLoggedVariable(variableName)
% Retrieve a workspace variable or a SimulationOutput property.

    ws = evalin('base','whos');
    names = {ws.name};

    if any(strcmp(names, variableName))
        value = evalin('base', variableName);
        return;
    end

    for j = 1:numel(ws)
        if strcmp(ws(j).class, 'Simulink.SimulationOutput')
            simOut = evalin('base', ws(j).name);

            try
                value = simOut.get(variableName);
                return;
            catch
            end

            try
                value = simOut.(variableName);
                return;
            catch
            end
        end
    end

    error('Variable %s not found.', variableName);
end

function avg = averageLoggedSignal(sig, mode, tStart, tEnd)
% Average a logged power timeseries or cumulative-energy timeseries.
% A scalar is interpreted as an already-calculated average in watts.

    if isnumeric(sig) && isscalar(sig) && isfinite(sig)
        avg = double(sig);
        return;
    end

    if ~isa(sig, 'timeseries')
        error('Expected a timeseries or a scalar average in watts.');
    end

    t = sig.Time(:);
    x = squeeze(sig.Data);
    x = x(:);

    if numel(t) ~= numel(x) || numel(t) < 2
        error('Invalid timeseries length.');
    end

    % Sort and remove duplicate timestamps
    [t, order] = sort(t);
    x = x(order);
    [t, uniqueIdx] = unique(t, 'stable');
    x = x(uniqueIdx);

    if tStart < t(1) || tEnd > t(end)
        error('Requested measurement window exceeds logged time range.');
    end

    if strcmp(mode, 'cumulativeEnergy')
        % Cumulative energy is in joules; average power = Delta E / Delta t
        E_start = interp1(t, x, tStart, 'linear');
        E_end = interp1(t, x, tEnd, 'linear');

        avg = (E_end - E_start) / (tEnd - tStart);

    elseif strcmp(mode, 'power')
        % Instantaneous power is in watts; integrate over the window.
        interior = t > tStart & t < tEnd;

        tw = [tStart; t(interior); tEnd];
        pw = [interp1(t,x,tStart,'linear'); ...
              x(interior); ...
              interp1(t,x,tEnd,'linear')];

        avg = trapz(tw,pw) / (tEnd-tStart);

    else
        error('Unknown mode: %s', mode);
    end
end

function s = sumComplete(v)
% Return a total only if every switch result is available.
    if all(isfinite(v))
        s = sum(v);
    else
        s = NaN;
    end
end
