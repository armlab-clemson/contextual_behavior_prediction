% MIT License
%
% Copyright (c) 2020 Jasprit Singh Gill (jaspritsgill@gmail.com)
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.

% contextual IMM program

ctx_imm = SLContextualBehaviorPredIMM(Ts_bp);
% thresholds - current lane threshold, next lane dist threshold and next
% lane velocity threshold representing diff between self vel & follow veh
% velocity. Vf - Vr < -1 (for a passive driver), Vf - Vr < 3 for aggressive
% driver. This means that aggressive driver is willing to accept a lane
% change gap even if the vehicle following in that lane has a higher speed
% to cut in.
ctx_imm.driverThresholds = [60 5 3; 60 15 -1];
ctx_imm.driverTypes = [0.5 0.5];

sigma_r = 0.05;

if aggressive_driver_use_case == true
    initial_front_car_distance = 100;
    leftLaneFollowingVehicleInitPosition = -106;
else
    initial_front_car_distance = 80;
    leftLaneFollowingVehicleInitPosition = -25;
end

for i = 1:length(simtime)
    t = simtime(i);
    if t < 20
        front_car_distance = initial_front_car_distance - 3.33 * t;
    end
        
    % Left lane vehicle position and corresponding context update
    leftLaneVehiclePosition = leftLaneFollowingVehicleInitPosition + 15*t;
    dist_LV = ctx_imm.combined_estimate(1) - leftLaneVehiclePosition;
    no_of_filters = length(ctx_imm.elementalFilters);
    
    %context vector - first 6 are distances and the next two are
    %velcocities with following vehicles in the adjoining lane.
    context = [100 100 100 100 100 100 15 15]';
    
    %comment following to remove the front vehicle
    context(3) = front_car_distance;
    
    %comment folling to remove the left lane vehicle
    context(2) = dist_LV;
    if t == 11.9
        context(2) = dist_LV;
    end
    
    ctx_imm.extractContext(context);
    ctx_imm.gapAcceptancePolicy();
    
    ctx_imm.calculateBehaviorProbabilityTransitionMatrix();
    
    % mix initial states for the current cycle first
    ctx_imm.mixEstimates();
    
    filter_traj(i).mark_trans_matrix = ctx_imm.markov_transition_matrix;
    filter_traj(i).mix_init_states = ctx_imm.mixed_init_state;
    % predict
    ctx_imm.predict(0);
    
    % correct and update probabilistic weights
    
    if enable_measurement_noise == true
        y_tilde = groundTruth(i).y_tilde;
    else
        y_tilde = groundTruth(i).y_gt;
    end
    ctx_imm.correct(y_tilde);
    
    % combined estimates
    [comb_x, comb_p] = ctx_imm.calculateCombinedEstimate();
    ctx_imm.driverUpdate();
    
    filter_traj(i).prenormalizedWts = ctx_imm.getFilterNonNormalizedWeights()';
    filter_traj(i).weights = ctx_imm.getFilterWeights()';
    filter_traj(i).likelihoods = ctx_imm.getFilterLikelihoods()';
    filter_traj(i).estimates = ctx_imm.getFilterEstimates();
    filter_traj(i).err = ctx_imm.getFilterErrors();
    filter_traj(i).driver_weights = ctx_imm.driverTypes';
    filter_traj(i).combined_estimates = comb_x;
    filter_traj(i).combined_p = comb_p;
    filter_traj(i).gapAcceptance = ctx_imm.gapAcceptance;
    filter_traj(i).context = context;
    filter_traj(i).leftLaneVehPosn = leftLaneVehiclePosition;
    filter_traj(i).distLLV = dist_LV;
    filter_traj(i).d1GapAcceptPolicy = ctx_imm.driver1GapAcceptance;
    filter_traj(i).d2GapAcceptPolicy = ctx_imm.driver2GapAcceptance;
    filter_traj(i).predictions = ctx_imm.getPredictions();
    filter_traj(i).front_car_position = comb_x(1) + front_car_distance;
end

post_processing_plots;
