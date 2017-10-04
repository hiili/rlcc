classdef GraphApproximateForkWalk < GraphGenericFeaturized
  %GRAPHAPPROXIMATEFORKWALK The environment for the approximate fork walk example
  %
  %   See MscExperiments wiki page for details.
  
  
  methods
    
    function this = GraphApproximateForkWalk()
      % Constructor
      %
      %   this = GraphForkWalk( configuration )
      
      % dimensions
      sCount = 4; aCount = 2; oCount = 4;
      
      % transitions
      this.P = [ ...
        0, 1, 0, 0; ...    % s1,a1 -> s2
        0, 0, 0, 1; ...    % s1,a2 -> s4
        0, 0, 0, 1; ...    % s2,a1 -> s4
        0, 0, 1, 0; ...    % s2,a2 -> s3
        0, 0, 0, 1; ...    % s3,a1 -> s4
        0, 0, 0, 1; ...    % s3,a2 -> s4
        0, 0, 0, 1; ...    % s4,a1 -> s4 (absorbing)
        0, 0, 0, 1 ];      % s4,a2 -> s4 (absorbing)
      
      % start and end states
      this.x0 = [ 1; 0; 0; 0 ];      % start: s1
      this.term = [ 0; 0; 0; 1 ];    % terminal: s4
      
      % rewards
      this.Q = zeros(sCount*aCount,1);
      this.Q( (3-1)*aCount+1 ) = 1;   % r(s3,a1)=1
      
      % observations
      this.O = eye(4);   % full observability
      
      % featurization
      switch 2
        case 1
          this.phi = [ ...
            [1 0 0]; ...   % feature vector for observation 1
            [0 1 0]; ...
            [0 0 1]; ...
            [0 0 0] ];
        case 2
          this.phi = [ ...
            [1   0  ]; ...   % feature vector for observation 1
            [0.5 0.5]; ...
            [0   1  ]; ...
            [0   0  ] ];
      end
      
      
      % call late constructor
      this = construct( this );
      
    end
    
  end
  
end
