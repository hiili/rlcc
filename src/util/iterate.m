function output = iterate( varargin )
%ITERATE A convenience wrapper for the Iterative class
%
%     output = iterate( name, logger, iterations, body, arguments ... )
%
%   A for-loop like convenience wrapper for the Iterative class. See the
%   documentation of Iterative for details.

output = Iterative( varargin{:} ).run();

end
