classdef TestConfigurable < Configurable
  %TESTCONFIGURABLE Test the Configurable class
  
  
  properties
    
    seed;
    
    foo;
    
  end
  
  properties (Constant, Hidden)
    seed_t = @(x) (isnumeric(x) && isscalar(x));
  end
  
  
  methods
    
    function this = TestConfigurable( varargin )
      this.configure( varargin );
    end
    
  end
  
  
end
