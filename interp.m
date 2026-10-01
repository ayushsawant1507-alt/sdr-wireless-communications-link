function y = interp(x, r, l, alpha)
% INTERP - Pure MATLAB Resampling Interpolator
% Upsamples input vector x by integer factor r using shape-preserving interpolation.
% Compatible with base MATLAB without Signal Processing Toolbox.
%
% Syntax:
%   y = interp(x, r)
%
% Inputs:
%   x - Input signal vector
%   r - Integer oversampling ratio
%
% Outputs:
%   y - Upsampled output vector of length length(x) * r

    if nargin < 2 || isempty(r), r = 1; end
    r = round(r);
    x = x(:);
    N = length(x);
    if r <= 1 || N <= 1
        y = x;
        return;
    end
    
    t_orig = (1 : N)';
    t_new = linspace(1, N, N * r)';
    y = interp1(t_orig, x, t_new, 'pchip');
end
