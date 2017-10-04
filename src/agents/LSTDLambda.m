classdef LSTDLambda < Critic
  %LSTDLAMBDA LSTD(lambda) critic.
  %
  %   A tabular, model-based critic. Implements LSTD(lambda) as described
  %   by Nedic & Bertsekas (2003) if fed with data processed by a suitable
  %   featurizer. See also: Peters, 2007; Lagoudakis & Parr, 2003.
  %
  %   References
  %
  %     Nedic & Bertsekas (2003). Least squares policy evaluation
  %     algorithms with linear function approximation.
  %
  %     Peters (2007). Machine learning of motor skills for robotics.
  %
  %     Lagoudakis & Parr (2003). Least-squares policy iteration.
  %
  %     Geramifard, Bowling & Sutton (2006). Incremental least-squares
  %     temporal difference learning.
  %
  %     Bruno Luong's pseudoinverse function
  %       www.mathworks.com/matlabcentral/fileexchange/25453-pseudo-inverse
  
  
  properties
    
    % transition model
    A;
    
    % reward model
    b;
    
    % eligibility trace
    z;
    
  end
  
  
  methods
    
    function this = LSTDLambda( gamma, lambda, varargin )
      % Constructor
      %
      %   this = LSTDLambda( gamma, lambda, [property/value pairs] )
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
      %       'incremental': Incremental update, as in (Geramifard et al.,
      %                      2006). (not implemented)
      %       'recursive':   Recursive update, as in (Lagoudakis and Parr,
      %                      2003). (not implemented)
      
      % parse args
      
      args = inputParser;
      args.addParamValue( 'I', 0, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'beta', 0, @(x) (isnumeric(x) && isscalar(x)) );
      
      args.addParamValue( 'batchMethod', 'pinv', @ischar );
      args.addParamValue( 'onlineMethod', 'none', @ischar );
      
      args.addParamValue( 'featureMask', [], @islogical );
      
      % not used but accepted for compatibility with LSPELambda
      args.addParamValue( 'stepsize', 1, @(x) (isnumeric(x) && isvector(x) && length(x) <= 2) );
      args.addParamValue( 'iterations', 1, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'w0', [], @isnumeric );
      
      args.parse( varargin{:} );
      
      
      % store args
      
      this.gamma = gamma;
      this.lambda = lambda;
      this.Ifactor = args.Results.I;
      this.beta = args.Results.beta;
      this.featureMask = args.Results.featureMask;
      
      this.batchMethod = args.Results.batchMethod;
      this.onlineMethod = args.Results.onlineMethod;
      
    end
    
    function this = reset( this )
      
      this.A = this.Ifactor * eye(this.dim);
      this.b = zeros(this.dim, 1);
      this.V = zeros(this.dim, 1);
      
    end
    
    function this = forget( this )
      % Forget statistics according to this.beta. Note that this.V is not
      % cleared.
      
      % forget
      this.A = (1 - this.beta) * this.Ifactor * eye(this.dim) + this.beta * this.A;
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
      % Get condition of the A matrix.
      
      % prepare the solver mask (for excluding certain features)
      m = this.featureMask; k = length(this.b);
      if isempty(m); m = true(1,k); end
      
      % get cond
      cnd = cond(this.A(m,m));
      
    end
    
    
    function this = step( this, s0, s1, r )
      
      assert( ~isempty(this.z) && strcmp( this.onlineMethod, 'none' ) );
      
      % update params
      this.z = this.gamma * this.lambda * this.z + s0;
      this.A = this.A + this.z * (s0 - this.gamma * s1)';
      this.b = this.b + this.z * r;
      
      this.Vok = false;
      
    end
    
    function this = addData( this, data )
      
      this.A = this.A + data.A;
      this.b = this.b + data.b;
      
      this.z = [];
      this.Vok = false;
      
    end
    
    function this = finalize( this )
      % No-op for LSTD
      
    end
    
    function this = computeV( this, batchMethod )
      % Computes the V-function and stores it into V. Alternatives for
      % solving Ax=b:
      %
      %   MATLAB internal
      %
      %     '\': x = A \ b
      %       Supports sparse data (although A and b are currently not stored
      %       as sparse) but does not handle rank deficiency well (returns
      %       results with huge norms).
      %     'pinv': x = pinv(A) * b
      %       Use pinv(). Not for sparse data.
      %     'lsqr': x = lsqr( A, b )
      %       Use the lsqr() function. Supports sparse data (but always
      %       returns full vectors). Possibility for providing an initial
      %       guess. Works very poorly for dense near-singular systems.
      %     'lsqr-warmstart': x = lsqr( A, b, [], [], [], [], V )
      %       Use the lsqr() function. Use previous result as the initial guess
      %     (todo: check other methods implemented in Matlab)
      %
      %   External functions
      %
      %     pseudoinverse()
      %       Bruno Luong's pseudoinverse function.
      %       Links @ www.mathworks.com/matlabcentral/...
      %         * fileexchange/25453-pseudo-inverse
      %         * newsreader/view_thread/235547
      
      if this.Vok; return; end
      this.Vok = true;
      
      if nargin < 2, batchMethod = this.batchMethod; end
      
      % prepare the solver mask (for excluding certain features)
      m = this.featureMask; k = length(this.b);
      if isempty(m); m = true(1,k); end
      
      % solve with mask
      switch batchMethod
        
        case '\'
          % MATLAB backslash operator
          V_ = this.A(m,m) \ this.b(m);
          
        case 'pinv'
          % MATLAB pinv function
          V_ = pinv(this.A(m,m)) * this.b(m);
          
        case 'qr'
          % MATLAB qr
          [Q,R] = qr( this.A(m,m) );
          V_ = R \ ( Q' * this.b(m) );
          
        case 'lsqr'
          % MATLAB lsqr
          V_ = lsqr( this.A(m,m), this.b(m) );
          
        case 'lsqr-warmstart'
          % MATLAB lsqr, use previous result as the initial guess
          V_ = lsqr( this.A(m,m), this.b(m), [],[],[],[], this.V(m) );
          
      end
      
      % undo solver mask and write back V
      this.V = zeros(k,1); this.V(m) = V_;
      
      if any(isnan(this.V)); error('Critic update resulted in NaN values in V!'); end
      %fprintf( ' (solver mse: %g) ', mean(((this.A - this.Ifactor * eye(size(this.A))) * this.V - this.b).^2) );
      
    end
    
  end
  
end
