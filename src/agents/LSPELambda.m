classdef LSPELambda < Critic
  %LSPELAMBDA LSPE(lambda) critic.
  %
  %   A tabular, model-based critic. Implements LSPE(lambda) by Nedic &
  %   Bertsekas (2003) if fed with data processed by a suitable featurizer.
  %
  %   References
  %
  %     Nedic & Bertsekas (2003). Least squares policy evaluation
  %     algorithms with linear function approximation.
  
  
  properties
    
    % critic stepsize (constant)
    stepsize;
    
    % critic iterations per update
    iterations;
    
    % initial params
    w0;
    
    
    % Critic params. Essentially same as V, except that w is used also
    % internally and it is updated only via calls to iterate(). Calls to
    % computeV() do not affect w.
    w;
    
    
    % B matrix
    B;
    
    % transition model
    A;
    
    % reward model
    b;
    
    % eligibility trace
    z;
    
  end
  
  
  methods
    
    function this = LSPELambda( gamma, lambda, varargin )
      % Constructor
      %
      %   this = LSPELambda( gamma, lambda, [property/value pairs] )
      %
      % Remember to call reset() before first use!
      %
      % Arguments
      %
      %   (double) gamma, lambda
      %     the discount factor and the eligibility trace strength
      %
      %   'I', f
      %     Before solving the linear system, the term f*I is added to the A
      %     matrix, where I is the identity matrix. Default: 1e-6
      %
      %   'beta', beta
      %     Forgetting factor for actor updates.
      %
      %   'stepsize', (double) stepsize
      %     Critic stepsize (constant).
      %
      %   (double array) w0
      %     Initial values for the state value function.
      %
      %   (logical array) featureMask
      %     Define which features will be taken into account when solving in
      %     the critic (this is taken into account also when reporting the
      %     condition number). If omitted or set to [], then all features
      %     will be used. Note that this mask does _not_ affect policy
      %     execution in the actor, it simply prevents the disabled features
      %     from affecting learning. The gradient elements corresponding to
      %     the disabled features are set to zero in the critic, and thus
      %     setting the corresponding elements manually to zero in the
      %     initial policy will effectively disable the feature also for the
      %     actor.
      %
      %   'batchMethod', 'lsqr'|'lsqr-warmstart'
      %     The batch solver to use in computeV(). Default: 'lsqr'
      %       'lsqr':           Use Matlab's lsqr() function.
      %       'lsqr-warmstart': As 'lsqr', but use the previous result as an
      %                         initial guess.
      %
      %   'onlineMethod', 'none'|'incremental'|'recursive'
      %     Update method for keeping the V-value estimate up-to-date in
      %     an online fashion. The first call to getV() after step()
      %     calls will cause V to be batch computed in case of no on-line
      %     updating. Default: 'none'
      %       'none':        V is not updated on-line.
      %       'incremental': N/A
      %       'recursive':   Recursive update, as in (...). (not
      %                      implemented!)
      
      % parse args
      
      args = inputParser;
      args.addParamValue( 'I', 0, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'beta', 0, @(x) (isnumeric(x) && isscalar(x)) );

      args.addParamValue( 'stepsize', 1, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'iterations', 1, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'w0', [], @isnumeric );
      args.addParamValue( 'featureMask', [], @islogical );
      
      args.addParamValue( 'batchMethod', 'pinv', @ischar );
      args.addParamValue( 'onlineMethod', 'none', @ischar );
      args.parse( varargin{:} );
      
      
      % store args
      
      this.gamma = gamma;
      this.lambda = lambda;
      this.Ifactor = args.Results.I;
      this.beta = args.Results.beta;
      this.featureMask = args.Results.featureMask;
      
      this.stepsize = args.Results.stepsize;
      this.iterations = args.Results.iterations;
      this.w0 = args.Results.w0(:);   % enforce into a column array
      
      this.batchMethod = args.Results.batchMethod;
      this.onlineMethod = args.Results.onlineMethod;
      
    end
    
    function this = reset( this )
      
      if isempty(this.w0); this.w0 = zeros(this.dim, 1); end
      this.B = this.Ifactor * eye(this.dim);
      this.A = zeros(this.dim);
      this.b = zeros(this.dim, 1);

      this.V = zeros(this.dim, 1);
      this.w = this.w0;
      
    end
    
    function this = forget( this )
      % Forget statistics according to this.beta and reset the stepsize
      % schedule. Note that this.V is not cleared, nor is forgetting
      % applied to the internally used previous solution.
      
      % forgetting
      this.B = (1 - this.beta) * this.Ifactor * eye(this.dim) + this.beta * this.B;
      this.A = this.beta * this.A;
      this.b = this.beta * this.b;
      this.z = zeros(this.dim, 1);   % unnecessary?
      
      % flag the current solution as invalid
      this.Vok = false;
      
    end
    
    function this = newEpisode( this )
      
      % reset the eligibility trace
      this.z = zeros(this.dim, 1);
      
    end
    
    function cnd = getCond( this )
      % Get condition of the B matrix.
      
      % prepare the solver mask (for excluding certain features)
      m = this.featureMask; k = length(this.b);
      if isempty(m); m = true(1,k); end
      
      % get cond
      cnd = cond(this.B(m,m));
      
    end
    
    
    function this = step( this, s0, s1, r )
      
      assert( ~isempty(this.z) && strcmp( this.onlineMethod, 'none' ) );
      
      % update params
      this.B = this.B + s0 * s0';
      this.z = this.gamma * this.lambda * this.z + s0;
      this.A = this.A + this.z * (this.gamma * s1 - s0)';
      this.b = this.b + this.z * r;
      
      this.Vok = false;
      
    end
    
    function this = addData( this, data )
      
      this.B = this.B + data.B;
      this.A = this.A + data.A;
      this.b = this.b + data.b;
      
      this.z = [];
      this.Vok = false;
      
    end
    
    function this = finalize( this )
      
      % compute V and store it to w
      this = computeV( this );
      this.w = this.V;
      
      this.Vok = false;
      
    end
    
    function this = computeV( this, batchMethod )
      % Computes the V-function and stores it into V. Note that this does
      % _not_ perform a critic update: calling this function successively
      % will not change the resulting V. A critic update is performed by
      % calling finalize(), after which further calls to computeV() will use
      % the new result as the starting point.
      %
      % Available solvers:
      %
      %   MATLAB internal
      %
      %     pinv:   Use the pinv() function for inverting B.
      
      if this.Vok; return; end
      this.Vok = true;
      
      if nargin < 2; batchMethod = this.batchMethod; end
      
      % prepare the solver mask (for excluding certain features)
      m = this.featureMask; k = length(this.b);
      if isempty(m); m = true(1,k); end
      
      % pick the current w as the starting point for V
      this.V = this.w;
      
      % iterate
      for i=1:this.iterations

        switch batchMethod

          case 'pinv'   % MATLAB pinv function

            % solve with mask
            delta_ = pinv(this.B(m,m)) * (this.A(m,m) * this.V(m) + this.b(m));

            % undo solver mask
            delta = zeros(k,1); delta(m) = delta_;

            % update V
            this.V = this.V + this.stepsize * delta;

        end

      end
      
      if any(isnan(this.V)); error('Critic update resulted in NaN values in V!'); end
      
    end
    
  end
  
end
