function i = randDiscretePdf( rstream, v )
%RANDDISCRETEPDF Sample from a given discrete probability density function.
%
%     i = randDiscretePdf( rstream, v )
%
%   Select a random element from the row or column vector v with p(I=i|v) =
%   v(i). The index of the element is returned. The probability vector v
%   does not need to be normalized.

% (re)normalizing here protects against rounding error problems
cs = cumsum(v); cs = cs ./ cs(end);
i = find( rand(rstream) < cs, 1 );

end
