classdef Critic < handle
  %CRITIC Base class for critics
  
  % TODO: Factor some common code from LSPELambda and LSTDLambda into here.
  %
  % BUG: In Matlab implementations of some agents, the critic eligibility
  % trace might not be cleared between episodes. This should be done, eg,
  % in Agent.newEpisode().
  %
  % TODO: Rename reset() to init().
  
  
  properties
    
    % discount factor and eligibility trace strength
    gamma, lambda;
    
    % Ifactor * I is added to the main matrix before solving
    Ifactor;
    
    % forgetting factor
    beta;
    
    % mask for selecting active features
    featureMask;
    
    
    % dimensionality. this must be set before using the object.
    dim = NaN;
    
    
    % The current estimate of the V function. Either 1) always call
    % computeV() before accessing this property, or 2) enable online
    % estimation.
    %
    % NOTE: a forget() call does not clear this property!
    %
    %   (column double vector) V
    V;
    
  end
  
  properties (Access=protected)
    
    % Methods to use for batch solving and online tracking of V
    batchMethod, onlineMethod;
    
    % Is V up to date? type: logical
    Vok = false;
    
  end
  
  
  methods (Abstract)
    
    % Reset the critic. This needs to be called before first use. this.dim
    % must have been set before calling this method.
    this = reset( this )
    
    % Forget statistics due to the actor having changed.
    this = forget( this )
    
    % Start a new episode.
    this = newEpisode( this )
    
    % Get condition of the main matrix.
    cnd = getCond( this )
    
    % Incorporates one transition sample into the internal model.
    %
    %   (column double vector) s0
    %     State feature activations before transition.
    %
    %   (column double vector) s1
    %     State-action feature activations transition.
    %
    %   (double) r
    %     Immediate reward
    this = step( this, s0, s1, r )
    
    % Add externally accumulated data to the statistics. The eligibility
    % trace will not be valid after this call.
    this = addData( this, data )
    
    % Finalize the current learning iteration of the critic, if applicable.
    this = finalize( this, varargin )
    
    % Compute the V-function and store it into V.
    %
    %   (string) batchMethod
    %     Name of the method to be used for solving, or [] to use the
    %     internally set method.
    this = computeV( this, batchMethod )
    
  end
  
end
