classdef AgentHybridNAC < AgentNaturalActorCritic
  %AGENTHYBRIDNAC Generic hybrid natural actor-critic
  %
  %   Generic hybrid natural actor-critic using the Gibbs policy.
  %   The additional parameters are:
  %     greediness
  %       range: [1,Inf), 1 = standard gradient, ->Inf = emulate LSPI (?)
  %     temperature
  %       range: [0,1], amount of added Boltzmann explorativity
  %     consistency
  %       range: [0,1], exploration constistency
  %   The standard natural actor-critic algorithm is obtained with:
  %     greediness=1, temperature=0, consistency=0
  
  properties (Access=protected)
    
    % greediness: 1 = standard NAC, ->Inf = emulate LSPI
    greediness;
    
  end
  
  methods
    
    function this = AgentHybridNAC( critic, varargin )
      
      args = inputParser; args.KeepUnmatched = true;
      args.addParamValue( 'greediness', 0, @(x) (isnumeric(x) && isscalar(x) && x >= 1 && ~isinf(x) ) );
      args.addParamValue( 'temperature', 0, @(x) (isnumeric(x) && isscalar(x) && x >= 0 && x <= 1) );
      args.addParamValue( 'consistency', 0, @(x) (isnumeric(x) && isscalar(x) && x >= 0 && x <= 1) );
      args.parse( varargin{:} );
      
      this = this@AgentNaturalActorCritic( critic, args.Unmatched );
      
      this.greediness = args.Results.greediness;
      
    end
    
  end
  
  methods (Access=protected)
    
    % re-implement the gradient step implementation
    function this = actorUpdate( this )
      
      % update the critic
      this.critic = computeV( this.critic );
      
      % step (temporary hack)
      this.theta = this.theta / this.greediness + this.greediness * this.stepsize * getQ(this)';
      
    end
    
  end
  
end

