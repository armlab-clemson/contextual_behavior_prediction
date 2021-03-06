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

classdef XKalmanFilter < handle %& matlab.mixin.Copyable
    properties
        Ts
        predicted_state
        predicted_P
        
        estimatedState
        estimate_P
        % Measurement noise
        R
        % Process noise
        Q
        % Motion model
        mm
        % likelihood
        likelihood
        % error innovation
        err_innov
        % error covariance
        err_cov
        % experimental
        weight
        nonNormalizedWeight
        no_of_states
    end
    
    methods
        function self = XKalmanFilter(Ts, motionmodel)
            if nargin == 0
                Ts = 0.1;
                motionmodel = LinearizedBicycleModel();
            elseif nargin == 1
                motionmodel = LinearizedBicycleModel(Ts);
            end
                
            self.Ts = Ts;
            self.mm = motionmodel;
            self.weight = 1;
            self.nonNormalizedWeight = 1;
            self.estimatedState = motionmodel.states;
            self.estimate_P = eye(length(self.estimatedState));
            self.predicted_state = motionmodel.states;
            self.predicted_P = eye(length(self.estimatedState));
            self.likelihood = 0;
            self.Q = self.estimate_P*0.001;
            self.err_innov = motionmodel.output_states;
            self.R = eye(length(self.err_innov))*0.0025;
            self.err_cov = self.R;
            self.no_of_states = length(self.estimatedState);
        end
        
        function self = updateNoiseStatistics(self, Q, R)
            self.Q = Q;
            self.R = R;
        end
        
        function setInitialConditions(self, X, P)
                self.estimatedState = X;
                self.estimate_P = P;
                self.predicted_state = X;
                self.predicted_P = P;
                self.mm.reset(X);
        end
 
        function [x_prop, p_prop] = predict(self, u, x, P)
            if nargin == 2
                % Use the last propagated states for propagating further
                x = self.predicted_state;
                P = self.predicted_P;
            end
            x_prop =  self.mm.propagate(x, u);
            
            % The first term in the covariance equation can be moved into
            % motion model for abstraction, but it will make the motion
            % model closely coupled with KF
            F = self.mm.linearizedDiscreteStateTransitionMatrix(x, u);
            p_prop = (F * P * F') + self.Ts*self.Q;
            
            %also predict for the next few time steps

            self.predicted_state = x_prop;
            self.predicted_P = p_prop;
        end
        
        function [x_plus, p_plus] = correct(self, y_tilde, x_prop, P_prop)
            if nargin == 2
                x_prop = self.predicted_state;
                P_prop = self.predicted_P;
            end
                       
            %correct
            yhat_minus = self.mm.estimatedMeasurement(x_prop, 0);
            self.err_innov = y_tilde - yhat_minus;    %residual
            
            % Following and the first term of error cov can be moved into
            % motion model, but it make the motion model coupled closely
            % with kalman filter and we wan't to keep that indepent.
            Ck = self.mm.getOutputMatrix();
            self.err_cov = Ck * P_prop *Ck' + self.R;    %residual covariance
            K = P_prop * Ck' * inv(self.err_cov);
            x_plus = x_prop + K * self.err_innov;
            p_plus = (eye(length(x_prop)) - K * Ck) * P_prop;
            self.estimatedState = x_plus;
            self.mm.setStates(x_plus);
            self.estimate_P = p_plus;
           
            % after correction, predicted and estimated states should be
            % the same.
            self.predicted_state = x_plus;
            self.predicted_P = p_plus;
            
            self.likelihood = 1/sqrt(det(2*pi*self.err_cov)) ...
                * exp(-1/2 * self.err_innov'* inv(self.err_cov) * self.err_innov);
            
%             self.nonNormalizedWeight = self.weight * self.likelihood;

        end
    end
end