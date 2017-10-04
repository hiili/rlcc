classdef GridEpisodicDoubleIntegrator < GridEpisodicBasic
  %GRIDEPISODICDOUBLEINTEGRATOR Episodic grid-world environment with
  %force-controllable vertical velocity.
  %
  %   See MscExperiments wiki page for details.
  
  
  properties (Access=private, Constant)
    
    % A constant related to velocity and acceleration ranges
    % (see wiki page for details)
    %
    % TODO: clean up code related to this
    vc = 4;
    
  end
  
  properties (Access=protected)
    
    % (sruct) state
    % Fields:
    %
    %   (2-element int vector) pos
    %       Current (x,y) position of the agent. Counting starts from 0
    %       and (0,0) is at the lower left corner.
    %   (int vector) v
    %       Vertical velocity
    %state;
    
  end
  
  properties (Access=private)
    
    % environment properties
    props;
    
  end
  
  
  methods
    
    % Constructor
    %
    %   this = GridBasicEpisodic( sizeX, sizeY, rewards )
    %
    % Arguments
    %   See GridEpisodicBasic
    function this = GridEpisodicDoubleIntegrator( ...
        sizeX, sizeY, rewards )
      
      this = this@GridEpisodicBasic( sizeX, sizeY, rewards );
      
      assert( sizeY/this.vc^2 == round( sizeY/this.vc^2 ), ...
        ['Vertical size must be a multiple of ' ...
        num2str(this.vc^2) '!'] );
      
      this.props.observationType = 'c';
      this.props.observationDim = 3;
      this.props.actionDim = 1;
      this.props.useActionsList = false;
      this.props.actionTypes = ('d')';
      
    end
    
    % return the environment properties struct
    function props = getProps( this ); props = this.props; end
    
  end
  
  
  % protected methods begin (implementations of abstract methods)
  
  
  methods (Access=protected)
    
    % reset the internal state ('state' field)
    function this = resetState( this )
      
      % reset the base object
      this = resetState@GridEpisodicBasic( this );
      
      % set vertical velocity to zero
      this.state.v = 0;
      
    end
    
    function this = advanceState( this, action )
      
      % clamp and scale the action
      action = min( max( action, -1 ), 1 );
      action = (sizeY / this.vc ^ 2) * action;
      
      % apply vertical acceleration
      this.state.v = ...
        max( -this.gridSize(2)/this.vc, ...
        min( this.gridSize(2)/this.vc, ...
        this.state.v + action(1) ));
      
      % move right (c - abs(v))
      %this.state.pos(1) = this.state.pos(1) + ...
      %    ( this.gridSize(2) / this.vc + 1 ) - abs(this.state.v);
      
      % move right (1 cell/step)
      this.state.pos(1) = this.state.pos(1) + 1;
      
      % move vertically
      this.state.pos(2) = this.state.pos(2) + ...
        this.state.v;
      
      % bounce if top or bottom edge overrun
      if this.state.pos(2) < 0 || ...
          this.state.pos(2) > this.gridSize(2) - 1
        this.state.v = -this.state.v;
      end
      
      % keep vertical position on grid (mirror back into grid)
      if this.state.pos(2) < 0
        this.state.pos(2) = abs( this.state.pos(2) );
      elseif this.state.pos(2) > this.gridSize(2) - 1
        this.state.pos(2) = ...
          2 * (this.gridSize(2) - 1) - this.state.pos(2);
      end
      
    end
    
    function stateVec = generateVectorialState( this )
      stateVec = [this.state.pos, this.state.v];
    end
    
    function observation = generateObservation( this )
      observation = [this.state.pos, this.state.v];
    end
    
  end
  
  
  % public methods for analysis and visualization begin
  
  
  methods
    
    % Plots the states and transitions of the specified trajectories.
    function visualizeTrajectories( this, trajectoryInds )
      
      logs = getLogs( this );
      if nargin < 2; trajectoryInds=1:8; end
      trajectoryInds( trajectoryInds > logs.episode(end) ) = [];
      
      prevhold = ishold; if ~prevhold; clf; end; hold on
      
      for tInd=trajectoryInds
        
        tSteps = (logs.episode == tInd);
        
        plot( logs.states(tSteps,1), ...
          logs.states(tSteps,2), ...
          'Color', [0 0.8 1] );
        
        quiver( ...
          logs.states(tSteps,1), ...
          logs.states(tSteps,2), ...
          zeros(length(tSteps), 1), ...
          logs.actions(tSteps,1), 0, ...
          'Color', [0 0.8 1] );
        
      end
      
      axis([ -0.5 this.gridSize(1)-0.5 -0.5 this.gridSize(2)-0.5 ]);
      if prevhold; hold on; else hold off; end
      
    end
    
  end
  
end
