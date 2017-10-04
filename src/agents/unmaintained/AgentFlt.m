classdef AgentFlt < Agent
    %AGENTFLT Base template for agent wrappers (filters).
    %
    %   This class is intended to be eventually replaced by EnvironmentFlt.
    %
    %   Method calls to init() and step() are not forwarded to the wrapped
    %   agent and need to be implemented by the derived class. Other method
    %   calls are just directly forwarded by the default implementations.
    %
    %   Logging is disabled in the filter object but operates normally in
    %   the wrapped Agent object (as long as the re-implementation of
    %   init() forwards the logLevel flag directly to the wrapped object).
    
    % TODO: This class could be, in principle, also inherited from
    % Environment, which might be way cleaner, esp. in lookahead cases.
    
    
    properties
        
        % the wrapped Agent object
        agent;
        
    end
    
    
    methods
        
        function this = AgentFlt( agent )
            this.agent = agent;
        end
        
        
        % NOTE: the wrapped agent must be still initialized by the derived
        % implementation!
        function this = init( this, seed, props, logLevel, logInterval )
            
            % init 'this' (no logging)
            this = init@Agent( this, seed, props, 0, logInterval );
            
        end
        
        function this = improve( this )
          this.agent = improve( this.agent );
          this = improve@Agent( this );
        end
        
        function this = reset( this )
            this = reset@Agent( this );
            this.agent = reset( this.agent );
        end
        
        function this = newEpisode( this )
            this = newEpisode@Agent( this );
            this.agent = newEpisode( this.agent );
        end
        
        
        function this = setLearning( this, learning )
            this.agent = setLearning( this.agent, learning );
        end
        
        function V = getV( this )
            V = getV( this.agent );
        end
        
        function Q = getQ( this )
            Q = getQ( this.agent );
        end
        
        function Pi = getPi( this )
            Pi = getPi( this.agent );
        end
        
        function logs = getLogs( this )
            logs = getLogs( this.agent );
        end
        
    end
    
end
