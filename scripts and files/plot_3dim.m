clear;
clc;
close all;


model = 'openloop_ev2_rload';

load_system(model);

fs = 25e3;                        

Llk1 = 0.3015e-6;                  
Llk2 = 0.3015e-6;                  

D_values = 0.20:0.1:0.60;


ratio_values = 0.50:0.5:1.50;


simTime = 1.0;                     

% Steady-state window
steady_start = 0.8;                
steady_end   = 1.0;               

Gain = NaN(length(ratio_values), length(D_values));

C1_values = zeros(length(ratio_values),1);
C2_values = zeros(length(ratio_values),1);
fr_values = zeros(length(ratio_values),1);


for i = 1:length(ratio_values)

    ratio = ratio_values(i);
    fr = fs / ratio;

    fr_values(i) = fr;

    C1 = 1 / ((2*pi*fr)^2 * Llk1);
    C2 = 1 / ((2*pi*fr)^2 * Llk2);

    C1_values(i) = C1;
    C2_values(i) = C2;
    fprintf('Frequency ratio fs/fr = %.2f\n', ratio);
    fprintf('Resonant frequency fr  = %.3f Hz\n', fr);
    fprintf('C1 = %.6e F\n', C1);
    fprintf('C2 = %.6e F\n', C2);
    for j = 1:length(D_values)
        D = D_values(j);

        fprintf('Running: fs/fr = %.2f, D = %.3f\n', ...
                ratio, D);

        in = Simulink.SimulationInput(model);

        in = in.setVariable('D', D);
        in = in.setVariable('C1', C1);
        in = in.setVariable('C2', C2);

        in = in.setVariable('fs', fs);
        in = in.setVariable('fr', fr);


      
        in = in.setModelParameter( ...
            'StopTime', num2str(simTime), ...
            'LoadInitialState', 'off');

        try

            out = sim(in);

        catch ME

            fprintf('\n!!! SIMULATION ERROR !!!\n');
            fprintf('fs/fr = %.2f\n', ratio);
            fprintf('D = %.3f\n', D);
            fprintf('%s\n\n', ME.message);

            Gain(i,j) = NaN;

            continue;

        end

        try

            VB1_ts = out.VB1_ws;
            VB2_ts = out.VB2_ws;

        catch ME

            fprintf('\n!!! VB1_ws / VB2_ws NOT FOUND !!!\n');
            fprintf('Check the To Workspace block names.\n');
            fprintf('They must be VB1_ws and VB2_ws.\n\n');

            Gain(i,j) = NaN;

            continue;

        end
        t1 = VB1_ts.Time;
        t2 = VB2_ts.Time;

        VB1 = squeeze(VB1_ts.Data);
        VB2 = squeeze(VB2_ts.Data);

        idx1 = (t1 >= steady_start) & (t1 <= steady_end);
        idx2 = (t2 >= steady_start) & (t2 <= steady_end);


        VB1_ss = mean(VB1(idx1), 'omitnan');
        VB2_ss = mean(VB2(idx2), 'omitnan');


        if abs(VB1_ss) > 1e-9

            Gain(i,j) = VB2_ss / VB1_ss;

        else

            Gain(i,j) = NaN;

        end

        fprintf('VB1 steady-state = %.4f V\n', VB1_ss);
        fprintf('VB2 steady-state = %.4f V\n', VB2_ss);
        fprintf('Voltage Gain     = %.6f\n\n', Gain(i,j));

    end
end

[D_grid, ratio_grid] = meshgrid(D_values, ratio_values);

disp(Gain);

figure('Name','3D Voltage Gain Plot', ...
       'NumberTitle','off');

surf(D_grid, ratio_grid, Gain);

xlabel('Duty Ratio, D', ...
       'FontSize',12, ...
       'FontWeight','bold');

ylabel('Frequency Ratio, f_s/f_r', ...
       'FontSize',12, ...
       'FontWeight','bold');

zlabel('Voltage Gain, V_{B2}/V_{B1}', ...
       'FontSize',12, ...
       'FontWeight','bold');

title('3D Voltage Gain Evaluation', ...
      'FontSize',14, ...
      'FontWeight','bold');

grid on;
shading interp;
colorbar;

view(135,30);


save('3D_voltage_gain_results.mat', ...
     'D_values', ...
     'ratio_values', ...
     'D_grid', ...
     'ratio_grid', ...
     'Gain', ...
     'C1_values', ...
     'C2_values', ...
     'fr_values', ...
     'fs');


saveas(gcf,'3D_voltage_gain_plot.fig');

exportgraphics(gcf, ...
               '3D_voltage_gain_plot.png', ...
               'Resolution',300);
fprintf('Simulation time per point : %.2f s\n', simTime);
fprintf('Steady-state window       : %.2f - %.2f s\n', ...
        steady_start, steady_end);

fprintf('\nFiles saved:\n');
fprintf('3D_voltage_gain_results.mat\n');
fprintf('3D_voltage_gain_plot.fig\n');
fprintf('3D_voltage_gain_plot.png\n');