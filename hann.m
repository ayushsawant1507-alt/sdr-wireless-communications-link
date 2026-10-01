function w = hann(N)
% HANN - Pure MATLAB Hann (Hanning) Window Generator
% Implements standard Hann window w[n] = 0.5 * (1 - cos(2*pi*n / (N-1)))
% Designed for complete compatibility with base MATLAB without Signal Processing Toolbox.
%
% Syntax:
%   w = hann(N)
%
% Inputs:
%   N - Window length (positive integer)
%
% Outputs:
%   w - Column vector of length N containing Hann window coefficients

    if nargin < 1 || isempty(N) || N < 1
        w = [];
        return;
    end
    N = round(N);
    if N == 1
        w = 1;
        return;
    end
    n = (0 : N - 1)';
    w = 0.5 * (1 - cos(2 * pi * n / (N - 1)));
end
