function [b, a] = butter(order, Wn, ftype)
% BUTTER - Pure MATLAB Butterworth Lowpass Filter Designer
% Bilinear transformation design of continuous-to-discrete Butterworth filter.
% Compatible with base MATLAB without Signal Processing Toolbox.
%
% Syntax:
%   [b, a] = butter(order, Wn)
%   [b, a] = butter(order, Wn, 'low')
%
% Inputs:
%   order - Filter order (positive integer, e.g. 5)
%   Wn    - Normalized cutoff frequency (0 < Wn < 1, normalized to Nyquist Fs/2)
%   ftype - 'low' (default lowpass filter)
%
% Outputs:
%   b     - Numerator filter coefficients
%   a     - Denominator filter coefficients

    if nargin < 3, ftype = 'low'; end %#ok<INUSD>
    order = round(order);
    
    % Constrain normalized cutoff safely in (0, 1)
    Wn = min(max(Wn, 1e-4), 0.999);
    
    % Pre-warp analog cutoff for bilinear transformation
    wa = 2 * tan(pi * Wn / 2);
    
    % Analog Butterworth poles on s-plane left-half circle
    k = 1 : order;
    sp = wa * exp(1j * (pi * (2 * k + order - 1) / (2 * order)));
    
    % Bilinear transform: s = 2 * (z - 1) / (z + 1) -> z = (2 + s) / (2 - s)
    zp = (2 + sp) ./ (2 - sp);
    zz = -ones(1, order); % zeros at Nyquist (z = -1)
    
    % Polynomial expansion
    a = real(poly(zp));
    b0 = real(poly(zz));
    
    % Normalize DC gain (at z = 1) to unity (0 dB)
    gain = sum(b0) / sum(a);
    b = b0 / gain;
end
