classdef AgentFltSparsifyGridEBLookahead < AgentFlt
    %AGENTFLTSPARSIFYEBLOOKAHEAD
    %
    %   Sparsify and introduce state value lookahead into a flattened
    %   GridEpisodicBasic environment

    % TODO: turn these actor wrappers into environment wrappers
    
    
    methods
        
        function this = AgentFltSparsifyGridEBLookahead( agent )
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
            
            % compute grid size
            this.gridSize = repmat( sqrt( this.props.observationRanges(2) ), 1, 2 );
            
            % compute state, action and state-action dimensions for the inner space
            this.sDim = diff( this.props.observationRanges1, 1, 2 );
            this.aDim = diff( this.props.actionRanges1, 1, 2 );
            this.saDim = this.sDim;
            
            % this is an environment-specific filter
            assert( this.aDim == 3 );
            assert( this.gridSize(1) == round(this.gridSize(1)) );   % assume square grid
            
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
                
                % generate the state-action feature matrix: make it refer
                % to the next states that follow the transition
                [x0,y0] = ind2sub( this.gridSize, observation );
                saFeatures = zeros( this.aDim, this.saDim );
                for action=1:this.aDim
                  
                  % compute new position (do not remove clamped actions so
                  % as to stay consistent with the basic implementation)
                  x1 = x0 + 1;
                  y1 = y0 + action - 2;
                  y1 = min( max( 1, y1 ), this.gridSize(2) );   % clamp y
                  
                  % if on grid, set one to the entry corresponding to the next state
                  if x1 <= this.gridSize(1)
                    saFeatures( action, sub2ind(this.gridSize, x1, y1) ) = 1;
                  end
                  
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
        
        % size of the grid (assume square grid)
        gridSize;
        
        % dimensions for the inner space
        sDim, aDim, saDim;
        
    end
    
end
