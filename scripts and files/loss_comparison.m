% Compute now before running simulation:
losses_config1 = [62.9, 68.6, 0, 0, 38.6, 46.3, 55.9, 0];
losses_config2 = [62.9, 68.6, 38.6, 46.3, 0, 0, 55.9, 0];
losses_timeavg = (losses_config1 + losses_config2) / 2;

active1 = losses_config1(losses_config1 > 1);
active2 = losses_config2(losses_config2 > 1);
activeavg = losses_timeavg(losses_timeavg > 1);

CV1   = std(active1)/mean(active1);
CV2   = std(active2)/mean(active2);
CVavg = std(activeavg)/mean(activeavg);

fprintf('CV Config1: %.4f\n', CV1);
fprintf('CV Config2: %.4f\n', CV2);
fprintf('CV TimeAvg: %.4f\n', CVavg);
% CVavg should be noticeably lower than CV1