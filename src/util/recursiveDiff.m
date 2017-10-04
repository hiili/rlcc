function d = recursiveDiff( lhs, rhs, ignoreFields, verbose )
%RECURSIVEDIFF Recursive diff between structs or objects.
%
%     d = recursiveDiff( lhs, rhs, [ignoreFields, [verbose]] )
%
%   Perform a recursive diff between lhs and rhs. Both structs and objects
%   are accepted. Recursion is performed also into objects encountered
%   while traversing a struct. 'ignoreFields' can be a cell array of
%   strings, in which case such fields are ignored whose name matches a
%   string in this array. 'verbose' can be a combination of the following
%   substrings, concatenated with arbitrary letters in between: 'diff',
%   'tree', 'silentskip' (set to '' to suppress all output).
%
%   If 'verbose' is omitted and the return value d is not assigned (i.e.,
%   nargout == 0), then verbose will default to 'diff'. Otherwise verbose
%   will default to '' (quiet).
%
%   The returned value d is a scalar that summarizes the differences
%   between lhs and rhs:
%     d == 0:        lhs and rhs are identical
%     0 < d < Inf:   lhs and rhs match structurally and by non-numeric
%                    values but have a finite difference in numeric
%                    values. d is the mean squared error between all
%                    encountered numeric values.
%     d == Inf:      lhs and rhs differ structurally or by non-numeric
%                    values, or by Inf in numeric values


if ~exist( 'ignoreFields', 'var' ); ignoreFields = {}; end
if ~exist( 'verbose', 'var' ); if nargout == 0; verbose = 'diff'; else verbose = ''; end; end

[dn, n] = recursiveDiff_( lhs, rhs, '.', verbose, repmat( {{}}, 0, 2 ), ignoreFields );
d = dn/n;   % mse = sum of squares / number of elements
if n == 0; d = 0; end

end




function [dn, n, hPairs] = recursiveDiff_( lhs, rhs, prefix, verbose, hPairs, ignoreFields )

dn = 0; n = 0;

% tree structure output
if strfind(verbose, 'tree'); fprintf( '%s\n', cleanup(prefix) ); end

% check for size or shape mismatch
if ndims(lhs) ~= ndims(rhs) || any(size(lhs) ~= size(rhs))
  %if isempty(prefix); prefix = '(root).'; end
  if strfind(verbose,'diff'); fprintf( 'Different size or shape: %s\n', cleanup(prefix) ); end
  dn = Inf; n = 1; return;
end


% compare based on type
if (isstruct(lhs) || isobject(lhs)) && (isstruct(rhs) || isobject(rhs))


  % both are struct or object arrays

  % extract field names, ignore fields listed in ignoreFields
  s = warning('off', 'all');
  lhsFields = setdiff( fieldnames(struct(lhs))', ignoreFields );
  rhsFields = setdiff( fieldnames(struct(rhs))', ignoreFields );
  warning(s);

  % report field differences
  if strfind(verbose,'diff')
    for fn=setdiff( lhsFields, rhsFields )
      if ~isempty(fn); fprintf( 'Only in lhs: %s\n', cleanup([prefix fn{1}]) ); end
    end
    for fn=setdiff( rhsFields, lhsFields )
      if ~isempty(fn); fprintf( 'Only in rhs: %s\n', cleanup([prefix fn{1}]) ); end
    end
  else
    if ~isequal( lhsFields, rhsFields ); dn = Inf; n = 1; return; end
  end

  % process struct or object arrays one element at a time
  if ~isscalar(lhs) || ~isscalar(rhs)

    % recurse for each element
    for el=1:numel(lhs)
      [dn_, n_, hPairs] = ...
        recursiveDiff_( lhs(el), rhs(el), [prefix(1:end-1) '(' num2str(el) ').'], verbose, hPairs, ignoreFields );
      dn = dn + dn_; n = n + n_;
    end

    return;

  end

  assert( isscalar(lhs) && isscalar(rhs) );

  % comparison between a pair of (scalar) handles?
  if isa( lhs, 'handle' ) && isa( rhs, 'handle' )

    % already compared?
    flag = false;
    for i=1:size(hPairs,1)   % can't use a handle array as some handle objects can't be cast into handles (R2011a)
      if (hPairs{i,1} == lhs && hPairs{i,2} == rhs) || (hPairs{i,1} == rhs && hPairs{i,2} == lhs); flag = true; break; end
    end
    if flag

      % compared: skip (report if verbose)
      if ~isempty(strfind(verbose,'diff')) && isempty(strfind(verbose,'silentskip'))
        fprintf( 'Skipping an already compared handle pair: %s\n', cleanup(prefix) );
      end
      return;

    else

      % not compared: add to hPairs list
      hPairs = [hPairs ; {lhs, rhs}];

    end

  end

  % turn objects into structs
  s = warning('off', 'all');
  if isobject(lhs); lhs = struct(lhs); end
  if isobject(rhs); rhs = struct(rhs); end
  warning(s);

  % recurse for each common field
  for fn=intersect( lhsFields, rhsFields )
    [dn_, n_, hPairs] = recursiveDiff_( lhs.(fn{1}), rhs.(fn{1}), [prefix fn{1} '.'], verbose, hPairs, ignoreFields );
    dn = dn + dn_; n = n + n_;
  end


elseif isnumeric(lhs) && isnumeric(rhs)


  % both are numeric arrays of equal size: compute mse

  % flatten
  lhs = lhs(:); rhs = rhs(:);

  % replace common nans with zeros (enforce nan == nan -> true)
  common = isnan(lhs) & isnan(rhs);
  lhs(common) = 0; rhs(common) = 0;

  % replace common infs with zeros (enforce inf == inf -> true)
  common = isinf(lhs) & isinf(rhs) & lhs == rhs;
  lhs(common) = 0; rhs(common) = 0;

  % compute squared error
  dn_ = sum( ( lhs - rhs ) .^ 2 );
  n_ = length(lhs);
  
  % NaN squared error -> Inf (eg, due to non-matching NaNs)
  if isnan(dn_); dn_= Inf; end

  % accumulate, report if dn_ > 0
  dn = dn + dn_; n = n + n_;
  if ~isempty(strfind(verbose,'diff')) && dn_ > 0
    fprintf( 'Differing numeric content: %s   (mse: %g)\n', cleanup(prefix), dn_/n_ );
  end


else


  % binary compare

  if ~isequalwithequalnans( lhs, rhs )
    dn = Inf; n = 1;
    if strfind(verbose,'diff'); fprintf( 'Differing non-numeric content: %s\n', cleanup(prefix) ); end
  end


end

end




function str = cleanup( str )

try
  if str(1) == '.'; str(1) = []; end
  if str(end) == '.'; str(end) = []; end
catch %#ok<CTCH>
end
if isempty(str); str = '(root)'; end

end
