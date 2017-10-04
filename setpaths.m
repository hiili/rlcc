function varargout = setpaths( varargin )
% SETPATHS Set paths
%
%   [paths] = setpaths( 'pathPrefix', (string), 'doAddpath', (logical = true) )
%
% Arguments
%
%   'pathPrefix', (string) path
%     Use the specified string as the path prefix. Default, if [] or
%     omitted: the path to this file (setpaths.m)
%
%   'doAddpath', (logical) doAddpath = true
%     Whether to add the paths also to the Matlab path with addpath.
%     Default: true
%
%   (cell array of strings) paths
%     The list is also returned in the return variable if requested by
%     assignment.


% parse args
args = inputParser;
args.addParamValue( 'pathPrefix', [], @(x) (isempty(x) || ischar(x)) );
args.addParamValue( 'doAddpath', true, @islogical );
args.parse( varargin{:} );

% assign args
pathPrefix = args.Results.pathPrefix;
if isempty(pathPrefix); [pathPrefix,~,~] = fileparts( which('setpaths') ); end
doAddpath = args.Results.doAddpath;


paths = {};

paths{end+1} = [pathPrefix '/src'];
paths{end+1} = [pathPrefix '/src/environments'];
paths{end+1} = [pathPrefix '/src/agents'];
paths{end+1} = [pathPrefix '/src/util'];
paths{end+1} = [pathPrefix '/src/util/processes'];
paths{end+1} = [pathPrefix '/src/mex'];

paths{end+1} = [pathPrefix '/tools'];

paths{end+1} = [pathPrefix '/test'];
paths{end+1} = [pathPrefix '/test/test_cases'];
paths{end+1} = [pathPrefix '/test/manual_tests'];
paths{end+1} = [pathPrefix '/experiments'];
paths{end+1} = [pathPrefix '/data'];

paths{end+1} = [pathPrefix '/external'];
paths{end+1} = [pathPrefix '/external/MatlabGraph'];
paths{end+1} = [pathPrefix '/external/DrawDot'];
paths{end+1} = [pathPrefix '/external/CatStruct'];
paths{end+1} = [pathPrefix '/external/CellStructEq'];
paths{end+1} = [pathPrefix '/external/matlab2tikz'];
paths{end+1} = [pathPrefix '/external/ellipse'];


% addpath?
if doAddpath; addpath( paths{:} ); end

% return the list?
if nargout == 1; varargout{1} = paths; end

end
