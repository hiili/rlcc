function b = squeeze1(a,dim)
%SQUEEZE1 Remove a specific singleton dimension.
%
%     b = squeeze1(a,dim)
%
%   Remove the singleton dimension 'dim', while verifying that it really is
%   singleton. No other singleton dimensions are removed.


s = size(a);
if s(dim) ~= 1; error('Dimension %d should be singleton but has size %d!', dim, s(dim)); end

s(dim) = [];
b = reshape(a, s);

end
