classdef GraphGeneric < Environment & Configurable
  %GRAPHGENERIC A generic discrete graph environment.
  %
  %   Note that all state, action and observation counting starts from 1.
  %
  %   The observation vector is a sparse index vector with length oCount,
  %   with a 1 at the position corresponding to the index of the current
  %   observation.
  %
  %   Action selection is based on action lists. The length of the action
  %   feature vectors (rows of the actions matrix) have the length oCount *
  %   aCount. For action 1, the observation vector y is placed at position
  %   1..length(y) and the rest of the elements are left zero. For action
  %   2, it is placed at length(y)+1..2*length(y), and so on.
  %
  %   In summary, actions are treated as fully dinstinct, i.e., having no
  %   generalization between them.
  
  % TODO rename Q -> r.
  
  % TODO rename class to Graph
  
  
  properties
    
    % (sCount*aCount x sCount double matrix) P, or
    % (sCount x aCount x sCount double array) P
    %   State transition matrix. In the first syntax, rows correspond to
    %   state-actions (state-major) and columns correspond to transition
    %   end states. In the second syntax, the first dimension corresponds
    %   to transition start states, the second corresponds to actions, and
    %   the third corresponds to transition end states.
    P;
    
    % (sCount*aCount -element double column vector) Q, or
    % (sCount x aCount double matrix) Q
    %   Immediate rewards for each state-action. The first syntax is
    %   state-major.
    Q;
    
    % (sCount -element double column vector) x0
    %   Starting state distribution. Elements should be non-negative
    %   and sum up to one.
    x0;
    
    % (sCount -element double column vector) term
    %   Probabilities for each state being a terminal state. Element
    %   ranges: [0,1]
    term;
    
    % (sCount x oCount double matrix) O
    %   State->observation mapping. Element (s,o) is the probability
    %   p(o|s). Each row should sum up to one.
    O;
    
    % (N-element row int vector) saRanges
    %   State-specific action ranges, or [].
    sa;
    
    % (sCount x 2 double matrix) vPos
    %   Optional state positions for visualization. Set to the empty
    %   matrix to let graphviz compute the positions automatically.
    vPos;
    
    
    % (int) sCount, aCount, oCount, oaCounts
    %   State, action, observation and state-specific action counts. These
    %   are filled automatically in the late constructor.
    sCount, aCount, oCount, saCounts;
    
  end
  
  properties (Access=protected)
    
    % (int: [1,sCount]) state
    %   Current state.
    state;
    
    % reward for the last transition
    reward;
    
    % whether the episode has ended
    ended;
    
  end
  
  properties (Access=private)
    
    % environment properties
    props;
    
    % state visitation distribution
    svd;
    
    % Markov chain induced by the policy
    chain;
    
  end
  
  
  methods
    
    function this = GraphGeneric( varargin )
      % Constructor.
      % 
      %   this = GraphGeneric( <name/value pairs> ... )
      % 
      % The user-configurable class properties can be provided as
      % name/value pairs here during construction.
      
      % configure
      this.configure( varargin );
      
    end
    
    function this = construct( this, P, Q, x0, term, O, sa, vPos )
      % Late constructor. This must be called before using the object.
      % You can call this, e.g., at the end of the constructor of the
      % inheriting class after filling in the fields.
      %
      %   this = construct()
      %   this = construct( P, Q, x0, term, O, sa, vPos )
      %
      % Arguments
      %   See documentation of the corresponding protected properties. If
      %   called without arguments, then the corresponding fields must be
      %   filled in before calling this constructor.
      
      assert( nargin == 1 || nargin == 8 );
      
      % store params, if provided
      if nargin == 8
        this.P = P; this.Q = Q; this.O = O;
        this.x0 = x0; this.term = term; this.sa = sa;
        this.vPos = vPos;
      end
      
      % check existence of params (sa and vPos can be empty)
      assert( ~isempty(this.P) && ~isempty(this.Q) && ...
        ~isempty(this.O) && ~isempty(this.x0) && ...
        ~isempty(this.term) );
      
      
      % extract dimensionality
      this.sCount = size( this.O, 1 );
      this.oCount = size( this.O, 2 );
      this.aCount = numel(this.Q) / this.sCount;
      this.saCounts = this.sa';
      if isempty(this.saCounts)
        this.saCounts = repmat( this.aCount, this.sCount, 1 );
      end
      
      % convert from P(s*a,s) and Q(s*a) syntax to P(s,a,s) and Q(s,a)
      if ismatrix(this.P); this.P = permute( reshape( this.P, this.aCount, this.sCount, this.sCount ), [2,1,3] ); end
      if isvector(this.Q); this.Q = reshape( this.Q, this.aCount, this.sCount )'; end
      
      % fill in the environment properties struct
      this.props.observationType = 'd';
      this.props.observationDim = this.oCount;
      this.props.useActionsList = true;
      this.props.actionType = 'd';
      this.props.actionDim = this.oCount * this.aCount;
      
    end
    
    function this = init( this, varargin )
      this = init@Environment( this, varargin{:} );
      
      % reset statistics
      this.resetStats();
      
    end
    
    % return the environment properties struct
    function props = getProps( this ); props = this.props; end
    
    
    function resetStats( this )
      this.svd = zeros(1, this.sCount);
      this.chain = zeros(this.sCount);
    end
    
    function stats = getStats( this )
      stats = struct( ...
        'svd', this.svd / sum(this.svd), ...
        'chain', this.chain ./ repmat( sum(this.chain,2), 1, size(this.chain,2) ) );
    end
    
  end
  
  
  
  
  % protected methods begin (implementations of abstract methods)
  
  
  
  
  methods (Access=protected)
    
    function actions = getAvailableActions( this )
      
      % fill in the actions matrix with state-dependent available actions
      actions = spalloc( this.saCounts(this.state), this.oCount * this.aCount, this.saCounts(this.state) );
      for a=1:this.saCounts(this.state)
        actions( a, (a-1)*this.oCount+1 : a*this.oCount ) = this.observation;
      end
      
    end
    
    function this = resetState( this )
      this.reward = 0;
      this.state = randDiscretePdf( this.rstream, this.x0 );
    end
    
    function this = advanceState( this, action )
      
      % add old state to svd, prepare to add transition to chain
      this.svd(this.state) = this.svd(this.state) + 1;
      state0 = this.state;
      
      % generate reward, advance state, check if ended
      this.reward = this.Q( this.state, action(1) );
      this.state = randDiscretePdf( this.rstream, squeeze(this.P( this.state, action(1) , : )) );
      this.ended = ( rand(this.rstream) < this.term(this.state) );
      
      % add transition to chain
      this.chain(state0,this.state) = this.chain(state0,this.state) + 1;
      
    end
    
    function ended = checkEndCondition( this )
      ended = this.ended;
    end
    
    function stateVec = generateVectorialState( this )
      stateVec = this.state;
    end
    
    function observation = generateObservation( this )
      observation = sparse(1, this.oCount);
      observation( randDiscretePdf(this.rstream, this.O(this.state,:)) ) = 1;
    end
    
    function reward = generateReward( this )
      reward = this.reward;
    end
    
  end
  
  
  
  
  % public methods for analysis and visualization begin
  
  
  
  
  methods
    
