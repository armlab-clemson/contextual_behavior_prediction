classdef MotionModel < handle
    properties(Abstract)
        Ts
        states
        propagated_states
        
        % discretized matrices
        Fd_matrix
        Bd_matrix
        Cd_matrix
        Dd_matrix
    end
    methods (Abstract)
        x_apriori = propagate(obj, x, u)
        
        % following should return a jacobian in case of non linear motion
        % models
        F = linearizedDiscreteStateTransitionMatrix(obj, x, u)
    end
end