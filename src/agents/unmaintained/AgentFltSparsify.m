classdef AgentFltSparsify < AgentFlt
    %AGENTFLTSPARSIFY Sparsify a flat and discrete environment.
    
    
    methods
        
        function this = AgentFltSparsify( agent )
            this = this@AgentFlt( agent );
        end
        
        
        function this = init( this, seed, props, logLevel, logInterval )
            this = init@AgentFlt( this, ...
                seed, props, logLevel, logInterval );
            
            assert( isempty(props.oaRanges), ...
                'Observation-dependent action ranges are not supported!' );
            
            % only a flat discrete environment is allowed
            assert( this.props.observationDim == 1 && this.props.actionDim == 1 && ...
              this.props.observationTypes == 'd' && this.props.actionTypes == 'd' && ...
              this.props.observationRanges(1) == 1 && this.props.actionRanges(1) == 1 );
            
            % compute state, action and state-action dimensions for the inner space
            this.sDim = diff( this.props.observationRanges1, 1, 2 );
            this.aDim = diff( this.props.actionRanges1, 1, 2 );
            this.saDim = this.sDim * this.aDim;
            
            % compute a props struct for the inner space
            propsInner.stateDim = this.sDim;
            propsInner.stateActionDim = this.saDim;
            propsInner.actionDim = 1;
            propsInner.actionTypes = 'd';
            propsInner.actionRanges = [1 this.aDim];
            
            % dummy
            propsInner.oaRanges = [];
            propsInner.observationDim = 1;
            propsInner.observationRanges = [1 1];
            propsInner.observationTypes = ['d'];
            
            % init the wrapped Agent
            this.agent = init( this.agent, seed, propsInner, ...
                logLevel, logInterval );
            
        end
        
        function [this, action] = step( this, reward, observation, actions )
            [this, action] = step@Agent( this, reward, observation, actions );
            
            if ~isempty(observation)
            
                % sparsify the observation (make it a row vector)
                sFeatures = zeros( 1, this.sDim ); sFeatures(observation) = 1;
                
                % generate the state-action feature matrix
                saFeatures = zeros( this.aDim, this.saDim );
                for action=1:this.aDim
                  saFeatures( action, (observation-1) * this.aDim + action ) = 1;
                end
                
            else
              
              sFeatures = []; saFeatures = [];
              
            end
            
            % forward the step call (action is not affected)
            [this.agent, action] = step( this.agent, reward, sFeatures, saFeatures );
            
        end
        
    end
    
    
    % private properties begin
    
    
    properties (Access=private)
        
        % dimensions for the inner space
        sDim, aDim, saDim;
        
    end
    
end
