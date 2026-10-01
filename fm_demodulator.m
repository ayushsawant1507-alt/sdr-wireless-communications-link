function [audio_out, mpx_signal, fs_audio] = fm_demodulator(rf_iq_signal, fs_rf, deemph_tau)
% FM_DEMODULATOR - Digital Signal Processing FM Broadcast Demodulator
%
% Syntax:
%   [audio_out, mpx_signal, fs_audio] = fm_demodulator(rf_iq_signal, fs_rf, deemph_tau)
%
% Inputs:
%   rf_iq_signal - Complex baseband I/Q signal from RF receiver / file
%   fs_rf        - RF baseband sampling frequency (e.g., 240000 Hz)
%   deemph_tau   - De-emphasis filter time constant in seconds
%                  (75e-6 for US/Americas, 50e-6 for Europe/Asia, default: 75e-6)
%
% Outputs:
%   audio_out    - Demodulated, filtered, decimated mono audio signal (at 48 kHz)
%   mpx_signal   - Raw Multiplex (MPX) baseband signal prior to audio decimation
%   fs_audio     - Output audio sampling frequency (48 kHz)
%
% DSP Operations:
%   1. Channel Bandpass/Lowpass Filtering (200 kHz channel bandwidth)
%   2. Quadrature Frequency Discrimination: Δθ[n] = angle(r[n] * conj(r[n-1]))
%   3. Standard De-Emphasis IIR Filtering: H(s) = 1 / (1 + s * tau)
%   4. Decimation and Audio Lowpass Filtering to 48 kHz audio rate
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link - Commercial FM Receiver

    if nargin < 3 || isempty(deemph_tau)
        deemph_tau = 75e-6; % 75 microseconds standard de-emphasis
    end
    
    fs_audio = 48000; % Standard Hi-Fi audio sampling rate

    % =========================================================
    % 1. Channel Bandpass / Lowpass Pre-Filtering
    % =========================================================
    % Retain the 200 kHz FM channel and reject out-of-band noise/adjacent stations
    channel_cutoff = 100e3; % ±100 kHz (200 kHz bandwidth)
    [b_rf, a_rf] = butter(5, min(0.9, channel_cutoff / (fs_rf / 2)), 'low');
    filtered_rf = filter(b_rf, a_rf, rf_iq_signal);

    % =========================================================
    % 2. Quadrature Frequency Discrimination
    % =========================================================
    % Calculate instantaneous phase differential between adjacent samples:
    % Δθ[n] = angle( r[n] · conj(r[n-1]) )
    % Instantaneous frequency offset is proportional to d(phi)/dt
    conj_product = filtered_rf(2:end) .* conj(filtered_rf(1:end-1));
    instantaneous_phase_diff = angle(conj_product);
    
    % Pad first sample to maintain vector length
    mpx_signal = [0; instantaneous_phase_diff];
    
    % Scale to physical frequency deviation: m[n] = (Fs / 2π) * Δθ[n]
    delta_f_max = 75e3; % ±75 kHz standard FM broadcast max deviation
    mpx_normalized = (fs_rf / (2 * pi * delta_f_max)) * mpx_signal;

    % =========================================================
    % 3. Standard FM De-Emphasis Filter
    % =========================================================
    % FM broadcast transmitters apply pre-emphasis H_pre(s) = 1 + s*tau to boost
    % high frequencies against triangular FM noise.
    % The receiver must apply de-emphasis: H_de(s) = 1 / (1 + s*tau).
    % Using bilinear transformation:
    dt = 1 / fs_rf;
    alpha = dt / (deemph_tau + dt);
    b_deemph = alpha;
    a_deemph = [1, -(1 - alpha)];
    
    deemphasized_mpx = filter(b_deemph, a_deemph, mpx_normalized);

    % =========================================================
    % 4. Audio Decimation & Lowpass Filtering (Down to 48 kHz)
    % =========================================================
    % Commercial FM mono audio bandwidth is limited to 15 kHz.
    decim_factor = round(fs_rf / fs_audio);
    
    if decim_factor > 1
        % Lowpass anti-aliasing filter before decimation (15 kHz cutoff)
        audio_cutoff = 15e3;
        [b_audio, a_audio] = butter(5, min(0.9, audio_cutoff / (fs_rf / 2)), 'low');
        audio_bandlimited = filter(b_audio, a_audio, deemphasized_mpx);
        
        % Downsample to 48 kHz
        audio_decimated = audio_bandlimited(1 : decim_factor : end);
    else
        audio_decimated = deemphasized_mpx;
    end

    % =========================================================
    % 5. DC Blocking & Volume Normalization
    % =========================================================
    % Remove DC bias from carrier frequency offsets
    audio_ac = audio_decimated - mean(audio_decimated);
    
    % Normalize audio amplitude to [-0.95, +0.95] for clean speaker playback
    peak_val = max(abs(audio_ac));
    if peak_val > 1e-4
        audio_out = 0.90 * (audio_ac / peak_val);
    else
        audio_out = audio_ac;
    end
end
