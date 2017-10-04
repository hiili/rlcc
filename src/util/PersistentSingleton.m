classdef PersistentSingleton
  %PERSISTENTSINGLETON Rudimentary support for persistent singleton objects
  %
  %   Rudimentary support for persistent singleton objects. A persistent
  %   singleton object can be (re-)initialized with the Init() method,
  %   loaded with Load() and stored back with Save().
  %
  %   The persistent storage files will be overwritten in Save() without
  %   asking the user for any confirmation and without any temporary backup
  %   files. It might be a good idea to have the storage directory backed
  %   up frequently.
  %
  %   For convenience, you might want to add the following lines to the
  %   inheriting classes:
  %     methods (Static)
  %       function Init(varargin); PersistentSingleton.Init( mfilename('class'), varargin{:} ); end
  %       function object = Load(varargin); object = PersistentSingleton.Load( mfilename('class'), varargin{:} ); end
  %       function Save(varargin); PersistentSingleton.Save( mfilename('class'), varargin{:} ); end
  %     end
  
  
  methods (Static)
    
    % Initializes a persistent singleton instance of a class by creating an
    % empty object instance and saving it in a <classname>.mat file. The
    % file is stored in the directory defined by StoragePath().
    % If the file already exists, it will be overwritten.
    %
    % The process is interactive: user confirmation is asked before writing
    % anything to disk.
    %
    %   (string) classname
    %     The name of the persistent singleton class for which an instance
    %     should be initialized.
    function Init( classname )
      
      % instantiate the object
      object = eval(classname); %#ok<NASGU>
      
      % generate the filename for the .mat file
      filename = [ PersistentSingleton.StoragePath() classname '.mat' ];
      
      % check if the file already exists
      if exist( filename, 'file' )
        doesExistString = '\nThe file ALREADY EXISTS and will be overwritten.\nAll associated data will be lost!\n';
      else
        doesExistString = 'The file does not exist at the moment. ';
      end
      
      % ask user for confirmation
      answer = input( [...
        'About to write a newly created singleton object instance to the persistent storage file:\n' ...
        '  ' filename '\n' ...
        doesExistString 'Proceed? (y/n) '], 's' );
      
      % stop if user did not answer 'y'
      if length(answer) ~= 1 || answer ~= 'y'
        fprintf( 'Operation cancelled.\n' );
        return;
      end
      
      % store the object
      save( filename, 'object', '-v7.3' );
      
      fprintf('Done.\n');
      
    end
    
    function object = Load( classname ) %#ok<STOUT>
      
      % generate the filename for the .mat file
      filename = [ PersistentSingleton.StoragePath() classname '.mat' ];
      
      % load the persistent singleton instance from disk
      load( filename, 'object' );
      
    end
    
    function Save( classname, object ) %#ok<INUSD>
      
      % generate the filename for the .mat file
      filename = [ PersistentSingleton.StoragePath() classname '.mat' ];
      
      % save the object back to disk
      save( filename, 'object', '-v7.3' );
      
    end
    
    % Return the path to the persistent storage files
    function pathname = StoragePath()
      
      % resolve programroot
      pathname = regexp( mfilename('fullpath'), '^(.*)[\\/]src[\\/]util[\\/]PersistentSingleton$', 'tokens' );
      assert( ~isempty(pathname), 'Unable to resolve programroot!' ); pathname = pathname{1}{1};
      
      % proceed to a relative hard-coded directory
      pathname = [ pathname '/data/persistent_storage/' ];
      
    end
    
  end
  
end

