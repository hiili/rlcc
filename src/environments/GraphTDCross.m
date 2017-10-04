classdef GraphTDCross < GraphGeneric
  %GRAPHTDCROSS TD cross example, as in my 2006 RL presentation
  %
  %   See MscExperiments wiki page for details.
  
  
  methods
    
    function this = GraphTDCross( configuration )
      
      % dimensions
      sCount = 7; aCount = 1; oCount = 5;
      
      % transitions
      this.P = [ ...
        0, 1, 0, 0, 0, 0, 0; ...    % s1,a1 -> s2
        0, 0, 1, 0, 0, 0, 0; ...    % s2,a1 -> s3
        0, 0, 0, 0, 0, 0, 1; ...    % s3,a1 -> term
        0, 0, 0, 0, 1, 0, 0; ...    % s4,a1 -> s5
        0, 0, 0, 0, 0, 1, 0; ...    % s5,a1 -> s6
        0, 0, 0, 0, 0, 0, 1; ...    % s6,a1 -> term
        0, 0, 0, 0, 0, 0, 1 ];      % term -> term
      
      % start and end states
      this.x0 = [ 0.5; 0; 0; 0.5; 0; 0; 0 ];      % start: s1 or s4
      this.term = [ 0; 0; 0; 0; 0; 0; 1 ];    % terminal: s7
      
      % rewards
      this.Q = [ 0; 0; 1; 0; 0; -1; 0 ];
      
      % observations
      this.O = [ ...
        1, 0, 0, 0, 0; ...
        0, 1, 0, 0, 0; ...
        0, 0, 1, 0, 0; ...
        0, 0, 0, 1, 0; ...
        0, 1, 0, 0, 0; ...
        0, 0, 0, 0, 1; ...
        1, 0, 0, 0, 0 ];    % s2 and s5 are aliased
      
      
      % call late constructor
      this = construct( this );
      
    end
    
  end
  
end

