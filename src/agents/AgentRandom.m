classdef AgentRandom < Agent
  %AGENTRANDOM A dummy agent that selects uniformly random actions.
  %
  %   This agent works only with actions list based environments. The
  %   observation is ignored and a uniformly random action is drawn from
  %   the provided action list.
  
  
  methods
    
    function [this, action] = step( this, reward, observation, actions )
      
      % episode ended?
      if isempty(observation); action = []; return; end
      
      % verify that actions were provided (environment must use action lists)
      assert( ~isempty(actions) );
        
      % we have an explicit action list, draw an index
      action = floor(this.rstream.rand() * size(actions,1) + 1);
      
    end
    
  end
  
end
