classdef GraphRotorblade < GraphGeneric
  %GRAPHROTORBLADE The rotorblade example
  %
  %   See MscExperiments wiki page for details.
  
  
  methods
    
    function this = GraphRotorblade( a1reward )
      % Constructor
      %
      %   this = GraphThreephaseMotor()
      
      if nargin == 0; a1reward = 0.5; end
      
      % dimensions (just to be used here)
      sCount = 8; aCount = 3; oCount = 5;
      
      % transitions (remember +1 offset wrt. mscthesis text!)
      this.P = zeros(sCount*aCount,sCount);
      this.P( (1-1)*aCount + 1, 2 ) = 1;  % s1,a1 -> s2
      this.P( (1-1)*aCount + 2, 3 ) = 1;  % s1,a2 -> s3
      this.P( (1-1)*aCount + 3, 4 ) = 1;  % s1,a3 -> s4
      this.P( (2-1)*aCount + (1:aCount), 6 ) = 1;   % s2,* -> s6
      this.P( (3-1)*aCount + (1:aCount), 7 ) = 1;   % s3,* -> s7
      this.P( (4-1)*aCount + (1:aCount), 5 ) = 1;   % s4,* -> s5
      this.P( (5-1)*aCount + (1:aCount), 8 ) = 1;   % s5,* -> s8
      this.P( (6-1)*aCount + (1:aCount), 8 ) = 1;   % s6,* -> s8
      this.P( (7-1)*aCount + (1:aCount), 8 ) = 1;  % s7,* -> s8
      
      % start and end states
      this.x0 = [ 1; 0; 0; 0; 0; 0; 0; 0; ];      % s1
      this.term = [ 0; 0; 0; 0; 0; 0; 0; 1; ];    % s8
      
      % rewards
      this.Q = zeros(sCount*aCount,1);
      this.Q( (2-1)*aCount + (1:aCount) ) = -1 + a1reward;   % r(s2,*) = -1 + a1reward
      %this.Q( (2-1)*aCount + (1:aCount) ) = -1;   % r(s2,*) = -1
      this.Q( (3-1)*aCount + (1:aCount) ) = -1;   % r(s3,*) = -1
      this.Q( (4-1)*aCount + (1:aCount) ) = -1;   % r(s4,*) = -1
      this.Q( (5-1)*aCount + (1:aCount) ) = 1;   % r(s5,*) = 1
      this.Q( (6-1)*aCount + (1:aCount) ) = 1;   % r(s6,*) = 1
      this.Q( (7-1)*aCount + (1:aCount) ) = 1;   % r(s7,*) = 1
      
      % observations: alias s2-s5, s3-s6, s4-s7
      this.O = [ ...
        1,  0, 0, 0,  0; ...
        0,  1, 0, 0,  0; ...
        0,  0, 1, 0,  0; ...
        0,  0, 0, 1,  0; ...
        0,  1, 0, 0,  0; ...
        0,  0, 1, 0,  0; ...
        0,  0, 0, 1,  0; ...
        0,  0, 0, 0,  1 ];
      
      % state-specific action ranges
      this.sa = [ 3, 1, 1, 1, 1, 1, 1, 1 ];
      
      % state positions for visualization
      %n = 2*pi/12;    % offset
      %this.vPos = [ ...
      %    0, 0; ...
      %    cos( 0*(2*pi/3) + n ), sin( 0*(2*pi/3) + n ); ...
      %    cos( 1*(2*pi/3) + n ), sin( 1*(2*pi/3) + n ); ...
      %    cos( 2*(2*pi/3) + n ), sin( 2*(2*pi/3) + n ); ...
      %    1.5*cos( 1*(2*pi/3) + n ), 1.5*sin( 1*(2*pi/3) + n ); ...
      %    1.5*cos( 2*(2*pi/3) + n ), 1.5*sin( 2*(2*pi/3) + n ); ...
      %    1.5*cos( 0*(2*pi/3) + n ), 1.5*sin( 0*(2*pi/3) + n ); ...
      %    4*cos( 1*(2*pi/3) + n ), 4*sin( 1*(2*pi/3) + n ); ...
      %    4*cos( 2*(2*pi/3) + n ), 4*sin( 2*(2*pi/3) + n ); ...
      %    4*cos( 0*(2*pi/3) + n ), 4*sin( 0*(2*pi/3) + n ) ...
      %    ] * 1 + 2;
      %this.vPos = [];     % don't use
      
      
      % call late constructor
      this = construct( this );
      
    end
    
  end
  
end

