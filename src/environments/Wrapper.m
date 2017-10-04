classdef Wrapper < Environment & Configurable
  %WRAPPER Environment wrapper base class
  %
  %   Base class for environment wrapper classes. This class provides
  %   default pass-through methods that simply forward calls to the
  %   contained environment.
  %
  %   The easiest way to use this class is to re-implement the getProps()
  %   method so as to re-define the environment properties, and then to
  %   re-implement some or all of the filter hook methods that begin with
  %   the word 'filter'.
  
  
  
  
  properties
    % User-configurable parameters
    
    % Contained environment. type: Environment
    containedEnvironment;
    
  end
  properties (Constant, Hidden)
    containedEnvironment_t = @(x) (isscalar(x) && isa(x, 'Environment'));
  end
  properties (Constant, Hidden, Access=private)
    mandatoryArgs = {'containedEnvironment'};
  end
  
  
  properties (Access=private)
    
    % Whether the contained environment uses action lists. type: logical
    useActionsList;
    
  end
  
  
  
  
  % Construction methods begin
  
  
  methods
    
    function this = Wrapper( varargin )
      % Constructor.
      % 
      %   this = FeaturizerSynthetic( <name/value pairs> ... )
      % 
      % The user-configurable class properties can be provided as
      % name/value pairs here during construction.
      
      % configure
      this.configure( varargin, this.mandatoryArgs );
      
    end
    
    function this = construct( this )
      % Late constructor. The call will be forwarded directly to the
      % contained environment; do not call this unless the contained
      % environment has a late constructor.
      
      % late construct the contained environment
      this.containedEnvironment.construct();
      
      % check whether action lists are being used
      props = this.containedEnvironment.getProps();
      this.useActionsList = props.useActionsList;
      
    end
    
  end
  
  
  
  
  % observation and action filter hooks begin
  
  
  methods (Access=protected)
    
    function observation = filterObservation( this, observation )
      % This filter hook is called for translating an observation from the
      % contained environment to an observation to be sent out.
    end
    
    function action = filterAction( this, action )
      % This filter hook is called for translating an incoming action to an
      % action to be sent to the contained environment.
    end
    
    function actions = filterActionsMatrix( this, actions )
      % This filter hook is called for translating an actions matrix from the
      % contained environment to an actions matrix to be sent out.
    end
    
  end
  
  
  
    
  % method forwards begin
  
  
  methods
    
    function props = getProps( this )
      props = this.containedEnvironment.getProps();
    end
    
    function init( this, varargin )
      % Init the Wrapper environment using the arguments, then init the
      % contained environment with a random seed that is generated from the
      % random stream of this Wrapper object.
      
      this = init@Environment( this, varargin{:} );
      this.containedEnvironment.init( 2^32 * rand(this.rstream) );
    end
    
    function [this, observation, actions] = newEpisode( this )
      
      % forward
      [~, observation, actions] = this.containedEnvironment.newEpisode();
      
      % filter the observation and the actions matrix
      observation = this.filterObservation( observation );
      if this.useActionsList; actions = this.filterActionsMatrix( actions ); end
      
    end
    
    function [this, reward, observation, actions] = step( this, action )
      
      % filter the action if not using action lists
      if ~this.useActionsList; action = this.filterAction( action ); end
      
      % forward
      [~, reward, observation, actions] = this.containedEnvironment.step( action );
      
      % filter the observation and the actions matrix
      observation = this.filterObservation( observation );
      if this.useActionsList; actions = this.filterActionsMatrix( actions ); end
      
    end
    
    function [this, data] = mexFork( this, useMex )
      [~, data] = this.containedEnvironment.mexFork( useMex );
    end
    
    function this = mexJoin( this, data )
      this.containedEnvironment.mexJoin( data );
    end
    
    function resetStats( this )
      this.containedEnvironment.resetStats();
    end
    
    function stats = getStats( this )
      stats = this.containedEnvironment.getStats();
    end
    
  end
  
  
  
  
  % dummy implementations of the abstract methods
  
  
  methods (Access=protected)
    function this = resetState( this ); end
    function this = advanceState( this, action ); end
    function ended = checkEndCondition( this ); end
    function stateVec = generateVectorialState( this ); end
    function observation = generateObservation( this ); end
    function reward = generateReward( this ); end
  end
  
end
