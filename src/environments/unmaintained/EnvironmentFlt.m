classdef EnvironmentFlt < Environment
  %ENVIRONMENTFLT Base template for environment wrappers (filters).
  %
  %   !!! This class is not finished! Instead consider directly inheriting
  %   from the Environment class that you are intending to wrap !!!
  %     (on the other hand, such inheritance tends to become messy, e.g.,
  %     due to having different environment props on different inheritance
  %     levels. also the getAvailableActions() implementation in the Tetris
  %     classes ended up messy, due to the featurizer class needing to
  %     access the Tetris class' actions matrix before it is naturally
  %     constructed. having fully separate classes might be cleaner after
  %     all, although manually forwarding all method calls is still tedious
  %     and rigid. filter classes would become cleaner if all excess
  %     visualization etc. methods would be removed and placed into some
  %     other class, so as to minimize the amount of methods that need to
  %     be forwarded.)
  %     (again on the other hand, you should just treat public and
  %     protected property fields in implementations with the assumption
  %     that they might have changed by a derived class, just as you have
  %     to do in case of)
  %
  %   This class is intended to eventually replace AgentFlt. Rationale:
  %   This way the wrapper can have more direct communication with the
  %   environment, which are typically more specialized than agents. For
  %   example, environment-specific lookahead featurization is more natural
  %   to implement on the environment side.
  %
  %   Interactive visualization and stats method calls are _not_ forwarded.
  %   The user should instead direct these calls directly to the wrapped
  %   environment (available in the public property 'environment'). The
  %   intention is to eventually make this into just a signal filter that
  %   filters the signals passing through the step() calls. The associated
  %   environment properties need still to be redefined, though.
  %
  %   Logging is disabled in the filter object but operates normally in the
  %   wrapped Environment object.
  
  properties
    
    % the wrapped environment object
    environment;
    
  end
  
  
  methods
    
    function this = EnvironmentFlt( environment )
      this.environment = environment;
    end
    
  end
  
end

