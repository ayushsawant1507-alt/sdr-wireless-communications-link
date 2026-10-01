function [psd, f] = pwelch(x, win, noverlap, nfft, fs, mode)
% PWELCH - Pure MATLAB Welch Power Spectral Density (PSD) Estimator
% Estimates power spectral density using Welch's averaged modified periodogram method.
% Compatible with base MATLAB without Signal Processing Toolbox.
%
% Syntax:
%   [psd, f] = pwelch(x, win, noverlap, nfft, fs)
%   [psd, f] = pwelch(x, win, noverlap, nfft, fs, 'centered')

    x = x(:);
    Nx = length(x);
    
    % Window evaluation
    if nargin < 2 || isempty(win)
        L = min(Nx, 256);
        win = hann(L);
    elseif isscalar(win)
        L = round(win);
        win = hann(L);
    else
        L = length(win);
        win = win(:);
    end
    
    if nargin < 3 || isempty(noverlap), noverlap = floor(L / 2); end
    if nargin < 4 || isempty(nfft),     nfft = max(256, 2^nextpow2(L)); end
    if nargin < 5 || isempty(fs),       fs = 1; end
    
    step = max(1, L - noverlap);
    num_segs = floor((Nx - L) / step) + 1;
    
    if num_segs < 1
        num_segs = 1;
        x_padded = [x; zeros(max(0, L - Nx), 1)];
        x_mat = x_padded(1 : L) .* win;
    else
        % Segment and window data matrix
        indices = (0 : L - 1)' + (0 : num_segs - 1) * step + 1;
        x_mat = x(indices) .* repmat(win, 1, num_segs);
    end
    
    % Discrete Fourier Transform across columns
    X = fft(x_mat, nfft, 1);
    
    % Segment power spectral density
    win_pwr = sum(abs(win) .^ 2);
    psd_mat = (abs(X) .^ 2) / (fs * win_pwr);
    psd_full = mean(psd_mat, 2);
    
    % Check centering and spectrum symmetry
    is_centered = (nargin >= 6 && ischar(mode) && strcmpi(mode, 'centered'));
    
    if is_centered
        psd = fftshift(psd_full);
        f = (-nfft/2 : nfft/2 - 1)' * (fs / nfft);
    elseif isreal(x)
        % One-sided PSD for real-valued time-domain signals
        n_half = floor(nfft / 2) + 1;
        psd_half = psd_full(1 : n_half);
        if n_half > 2
            psd_half(2 : end-1) = 2 * psd_half(2 : end-1);
        end
        psd = psd_half;
        f = (0 : n_half - 1)' * (fs / nfft);
    else
        psd = psd_full;
        f = (0 : nfft - 1)' * (fs / nfft);
    end
end
