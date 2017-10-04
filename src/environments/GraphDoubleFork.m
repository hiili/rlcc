classdef GraphDoubleFork < GraphGeneric
  %GRAPHDOUBLEFORK The Double Fork example
  %
  %   See MscExperiments wiki page for details.
  
  
  methods
    
    function this = GraphDoubleFork( configuration, isHidden )
      % Constructor
      %
      %   this = GraphDoubleFork( configuration )
      %
      % Arguments
      %   (int) configuration
      %       Reward configuration id. See wiki page for details.
      
      if nargin < 2; isHidden = true; end
      
      % dimensions
      sCount = 3; aCount = 2; oCount = 1;
      
      % transitions
      this.P = [ ...
        0, 1, 0; ...    % s1,a1 -> s2
        0, 0, 1; ...    % s1,a2 -> s3
        0, 0, 1; ...    % s2,a1 -> s3
        0, 0, 1; ...    % s2,a2 -> s3
        0, 0, 1; ...    % s3,a1 -> s3 (absorbing)
        0, 0, 1 ];      % s3,a2 -> s3 (absorbing)
      
      % start and end states
      this.x0 = [ 1; 0; 0 ];      % start: s1
      this.term = [ 0; 0; 1 ];    % terminal: s3
      
      % rewards
      this.Q = zeros(sCount*aCount,1);
      switch configuration
        case 1
          this.Q( (2-1)*aCount+1 ) = 0;   % r(s2,a1)=0
          this.Q( (2-1)*aCount+2 ) = 1;   % r(s2,a2)=1
          this.Q( (1-1)*aCount+2 ) = 0;   % r(s1,a2)=0
        case 2
          this.Q( (2-1)*aCount+1 ) = 1;   % r(s2,a1)=1
          this.Q( (2-1)*aCount+2 ) = -10; % r(s2,a2)=-10
          this.Q( (1-1)*aCount+2 ) = 0;   % r(s1,a2)=0
        case 3
          this.Q( (2-1)*aCount+1 ) = 0;   % r(s2,a1)=0
          this.Q( (2-1)*aCount+2 ) = -10; % r(s2,a2)=-10
          this.Q( (1-1)*aCount+2 ) = 1;   % r(s1,a2)=1
        case 4   % like 1, but shift the optimum away from origin
                 %   pi*(left) = 2/3 (R=1/3)
                 %   theta*(left) - theta*(right) = log(2) = 0.693147180..
          this.Q( (2-1)*aCount+1 ) = 0.25; % r(s2,a1)=0.25
          this.Q( (2-1)*aCount+2 ) = 1;   % r(s2,a2)=1
          this.Q( (1-1)*aCount+2 ) = 0;   % r(s1,a2)=0
      end
      
      % observations
      if isHidden
        this.O = [ 1; 1; 0 ];   % both states -> o1
      else
        this.O = [ ...
          1, 0; ...
          0, 1; ...
          0, 0 ];
      end
      
      
      % call late constructor
      this = construct( this );
      
    end
    
  end
  
end

