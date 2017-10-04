classdef TestConfigurable_derived < TestConfigurable_base & Configurable
  %TESTCONFIGURABLE_DERIVED Test inheritance with the Configurable class
  
  
  properties
    derivedprop;
  end
  
  properties (Constant, Hidden)
    derivedprop_t = @(x) (isnumeric(x) && isscalar(x));
  end
  
  
  methods
    
    function this = TestConfigurable_derived( varargin )
      this.configure( varargin );
    end
    
  end
  
  
end
