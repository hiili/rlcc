function str = fmtnum( x )
%FMTNUM Convert a floating point number to a formatted string

if isnan(x)
  str = '      n/a';
elseif round(x) > -100000 && round(x) < 1000000
  str = sprintf( '%9.2f', x );
else
  str = sprintf( '%9.3g', x );
end

end
