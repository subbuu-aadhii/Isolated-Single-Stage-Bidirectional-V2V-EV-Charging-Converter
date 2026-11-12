% Preliminary IGBT conduction-loss lookup
% VGE = 15 V, Tj = 25 deg C
% Values are approximate visual readings from supplied graph.
% Replace with digitized values from the exact device datasheet
% before using for a final quantitative comparison.

Ic_bp  = [0 5 10 20 40 60 80 100 120];  % A
Vce_bp = [0.75 0.92 1.00 1.16 1.43 ...
          1.62 1.80 1.98 2.15];        % V
Ic_bp1 = [0 10 20 40 60 80 100 120];  % A
Eon_mJ  = [0 0.30 0.80 1.75 2.70 4.10 6.20 8.90];
Eoff_mJ = [0 0.25 0.55 1.15 1.75 2.35 3.00 3.60];