%     function stats = getStats( this, logs )
%     % Return some statistics of the given trajectories. If no
%     % trajectories are given, then the logged trajectories in the
%     % environment object will be used.
%     %
%     % (struct) stats
%     % Fields:
%     %   (int) nSteps
%     %       Total number of steps contained in the data.
%     %   (double vector) sd
%     %       Normalized state visitation distribution. sd(s) is
%     %       the visit count of state s divided by the total number
%     %       of steps (state visits).
%     %   (double vector) return
%     %       Average total reward from the tails of trajectories going
%     %       out from a state. return(s) is the average total
%     %       return for state s.
%     %       NOTE: states with no visits at all will have a NaN
%     %             as the total reward.
%     %   (double vector) returns
%     %       Returns for each trajectory.
%       
%       % if no trajectory inds are given, then use all
%       %if nargin < 2; trajectoryInds = 1:getLogs(this).episode(end); end
%       
%       % if no logs are given, then use ones logged in 'this'
%       if nargin < 2; logs = getLogs(this); end
%       
%       stats.nSteps = [];
%       
%       % compute the state visitation distribution
%       stats.sd = zeros( this.sCount, 1 );
%       for s=logs.states'
%         stats.sd(s) = stats.sd(s) + 1;
%       end
%       stats.nSteps = length(logs.states);
%       stats.sd = stats.sd / stats.nSteps;
%       
%       % compute returns
%       stats.return = zeros( this.sCount, 1 );
%       for e=1:logs.episode(end)
%         
%         estates = logs.states(logs.episode == e);
%         erewards = logs.rewards(logs.episode == e);
%         
%         % compute returns over the trajectory
%         % (count multiple visits correctly)
%         cr = 0;
%         for s=length(erewards):-1:1
%           cr = cr + erewards(s);
%           stats.return( estates(s) ) = ...
%             stats.return( estates(s) ) + cr;
%         end
%         
%         % store also the complete trajectory return
%         stats.returns(e) = cr;
%         
%       end
%       stats.return = stats.return ./ (stats.sd * stats.nSteps);
%       
%     end
%     
%     
%     function visualize( this, trajectoryInds )
%       % Visualize everything.
%     end
    
    function visualizeEnvironment( this )
      % Visualize the environment.
      
      fn = evalc('!mktemp'); fn(end) = [];
      fh = fopen( fn, 'w' );
      
      fprintf( fh, 'digraph G {\n' );
      
      % nodes
      for s0=1:this.sCount
        if isempty(this.vPos)
          fprintf( fh, '    s%d;\n', s0 );
        else
          fprintf( fh, '    s%d [pin=true,pos="%d,%d"];\n', ...
            s0, this.vPos(s0,1), this.vPos(s0,2) );
        end
        
        % edges
        for a=1:this.oaCounts(s0)   % must assume s=o
          for s1=1:this.sCount
            if this.P( s0, a, s1 ) > 0
              
              r = this.Q( s0, a );
              if r ~= 0; rs = ['r=' num2str(r)];
              else rs = ''; end
              
              fprintf( fh, ...
                ['        s%d -> s%d [' ...
                'labelfontsize=10,taillabel="%s",' ...
                'fontsize=10,label="%s"];\n'], ...
                s0, s1, ['a' num2str(a)], rs );
              
            end
          end
        end
        
      end
      
      fprintf( fh, '}\n' );
      fclose(fh);
      
      if isempty(this.vPos); gvMode='dot'; else gvMode='neato'; end
      evalc([ '!' gvMode ' -Tpdf ' fn ...
        ' | acroread /a "zoom=100" -' ]);
      
    end
    
%     function stats = visualizeStats( this, stats )
%       % Visualize statistics.
%     end
%     
%     function visualizeTrajectories( this, trajectoryInds )
%       % Plots the states and transitions of the given trajectories.
%     end
%     
%     function visualizePolicy( this, agent, nSamples )
%       % Visualize a policy.
%     end
    
  end
  
end
