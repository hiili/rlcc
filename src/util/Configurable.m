classdef Configurable < handle
  %CONFIGURABLE Transforms public properties into an inputParser
  %
  %   Allows setting the public fields of an object by using the
  %   inputParser system. Note that passing in [] as the value for a
  %   property has the effect of leaving the property unchanged. It is
  %   currently not possible to set a property to [].
  %
  %   Type checking can be optionally enforced by adding type definition
  %   properties with the suffix '_t' as follows:
  %
  %     properties
  %       seed;
  %     end
  %
  %     properties (Constant, Hidden)
  %       seed_t = @(x) (isnumeric(x) && isscalar(x));
  %     end
  
  % NOTE The current design has issues; see notes.txt:2012-08
  
  
  methods
    
    function this = configure( this, arguments, mandatory )
      % Configure the object with the provided args.
      %
      %   this = configure( this, arguments, [mandatory] )
      %
      %   arguments
      %     Passed directly to inputParser.
      %
      %   mandatory
      %     An optional cell array of string specifying mandatory
      %     arguments.
      %
      % There is currently no type checking implemented.
      
      
      if ~exist('mandatory', 'var'); mandatory = {}; end
      
      % no-op if no args and no mandatory args
      if isempty(arguments) && isempty(mandatory); return; end
      
      % add public visible properties to the scheme
      args = inputParser();
      for prop=properties(this)'
        
        try
          % try to add to scheme using a type definition field (which have a _t suffix)
          args.addParamValue( prop{1}, [], this.([prop{1} '_t']) );
        catch err
          if ~strcmp(err.identifier, 'MATLAB:noSuchMethodOrField'); err.rethrow(); end
          
          % no type definition found, add without type checking
          args.addParamValue( prop{1}, [] );
          
        end
        
      end
      
      % Parse
      args.parse( arguments{:} );
      
      % Check that all mandatory arguments were provided
      missing = intersect(mandatory, args.UsingDefaults);
      if ~isempty(missing)
        error(['The following mandatory arguments were not specified:' repmat(' %s', 1, length(missing))], missing{:} );
      end
      
      % Assign values. Don't use p.UsingDefaults, so as to allow
      % passing in [] for keeping the default value. It is currently not
      % possible to set a property to [].
      for prop=properties(this)'
        if ~isempty( args.Results.(prop{1}) )
          this.(prop{1}) = args.Results.(prop{1});
        end
      end
      
    end
    
  end
  
  
end
