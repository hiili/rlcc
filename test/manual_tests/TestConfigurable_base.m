classdef TestConfigurable_base < Configurable
  %TESTCONFIGURABLE_BASE Test inheritance with the Configurable class
  
  
  properties
    baseprop;
  end
  
  properties (Constant, Hidden)
    baseprop_t = @(x) (isnumeric(x) && isscalar(x));
  end
  
  
  methods
    
    function this = TestConfigurable_base( varargin )
      this.configure( varargin );
    end
    
  end
  
  
end
