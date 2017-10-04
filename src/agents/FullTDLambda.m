classdef FullTDLambda < Critic
  %FULLTDLAMBDA TD(lambda) critic with explicit computations (for analysis)
  %
  % TD(lambda) critic with explicit computations, intended for analysis
  % purposes (is very slow).
  %
  % Current status:
  %   - Comments are not up to date. Code is not cleaned.
  %   - TD(0), LSTD and LSTD(0) modes produce expected results that match those of LSTDLambda
  %   - MC gives incorrect results (do not match with LSTD mode and LSTDLambda critic)
  %     - the mismatch is not big; is comparable to the effect of the IRF feature
  %     - might well be due to rounding errors
  
  % TODO update comments
  
  % ---- OLD COMMENTS FOLLOW ----
  %
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
  
  %#ok<*PROP>
  
  
  properties
    
    % preallocate for this many samples
    PREALLOC = 1e3;
    
    
    % Internal matrices that were computed during the last call to
    % computeV(). These are computed from s0, s1 and r on each call to
    % computeV().
    A; b;
    
    % transition memory: rows correspond to samples, columns to features
    s0; s1;
    
    % reward memory: rows correspond to samples
    r;
    
    % indices (into rows of s0, s1 and r) of episode starts
    episodeStartInds;
    
    % number of samples in s0, s1 and r (which use preallocation)
    n;
    
  end
  
  
  methods
    
    function this = FullTDLambda( gamma, lambda, varargin )
      % Constructor
      %
      %   this = LSTDLambda( gamma, lambda, [property/value pairs] )
      %
      % Remember to call forget() before first use!
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
      %                      2006). (not implemented!)
      %       'recursive':   Recursive update, as in (Lagoudakis and Parr,
      %                      2003). (not implemented!)
      
      % parse args
      
      args = inputParser;
      args.addParamValue( 'I', 0, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'beta', 0, @(x) (isnumeric(x) && isscalar(x)) );
      
      args.addParamValue( 'batchMethod', 'LSTD(0)', @ischar );
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
      
      this.V = zeros(this.dim, 1);
      this = forget( this );
      
    end
    
    function this = forget( this )
      % Forget statistics according to this.beta. Note that this.V is not
      % cleared.
      
      this.s0 = nan( this.PREALLOC, this.dim );
      this.s1 = nan( this.PREALLOC, this.dim );
      this.r = nan( this.PREALLOC, 1 );
      
      this.episodeStartInds = [];
      this.n = 0;
      
      this.Vok = false;
      
    end
    
    function this = newEpisode( this )
      
      % record episode start ind
      this.episodeStartInds(end+1) = this.n + 1;
      
    end
    
    function cnd = getCond( this )
      % Get condition of the A matrix.
      
      % prepare the solver mask (for excluding certain features)
      m = this.featureMask; k = size(this.s0,2);
      if isempty(m); m = true(1,k); end
      
      % get cond
      %A = this.s0(1:this.n,:) - this.gamma * this.s1(1:this.n,:);
      %cnd = cond(A(:,m));
      cnd = nan;
      
    end
    
    
    function this = step( this, s0, s1, r )
      
      assert( strcmp( this.onlineMethod, 'none' ) );
      
      % update params: store s0, s1 and r
      if this.n + 1 > size(this.s0,1)
        % preallocate more
        this.s0(end+1:end+size(this.s0,1),:) = nan(size(this.s0));
        this.s1(end+1:end+size(this.s1,1),:) = nan(size(this.s1));
        this.r(end+1:end+size(this.r,1),1) = nan(size(this.r));
      end
      this.s0(this.n+1,:) = s0;
      this.s1(this.n+1,:) = s1;
      this.r(this.n+1,1) = r;
      this.n = this.n + 1;
      
      this.Vok = false;
      
    end
    
    function this = addData( this, data )
      
      % update params: store s0, s1 and r
      while this.n + data.n > size(this.s0,1)
        % preallocate more
        this.s0(end+1:end+size(this.s0,1),:) = nan(size(this.s0));
        this.s1(end+1:end+size(this.s1,1),:) = nan(size(this.s1));
        this.r(end+1:end+size(this.r,1),1) = nan(size(this.r));
      end
      this.s0(this.n+1:this.n+data.n,:) = data.s0(1:data.n,:);
      this.s1(this.n+1:this.n+data.n,:) = data.s1(1:data.n,:);
      this.r(this.n+1:this.n+data.n,1) = data.r(1:data.n,1);
      this.n = this.n + data.n;
      
      this.Vok = false;
      
    end
    
    % No-op for LSTD
    function this = finalize( this ); end
    
    function this = computeV( this, batchMethod, correctPetersTrick, stateDim )
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
      %       guess. Works very poorly for dense but near-singular systems.
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
      
      if ~exist( 'batchMethod', 'var') || isempty(batchMethod); batchMethod = this.batchMethod; end
      if ~exist( 'correctPetersTrick', 'var'); correctPetersTrick = false; end
      
      % prepare the solver mask (for excluding certain features)
      m = this.featureMask; k = size(this.s0,2);
      if isempty(m); m = true(1,k); end
      
      % extract in-use portions of s0, s1 and r
      s0 = this.s0(1:this.n,:);
      s1 = this.s1(1:this.n,:);
      r = this.r(1:this.n,1);
      
      % add one-past-end index to episodeStartInds
      epInds = [ this.episodeStartInds, this.n + 1 ];
      
      % bail out if called at beginning of iteration due to logging
      if length(epInds) == 1; this.V = zeros(k,1); return; end
          
      % solve with mask
      switch batchMethod

        case 'TD(0)'

          % use TD(0)
          A = s0 - this.gamma * s1;
          b = r;
          
          % apply mask
          A = A(:,m);

          % solve
          if false
            V_ = linsolve( A, b );
            fprintf('            linsolve( A, b ):                      residual = %g (cond = %g)\n', ...
              norm(A * V_ - b), cond(A) );

            V_ = pinv( A' * A ) * (A' * b);
            fprintf('            pinv( A'' * A ) * (A'' * b):             residual = %g (cond = %g)\n', ...
              norm(A * V_ - b), cond(A' * A) );

            fun = @(x)( norm(A*x - b) );
            %x0 = zeros( size(A,2), 1 );
            x0 = V_;
            V_ = fminsearch( fun, x0 );
            fprintf('            fminsearch( fun, x0 ):                 residual = %g\n', norm(A * V_ - b) );
          end

          V_ = pinv( s0' * A ) * (s0' * b);
          fprintf('            pinv( s0'' * A ) * (s0'' * b):           residual = %g (cond = %g)\n', ...
            norm(A * V_ - b), cond( s0' * A ) );
          
        case 'MC'
          
          % init A and b
          A = zeros(0,k); b = zeros(0,1);
          A_LSTD = zeros(k,k);
          b_LSTD = zeros(k,1);
          
          % loop through episodes
          for ep=1:length(epInds)-1
            
            % episode range
            rangeBegin = epInds(ep); rangeEnd = epInds(ep+1)-1;
            
            % compute returns (= backwards cumulative reward with discounting)
            R = r(rangeBegin:rangeEnd,1);
            for i=length(R)-1:-1:1
              R(i) = R(i) + this.gamma * R(i+1);
            end
            
            % construct equations: s0_t = R_t
            A_ = s0(rangeBegin:rangeEnd,:);
            b_ = R;
            
            % emulate LSTD
            for i=1:length(R)
              A_LSTD = A_LSTD + s0(rangeBegin+i-1,:)' * s0(rangeBegin+i-1,:);
              b_LSTD = b_LSTD + s0(rangeBegin+i-1,:)' * R(i);
            end
            
            % concatenate to A and b
            A = [ A ; A_ ]; b = [b ; b_];
            
          end

          % apply mask
          A = A(:,m);
          A_LSTD = A_LSTD(m,m);
          b_LSTD = b_LSTD(m,1);

          % solve
          if false
            V_ = pinv( A_LSTD ) * b_LSTD;
            fprintf('            pinv( A_LSTD ) * b_LSTD:               residual = %g (cond = %g)\n', ...
              norm(A * V_ - b), cond(A) );
          end
          [V_,~] = linsolve( A, b );
          fprintf('            linsolve( A, b ):                      residual = %g (cond = %g)\n', ...
            norm(A * V_ - b), cond(A) );
          
          
        case 'LSTD'

          % emulate LSTD

          A = zeros(k,k);
          b = zeros(k,1);
          z = zeros(k,1);

          for i=1:size(s0,1)
            if any(i == epInds); z = zeros(k,1); end   % reset trace on episode start
            z0 = z;
            z = this.gamma * this.lambda * z + s0(i,:)';
            A = A + z * ( s0(i,:)' - this.gamma * s1(i,:)' )';
            if correctPetersTrick
              s0A = zeros(k,1); s0A(stateDim+1:end,1) = s0(i,stateDim+1:end);
              A = A - this.gamma * this.lambda * z0 * s0A';
            end
            b = b + z * r(i);
          end
          
          % apply mask
          A = A(m,m);
          b = b(m);
          
          % solve
          V_ = pinv(A) * b;
          
          fprintf('LSTD cond: %g\n', cond(A));

        case 'LSTD(0)'

          % emulate LSTD(0)

          A = zeros(k,k);
          b = zeros(k,1);

          for i=1:size(s0,1)
            A = A + s0(i,:)' * ( s0(i,:)' - this.gamma * s1(i,:)' )';
            b = b + s0(i,:)' * r(i);
          end

          % apply mask
          A = A(m,m);
          b = b(m);
          
          V_ = pinv(A) * b;
          
          fprintf('LSTD(0) cond: %g\n', cond(A));

        otherwise
          
          error('Unknown batch method ''%s''!', batchMethod );
          
      end

      % undo solver mask and write back V
      this.V = zeros(k,1); this.V(m) = V_;
      
      if any(isnan(this.V)); error('Critic update resulted in NaN values in V!'); end
      %fprintf( ' (solver mse: %g) ', mean(((this.A - this.Ifactor * eye(size(this.A))) * this.V - this.b).^2) );
      
      % store A and b
      this.A = A(m,m);
      this.b = b(m);
      
    end
    
  end
  
end
