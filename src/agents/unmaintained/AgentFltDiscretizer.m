classdef AgentFltDiscretizer < AgentFlt
    %AGENTFLTDISCRETIZER Discretize and flatten the state-action space.
    %
    %   NOTE: Currently only flattening is implemented.
    
    
    methods
        
        function this = AgentFltDiscretizer( agent )
            this = this@AgentFlt( agent );
        end
        
        
        function this = init( this, seed, props, logLevel, logInterval )
            this = init@AgentFlt( this, ...
                seed, props, logLevel, logInterval );
            
            assert( isempty(props.oaRanges), ...
                'Observation-dependent action ranges are not supported!' );
            
            % only discrete variables allowed at the moment
            assert( all(this.props.observationTypes == 'd') && ...
                all(this.props.actionTypes == 'd') );
            
            % compute observation and action dims of the outer space
            this.oDims = diff( this.props.observationRanges1, 1, 2 )';
            this.aDims = diff( this.props.actionRanges1, 1, 2 )';
            
            % compute state and action counts for the inner space
            this.oCount = prod( this.oDims );
            this.aCount = prod( this.aDims );
            
            % compute a props struct for the inner space
            propsInner.observationDim = 1;
            propsInner.actionDim = 1;
            propsInner.observationTypes = 'd';
            propsInner.actionTypes = 'd';
            propsInner.observationRanges = [1 this.oCount];
            propsInner.actionRanges = [1 this.aCount];
            propsInner.oaRanges = [];
            
            % init the wrapped Agent
            this.agent = init( this.agent, seed, propsInner, ...
                logLevel, logInterval );
            
        end
        
        function [this, action] = step( this, reward, observation, actions )
            [this, action] = step@Agent( this, reward, observation, actions );
            
            if ~isempty(observation)
            
                % discretize and flatten the observation (NOTE:
                % discretization is not currently implemented)
                observationC = num2cell( ...
                    observation - this.props.observationRanges1(:,1)' + 1 );
                observation = sub2ind( [this.oDims 1], observationC{:} );
                
            end
            
            % forward the step call
            [this.agent, action] = step( this.agent, reward, observation, [] );
            
            % continuize and unflatten the action (NOTE: continuization is
            % not currently implemented)
            [actionC{1:length(this.aDims)}] = ind2sub(this.aDims, action);
            action = this.props.actionRanges1(:,1)' + [actionC{:}] - 1;
            
        end
        
    end
    
    
    % private properties begin
    
    
    properties (Access=private)
        
        % observation and action dimensions of the outer space
        oDims, aDims;
        
        % observation and action counts for the inner space
        oCount, aCount;
        
    end
    
end
