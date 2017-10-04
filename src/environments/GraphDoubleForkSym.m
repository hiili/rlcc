classdef GraphDoubleForkSym < GraphGeneric
  %GRAPHDOUBLEFORKSYM The symmetric Double Fork example
  %
  %   See MscExperiments wiki page for details.
  
  
  methods
    
    function this = GraphDoubleForkSym( configuration )
      % Constructor
      %
      %   this = GraphDoubleFork( configuration )
      %
      % Arguments
      %   (int) configuration
      %       Reward configuration id. See wiki page for details.
      
      % dimensions
      sCount = 4; aCount = 2; oCount = 1;
      
      % transitions
      this.P = [ ...
        0, 1, 0, 0; ...    % s1,a1 -> s2
        0, 0, 1, 0; ...    % s1,a2 -> s3
        0, 0, 0, 1; ...    % s2,a1 -> s4
        0, 0, 0, 1; ...    % s2,a2 -> s4
        0, 0, 0, 1; ...    % s3,a1 -> s4
        0, 0, 0, 1; ...    % s3,a2 -> s4
        0, 0, 0, 1; ...    % s4,a1 -> s4 (absorbing)
        0, 0, 0, 1 ];      % s4,a2 -> s4 (absorbing)
      
      % start and end states
      this.x0 = [ 1; 0; 0; 0 ];      % start: s1
      this.term = [ 0; 0; 0; 1 ];    % terminal: s3
      
      % rewards
      this.Q = zeros(sCount*aCount,1);
      switch configuration
        case 1
          this.Q( (2-1)*aCount+1 ) = 0;   % r(s2,a1)=0
          this.Q( (2-1)*aCount+2 ) = 1;   % r(s2,a2)=1
          this.Q( (3-1)*aCount+1 ) = 1;   % r(s3,a1)=1
          this.Q( (3-1)*aCount+2 ) = 0;   % r(s3,a2)=0
        case 2
          this.Q( (2-1)*aCount+1 ) = 1;   % r(s2,a1)=1
          this.Q( (2-1)*aCount+2 ) = -10; % r(s2,a2)=-10
          this.Q( (3-1)*aCount+1 ) = -10; % r(s3,a1)=-10
          this.Q( (3-1)*aCount+2 ) = 1;   % r(s3,a2)=1
        case 3
          this.Q( (2-1)*aCount+1 ) = 0;   % r(s2,a1)=0
          this.Q( (2-1)*aCount+2 ) = -10; % r(s2,a2)=-10
          this.Q( (3-1)*aCount+1 ) = -10; % r(s3,a1)=-10
          this.Q( (3-1)*aCount+2 ) = 0;   % r(s3,a2)=0
      end
      
      % observations
      this.O = [ 1; 1; 1; 1 ];   % all states -> o1
      
      
      % call late constructor
      this = construct( this );
      
    end
    
  end
  
end

