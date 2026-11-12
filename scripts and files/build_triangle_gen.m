m%% build_triangle_gen.m
% Builds a pure Simulink HDL-compatible triangle wave generator
% inside your existing subsystem, replacing the MATLAB Function block.
% Run with your model OPEN.

mdl = 'closeloop_fyp_finalllllll_2024a';
sys = [mdl '/Subsystem'];   % path to your HDL subsystem

%% ── STEP 1: Delete old MATLAB Function block ─────────────────────────
try
    delete_block([sys '/MATLAB Function']);
    disp('Deleted old MATLAB Function block.');
catch
    disp('MATLAB Function block not found - skipping delete.');
end

%% ── STEP 2: Delete old Counter and Constant(N) if they exist ────────
try; delete_block([sys '/Counter Limited']); catch; end
try; delete_block([sys '/Constant']);        catch; end  % N=10 block

%% ── STEP 3: Add all new blocks ───────────────────────────────────────

% --- Counter Limited (0 to 7 for N=8) ---
add_block('simulink/Sources/Counter Limited', [sys '/TriCounter'], ...
    'uplimit',        '7', ...
    'tsamp',          '-1', ...       % inherited sample time
    'Position',       [100 300 160 330]);

% --- Constant: N/2 = 4 ---
add_block('simulink/Sources/Constant', [sys '/Half_N'], ...
    'Value',          '4', ...
    'OutDataTypeStr', 'uint16', ...
    'Position',       [100 370 160 400]);

% --- Relational Operator: count < N/2 ---
add_block('simulink/Logic and Bit Operations/Relational Operator', ...
    [sys '/IsRising'], ...
    'Operator',   '<', ...
    'Position',   [220 305 260 345]);

% --- Subtract N/2 from count (for falling slope) ---
add_block('simulink/Math Operations/Sum', [sys '/SubHalf'], ...
    'Inputs',         '+-', ...
    'OutDataTypeStr', 'uint16', ...
    'Position',       [220 370 260 410]);

% --- Gain for rising slope: 0.25 = 1/(N/2) ---
add_block('simulink/Math Operations/Gain', [sys '/GainRise'], ...
    'Gain',           '0.25', ...
    'OutDataTypeStr', 'fixdt(1,16,14)', ...
    'RndMeth',        'Floor', ...
    'SaturateOnIntegerOverflow', 'on', ...
    'Position',       [310 295 370 325]);

% --- Gain for falling slope: 0.25 ---
add_block('simulink/Math Operations/Gain', [sys '/GainFall'], ...
    'Gain',           '0.25', ...
    'OutDataTypeStr', 'fixdt(1,16,14)', ...
    'RndMeth',        'Floor', ...
    'SaturateOnIntegerOverflow', 'on', ...
    'Position',       [310 370 370 400]);

% --- Constant: -1 in Q1.14 ---
add_block('simulink/Sources/Constant', [sys '/ConstNeg1'], ...
    'Value',          '-1', ...
    'OutDataTypeStr', 'fixdt(1,16,14)', ...
    'Position',       [310 240 370 270]);

% --- Constant: +1 in Q1.14 ---
add_block('simulink/Sources/Constant', [sys '/ConstPos1'], ...
    'Value',          '1', ...
    'OutDataTypeStr', 'fixdt(1,16,14)', ...
    'Position',       [310 430 370 460]);

% --- Sum for rising: -1 + gain*count ---
add_block('simulink/Math Operations/Sum', [sys '/SumRise'], ...
    'Inputs',         '++', ...
    'OutDataTypeStr', 'fixdt(1,16,14)', ...
    'RndMeth',        'Floor', ...
    'SaturateOnIntegerOverflow', 'on', ...
    'Position',       [430 255 470 295]);

% --- Sum for falling: 1 - gain*(count-half) ---
add_block('simulink/Math Operations/Sum', [sys '/SumFall'], ...
    'Inputs',         '+-', ...
    'OutDataTypeStr', 'fixdt(1,16,14)', ...
    'RndMeth',        'Floor', ...
    'SaturateOnIntegerOverflow', 'on', ...
    'Position',       [430 375 470 415]);

% --- Switch: select rising or falling ---
add_block('simulink/Signal Routing/Switch', [sys '/TriSwitch'], ...
    'Criteria',       'u2 ~= 0', ...
    'OutDataTypeStr', 'fixdt(1,16,14)', ...
    'Position',       [540 290 590 410]);

%% ── STEP 4: Wire everything up ───────────────────────────────────────

% Counter → RelOp input 1
add_line(sys, 'TriCounter/1', 'IsRising/1',  'autorouting','on');
% Half_N  → RelOp input 2
add_line(sys, 'Half_N/1',    'IsRising/2',  'autorouting','on');

% Counter → SubHalf input 1
add_line(sys, 'TriCounter/1', 'SubHalf/1',   'autorouting','on');
% Half_N  → SubHalf input 2
add_line(sys, 'Half_N/1',    'SubHalf/2',   'autorouting','on');

% Counter → GainRise
add_line(sys, 'TriCounter/1', 'GainRise/1',  'autorouting','on');
% SubHalf → GainFall
add_line(sys, 'SubHalf/1',   'GainFall/1',  'autorouting','on');

% ConstNeg1 → SumRise input 1
add_line(sys, 'ConstNeg1/1', 'SumRise/1',   'autorouting','on');
% GainRise  → SumRise input 2
add_line(sys, 'GainRise/1',  'SumRise/2',   'autorouting','on');

% ConstPos1 → SumFall input 1
add_line(sys, 'ConstPos1/1', 'SumFall/1',   'autorouting','on');
% GainFall  → SumFall input 2
add_line(sys, 'GainFall/1',  'SumFall/2',   'autorouting','on');

% SumRise  → Switch input 1 (True/rising path)
add_line(sys, 'SumRise/1',   'TriSwitch/1', 'autorouting','on');
% IsRising → Switch input 2 (control)
add_line(sys, 'IsRising/1',  'TriSwitch/2', 'autorouting','on');
% SumFall  → Switch input 3 (False/falling path)
add_line(sys, 'SumFall/1',   'TriSwitch/3', 'autorouting','on');

%% ── STEP 5: Connect TriSwitch output to comparator (≥ block) ─────────
% Find the comparator block - it was previously connected to MATLAB Function
% Connect TriSwitch output to wherever triangle_gen 'y' was going
% You may need to manually connect TriSwitch/1 to your comparator input
disp('──────────────────────────────────────────');
disp('Blocks built and wired successfully!');
disp('');
disp('MANUAL STEP REQUIRED:');
disp('Connect TriSwitch/1 output to your comparator (≥) block input 2.');
disp('(This was previously the triangle_gen y output)');
disp('');
disp('Then verify scope shows triangle, then run:');
disp(['  makehdl(''' sys ''');']);