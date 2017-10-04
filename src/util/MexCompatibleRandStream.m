classdef MexCompatibleRandStream < RandStream & handle
  %MEXCOMPATIBLERANDSTREAM RandStream with mex sync
  %
  %   An extension of RandStream that allows one to perform identical
  %   experiments using both mex and Matlab implementations.
  %
  %   Currently the mex implementations buffer the random numbers read from
  %   Matlab, which causes more random numbers to be read than what is
  %   actually used. This class performs proper skipping so as to keep the
  %   random sequences identical in both cases.
  %
  %   Usage: Use as you would use RandStream, but call mexFork() and
  %   mexJoin() where a mex execution path could have been started and
  %   where that mex execution path would have joined back in,
  %   respectively.
  
  properties (Access=private)
    
    % Remember to keep this in sync with the constant in mex/MatlabRandStream.hpp
    BUFFERSIZE = 1024;
    
    % emulates the index in the mex implementation
    counter = 0;
    
    % stack for pushState() and popState()
    stateStack = {};
    
  end
  
  methods
    
    function this = MexCompatibleRandStream( varargin )
      this = this@RandStream( varargin{:} );
      this.counter = this.BUFFERSIZE;
    end
    
    function r = rand( this, varargin )
      r = rand@RandStream( this, varargin{:} );
      this.counter = mod( this.counter + length(r(:)), this.BUFFERSIZE );
    end
    
    function mexFork( this )
      % call this where a mex execution path could have been started
      
      this.counter = 0;
    end
    
    function mexJoin( this )
      % call this where a mex execution path would have joined back in
      
      if this.counter > 0; rand( this, this.BUFFERSIZE - this.counter, 1 ); end
      this.counter = 0;
    end
    
    function pushState( this )
      % Push stream state into internal state stack. Note that you have to
      % use the syntax pushState( object ) instead of object.pushState(),
      % due to the overloaded subsref in RandStream.
      
      this.stateStack = { this.State, this.stateStack };
    end
    
    function popState( this )
      % Restore stream state from internal state stack. Note that you have
      % to use the syntax popState( object ) instead of object.popState(),
      % due to the overloaded subsref in RandStream.
      
      this.set( 'State', this.stateStack{1} );   % can't assign directly.. (r2011a)
      this.stateStack = this.stateStack{2};
    end
    
  end
  
end

