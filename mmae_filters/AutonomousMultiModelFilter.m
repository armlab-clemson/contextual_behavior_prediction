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

classdef AutonomousMultiModelFilter < handle
    properties
        Ts
        elementalFilters
%         elementalFilterLikelihoods
%         estimates_elementalFilters
%         P_estimates_elementalFilters
        weights
        combined_estimate
        P_combined_estimate
        no_of_states
    end
    
    methods
        function self = AutonomousMultiModelFilter(Ts)
            if nargin == 0
                Ts = 0.1;
            end
            self.Ts = Ts;
            self.no_of_states = 4;
            % By default, initializes everything to double empty, elemental
            % filters need to be initialized to XKalmanFilter empty array.
            % Unfortunately it is not supported for code generation. So we
            % need to use a cell array. However, dot indexing is not
            % supported when using a for loop. So its best to index it with
            % an iterator (like i) and then set the elements. Second, the
            % compiler gives an error if the array of objects are
            % initialized dynamically. So the best 
%             self.elementalFilters = {};
            self.combined_estimate = zeros(self.no_of_states, 1);
            self.P_combined_estimate = eye(self.no_of_states);
        end
        
        function addElementalFilter(self, elementalFilter)
            num_filters = length(self.elementalFilters) + 1;
            self.elementalFilters{num_filters} = elementalFilter;
            self.resetFilterWeights();
        end
        
        function resetFilterWeights(self)
            num_filters = length(self.elementalFilters);
            for i = 1:num_filters
                flt = self.elementalFilters{i};
                flt.weight = 1/num_filters;
            end
        end
        
        function predict(self, u, X, P)
            if nargin == 2
                X = self.combined_estimate;
                P = self.P_combined_estimate;
            end
            
            for i = 1: length(self.elementalFilters)
                flt = self.elementalFilters{i};
                flt.predict(u);
            end            
        end
        
        function correct(self, y_tilde, X, P)
            if nargin == 2
                X = self.combined_estimate;
                P = self.P_combined_estimate;
            end
            
            for i = 1: length(self.elementalFilters)
                flt = self.elementalFilters{i};
                flt.correct(y_tilde);
            end
            self.updateWeights();
        end
        
        function updateWeights(self)
            normalizer = 0;
            for i = 1: length(self.elementalFilters)
                flt = self.elementalFilters{i};
                flt.nonNormalizedWeight = flt.weight * flt.likelihood;
                normalizer = normalizer + flt.nonNormalizedWeight;
            end
                
            for i = 1: length(self.elementalFilters)
                flt = self.elementalFilters{i};
                flt.weight = flt.nonNormalizedWeight/normalizer;
            end
        end
        
        function wts = getFilterWeights(self)
            num_filters = length(self.elementalFilters);
            wts = zeros(1, num_filters);
            for i = 1:num_filters
                flt = self.elementalFilters{i};
                wts(i) = flt.weight;
            end
        end
        
        function lhd = getFilterLikelihoods(self)
            num_filters = length(self.elementalFilters);
            lhd = zeros(1, num_filters);
            for i = 1:num_filters
                flt = self.elementalFilters{i};
                lhd(i) = flt.likelihood;
            end
        end
        
        function wts = getFilterNonNormalizedWeights(self)
            num_filters = length(self.elementalFilters);
            wts = zeros(1, num_filters);
            for i = 1:num_filters
                flt = self.elementalFilters{i};
                wts(i) = flt.nonNormalizedWeight;
            end
        end

        function err = getFilterErrors(self)
            num_filters = length(self.elementalFilters);
            flt = self.elementalFilters{1};
            no_of_observ = length(flt.mm.output_states);
            err = zeros(no_of_observ, 1, num_filters);
            for i = 1:num_filters
                flt = self.elementalFilters{i};
                err(:,:, i) = flt.err_innov;
            end
        end
        
        
        % functions that will have to be overridden in the super class due
        % to length of the states. 
        
        function setInitialConditions(self, X, P)
            for i = 1:length(self.elementalFilters)
                flt = self.elementalFilters{i};
                flt.setInitialConditions(X, P);
            end
        end
        
        function [comb_est, comb_P] = calculateCombinedEstimate(self)
            comb_est = [0 0 0 0]';
            for i = 1: length(self.elementalFilters)
                flt = self.elementalFilters{i};
                estimate = flt.estimatedState(1:self.no_of_states);
                comb_est = comb_est + flt.weight * estimate;
            end
            self.combined_estimate = comb_est;
            
            % calculate combined covariance
            
            comb_P = zeros(4);
            for i = 1: length(self.elementalFilters)
                flt = self.elementalFilters{i};
                estimate = flt.estimatedState(1:self.no_of_states);
                est_P = flt.estimate_P(1:self.no_of_states, 1:self.no_of_states);
                err = estimate - comb_est;
                comb_P = comb_P + flt.weight * (err * err' + est_P);
            end
            self.P_combined_estimate = comb_P;
        end
        
        function est_cov = getFilterEstimateCovariances(self)
            num_filters = length(self.elementalFilters);
            est_cov = zeros(self.no_of_states, self.no_of_states, num_filters);
            for i = 1:num_filters
                flt = self.elementalFilters{i};
                est_cov(:,:, i) = flt.predicted_P(1:self.no_of_states, 1:self.no_of_states);
            end
        end
        
        function est = getFilterEstimates(self)
            num_filters = length(self.elementalFilters);
            est = zeros(4, 1, num_filters);
            for i = 1:num_filters
                flt = self.elementalFilters{i};
                est(:,:, i) = flt.predicted_state(1:self.no_of_states);
            end
        end

    end
end