classdef GraphSynthetic < GraphGeneric & Configurable
  %GRAPHSYNTHETIC Synthetic POMDP graph environment.
  %
  %   A parameterized synthetic POMDP environment with discrete state,
  %   action, and observation spaces. The state and observation spaces are
  %   assumed to have multidimensional uniform grid structures that are
  %   taken into account when generating the actual parameters of the
  %   POMDP. The action space is unstructured.
  %
  %   The dimension of the grid of the underlying MDP is defined by
  %   dimsMdp. Setting this to 2 produces a conventional 2-dimensional grid
  %   world. The effect of this grid on the synthesized MDP is described
  %   below.
  %
  %   The unnormalized probability of starting from state s is synthesized
  %   from a unit-scale gamma distribution, with the shape (mean) k =
  %   Gaussian(d), where d is the Euclidean distance of state s from the
  %   corner of the grid at which state 1 resides. The Gaussian has zero
  %   mean and unit variance. The probability of terminating when in state
  %   s is synthesized likewise, except that the distance is computed from
  %   the opposite corner of the grid (i.e., at which the last state
  %   resides).
  %
  %   The unnormalized probability of transitioning from state s0 to state
  %   s1 with a given action is synthesized from a unit-scale gamma
  %   distribution, with the shape (mean) k = Gaussian(s1_p), where s1_p is
  %   the position of s1 on the grid. By default, the Gaussian is centered
  %   at s0_p, i.e., at the position of s0 on the grid. It is also possible
  %   to move the distribution toward the starting corner or the terminal
  %   corner of the grid with PSynthMean, so as to make the MDP to have a
  %   tendency toward either end (negative shift moves the Gaussian from
  %   s0_p toward the start corner). The radial variance of the Gaussian
  %   can be specified with PSynthVariance.
  %
  %   Immediate rewards (which are deterministic) for each state-action are
  %   synthesized from a zero-mean unit-variance Gaussian distribution.
  %
  %   The dimension of the grid of the observation space is defined by
  %   dimsPomdp. The effect of this grid on the synthesized observation
  %   function is described below.
  %
  %   The observation function is constructed in such a way that only the
  %   first dimsPomdp dimensions of the MDP grid are observable; the rest
  %   of the dimensions are discarded when states are mapped to
  %   observations, thus introducing state aliasing along these truncated
  %   dimensions. Noise is then added to the truncated state, so as to
  %   produce the final observation. The expected value of the synthesized
  %   probability of observing o when the truncated state is s_t is
  %   inversely proportional to the distance between s_t and o on the
  %   observation grid: the unnormalized probability of observing o for s_t
  %   is synthesized from a unit-scale gamma distribution, with the shape
  %   (mean) k = Gaussian(d), where d is the Euclidean distance between o
  %   and s_t on the observation grid. The variance of the Gaussian can be
  %   specified with OSynthVariance. Setting it to eps results in a
  %   deterministic observation function, while setting it to realmax
  %   results in an observation function that does not correlate with the
  %   internal grid structure.
  %
  %
  %   Mandatory parameters
  %
  %     sCount, aCount   (inherited from GraphGeneric)
  %       State and action count for the underlying MDP. sCount must
  %       fulfill sCount == n^dimsMdp, where n is an integer.
  %
  %   Optional parameters
  %
  %     synthSeed
  %       Random seed for synthesizing the environment.
  %
  %     dimsMdp, dimsPomdp
  %       Dimensions of the neighborhood grid of the underlying MDP and of
  %       the POMDP. It must be that dimsPomdp <= dimsMdp. dimsPomdp
  %       defaults to dimsMdp, i.e., to full observability (except for
  %       observation noise specified by OSynthVariance). dimsMdp defaults
  %       to 1.
  %
  %     PSynthMean, PSynthVariance
  %       The relative mean and the variance of the Gaussian shape function
  %       that is used for synthesizing transition probabilities. A
  %       negative mean moves the shape function toward the start corner of
  %       the grid, i.e., toward where state 1 resides. A positive mean
  %       moves it toward the end corner of the grid (the opposite corner,
  %       where the last state resides).
  %
  %     OSynthVariance
  %       Variance of the Gaussian shape function that is used for
  %       synthesizing the observation function. If set to eps, then each
  %       state will map deterministically to the observation that is
  %       obtained after removing hidden dimensions. If set to realmax,
  %       then the observation function is synthesized with an equal weight
  %       for every state and observation pair.
  
  % TODO Maybe fix the start and end states to the corners, as the current
  % randomization might be a completely redundant addition to the state
  % transition randomness.
  
  
  properties
    % User-configurable parameters
    
    % random seed used for synthesizing the environment
    synthSeed = 1;
    
    % dimension of the neighborhood grid of the underlying MDP
    %   (positive integer)
    dimsMdp = 1;
    
    % number of dimensions in the underlying MDP that are observable
    %   (positive integer)
    dimsPomdp;
    
    % placement and width of the Gaussian distribution for generating the
    % transition matrix
    %   (double, non-negative finite double)
    PSynthMean = 0; PSynthVariance = 1;
    
    % variance of the Gaussian blur filter that is applied to the
    % observation function
    %   (non-negative finite double)
    OSynthVariance = 1;
    
  end
  properties (Constant, Hidden)
    dimsMdp_t          = @(x) (isscalar(x) && isnumeric(x) && round(x) == x && x > 0);
    dimsPomdp_t        = @(x) (isscalar(x) && isnumeric(x) && round(x) == x && x > 0);
    PSynthMean_t       = @(x) (isscalar(x) && isnumeric(x));
    PSynthVariance_t   = @(x) (isscalar(x) && isnumeric(x) && x > 0 && ~isinf(x) );
    OSynthVariance_t   = @(x) (isscalar(x) && isnumeric(x) && x > 0 && ~isinf(x) );
  end
  properties (Constant, Hidden, Access=private)
    mandatoryArgs = {'sCount', 'aCount'};
  end
  
  properties
    
    % Length of individual dimensions of the grid (both state and
    % observation grids). type: integer
    dimLength;
    
    % Grid positions for each state and observation. sGridPos(s,:) is the
    % grid position of state s. Elements are in the range [1,dimLength].
    %   (integer matrix)
    sGridPos; oGridPos;
    
  end
  
  
  methods
    
    function this = GraphSynthetic( varargin )
      % Constructor.
      % 
      %   this = GraphSynthetic( <name/value pairs> ... )
      % 
      % The user-configurable class properties should be provided as
      % name/value pairs here during construction.
      
      % configure
      this.configure( varargin, this.mandatoryArgs );
      
    end
    
    function this = construct( this )
      % Late constructor. This must be called before using the object.
      
      
      % check or set dimsPomdp
      if isempty(this.dimsPomdp); this.dimsPomdp = this.dimsMdp; end
      assert( this.dimsPomdp <= this.dimsMdp, 'It must hold that dimsPomdp <= dimsMdp.' );
      
      % compute the length of the individual dimensions of the grid (both state and observation grids)
      this.dimLength = this.sCount^(1/this.dimsMdp);
      this.dimLength = round(this.dimLength * 2^10) / 2^10;   % remove possible rounding errors
      assert( round(this.dimLength) == this.dimLength, ...
        'It must hold that this.sCount == n^this.dim, where n is an integer.' );
      
      % compute the observation count
      assert( isempty(this.oCount) || this.oCount == this.dimLength^this.dimsPomdp, ...
        'this.oCount does not match other parameters (you can leave it empty to have it computed automatically).');
      this.oCount = this.dimLength^this.dimsPomdp;
      
      
      % create a random stream, set to default stream (stats toolbox uses the default stream)
      prevRStream = RandStream.setGlobalStream( RandStream('mt19937ar', 'seed', this.synthSeed ) );
      
      % compute the grid positions of each state on the this.dimsMdp -dimensional grid: row n = ind2sub(grid, n)
      this.sGridPos = mod( floor( repmat( (0:(this.sCount-1))', 1, this.dimsMdp ) ./ ...
        repmat( this.dimLength.^(0:this.dimsMdp-1), this.sCount, 1 ) ), this.dimLength ) + 1;
      
      % store the grid positions of each observation on the this.dimsPomdp -dimensional grid: row n = ind2sub(grid, n)
      this.oGridPos = this.sGridPos(1:this.oCount,1:this.dimsPomdp);
      
      
      % start and end states (see help section)
      this.x0 = gamrnd( mvnpdf( this.sGridPos - 1, [], ones(1,size(this.sGridPos,2)) ), 1 );
      this.x0 = this.x0 ./ sum(this.x0);
      this.term = gamrnd( mvnpdf( this.sGridPos - this.dimLength, [], ones(1,size(this.sGridPos,2)) ), 1 );
      this.term = this.term ./ sum(this.term);
      
      % rewards
      this.Q = randn(this.sCount, this.aCount);
      
      
      % transitions
      
      % compute the unnormalized transition distribution
      this.P = zeros(this.sCount,this.aCount,this.sCount);
      for s=1:this.sCount
        for a=1:this.aCount
          
          % Compute the Gaussian for each grid point, having the Gaussian
          % centered at the current state s minus this.PSynthMean (i.e.,
          % shift it toward the corner where state 1 resides). Use
          % this.PSynthVariance as the variance. Then sample from the gamma
          % distribution that has the Gaussian as its shape.
          this.P(s,a,:) = gamrnd( mvnpdf( ...
            this.sGridPos, this.sGridPos(s,:) + this.PSynthMean, ...
            repmat( this.PSynthVariance, 1, this.dimsMdp) ), 1 );
          
        end
      end
      
      % normalize
      this.P = this.P ./ repmat( sum(this.P, 3), [1, 1, this.sCount] );
      
      
      % observations
      
      % Compute the gamma shape parameters for the observation function for
      % the first oCount states. These states lie on the bottom of the
      % hidden subspace, i.e., are non-aliased. They are mapped directly to
      % the corresponding observations, except for a Gaussian blur filter
      % that introduces uncertainty already within the observed dimensions.
      OShapeObservable = zeros(this.oCount,this.oCount);
      for s=1:this.oCount
          
          % Compute the Gaussian for each observation grid point, having
          % the Gaussian centered at the current state s. Use
          % this.OSynthVariance as the variance.
          OShapeObservable(s,:) = mvnpdf( ...
            this.oGridPos, this.oGridPos(s,1:this.dimsPomdp), ...
            repmat( this.OSynthVariance, 1, this.dimsPomdp) );
          
      end
      
      % Clone the shape table over the hidden subspace, so as to
      % introduce aliasing along the involved dimensions
      OShape = repmat( OShapeObservable, this.sCount / this.oCount, 1 );
      
      % generate the actual observation probabilities from OShape, then normalize
      this.O = gamrnd( OShape, 1);
      this.O = this.O ./ repmat( sum(this.O, 2), 1, this.oCount );
      
      
      % revert the global random stream
      RandStream.setGlobalStream( prevRStream );
      
      % late construct the parent class
      this = construct@GraphGeneric( this );
      
    end
    
  end
  
end
