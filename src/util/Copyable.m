classdef Copyable < handle
  %COPYABLE Adds a deep-copying clone method to the class
  %
  %   Adapted from
  %   http://www.mathworks.com/matlabcentral/newsreader/view_thread/257925.
  %   See also matlab.mixin.Copyable.
  
  methods
    function newObj = clone(this)
      
      switch 2
        
        case 1  % the class must handle zero-argument construction. also, handle properties might become shallow-copied.
          
          % create an empty instance of the class
          newObj = eval(class(this));

          % copy non-dependent properties, by creating a meta object for the class of 'this'
          mo = metaclass(this);
          ndp = findobj([mo.Properties{:}],'Dependent',false);
          for idx = 1:length(ndp)
              newObj.(ndp(idx).Name) = this.(ndp(idx).Name);
          end
          
        case 2
          
          try
            pid = getpid();
          catch
            try
              pid = feature('getpid');   % avoid relying primarily on this undocumented function
            catch
              pid = 0;
            end
          end
          
          filename = [tempname '_' num2str(pid) '__Copyable.mat'];
          save(filename, 'this');
          newObj = getfield( load(filename), 'this' );
          delete(filename);
          
      end
          
    end
  end
  
end

