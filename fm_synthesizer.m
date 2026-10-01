function [rf_iq_signal, orig_audio, fs_rf, fs_audio] = fm_synthesizer(duration_sec, snr_db, cfo_hz)
% FM_SYNTHESIZER - High-Fidelity Synthetic Commercial FM Broadcast Station
%
% Syntax:
%   [rf_iq_signal, orig_audio, fs_rf, fs_audio] = fm_synthesizer(duration_sec, snr_db, cfo_hz)
%
% Inputs:
%   duration_sec - Duration of the broadcast in seconds (e.g., 5.0)
%   snr_db       - Channel SNR in dB (e.g., 25.0)
%   cfo_hz       - Carrier Frequency Offset in Hz (e.g., 500.0)
%
% Outputs:
%   rf_iq_signal - Corrupted complex baseband I/Q signal representing the FM station
%   orig_audio   - Original acoustic audio track for comparison
%   fs_rf        - RF baseband sampling rate (240 kHz)
%   fs_audio     - Audio sampling rate (48 kHz)
%
% Features:
%   - Multi-harmonic acoustic melody (synthesized musical chord progression)
%   - 75 μs standard broadcast pre-emphasis filter
%   - 19 kHz Stereo Pilot Tone & 57 kHz RDS subcarrier injection
%   - Wideband FM Phase Integration (Δf = ±75 kHz)
%   - RF multipath fading and AWGN channel emulation
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link - Commercial FM Receiver

    if nargin < 1 || isempty(duration_sec), duration_sec = 5.0; end
    if nargin < 2 || isempty(snr_db),       snr_db = 25.0; end
    if nargin < 3 || isempty(cfo_hz),       cfo_hz = 0.0; end

    fs_audio = 48000; % 48 kHz standard audio rate
    fs_rf    = 240000; % 240 kHz RF baseband rate (oversampling factor = 5)
    delta_f  = 75e3;   % ±75 kHz standard FM broadcast maximum frequency deviation

    % =========================================================
    % 1. Synthesize Acoustic Audio Track (Musical Progression)
    % =========================================================
    t_audio = (0 : 1/fs_audio : duration_sec - 1/fs_audio)';
    
    % Synthesize an acoustic chord progression: C maj -> G maj -> A min -> F maj
    orig_audio = zeros(size(t_audio));
    chord_duration = 1.25; % seconds per chord
    
    % Musical note frequencies in Hz
    notes.C4 = 261.63; notes.E4 = 329.63; notes.G4 = 392.00;
    notes.D4 = 293.66; notes.B3 = 246.94;
    notes.A3 = 220.00; notes.C5 = 523.25;
    notes.F3 = 174.61; notes.A4 = 440.00;
    
    chord_map = {
        [notes.C4, notes.E4, notes.G4], ...       % C Major
        [notes.G4, notes.B3, notes.D4], ...       % G Major
        [notes.A3, notes.C4, notes.E4], ...       % A Minor
        [notes.F3, notes.A4, notes.C5]            % F Major
    };

    for ch = 1 : length(chord_map)
        idx_start = round((ch - 1) * chord_duration * fs_audio) + 1;
        idx_end   = min(length(t_audio), round(ch * chord_duration * fs_audio));
        t_seg = t_audio(idx_start : idx_end);
        
        freqs = chord_map{ch};
        seg_audio = zeros(size(t_seg));
        for fn = 1 : length(freqs)
            f0 = freqs(fn);
            % Fundamental + natural acoustic harmonics
            seg_audio = seg_audio + 0.40 * sin(2 * pi * f0 * t_seg) + ...
                                    0.25 * sin(2 * pi * 2 * f0 * t_seg) + ...
                                    0.10 * sin(2 * pi * 3 * f0 * t_seg);
        end
        % Apply smooth Hann envelope to prevent clicking
        env = hann(length(seg_audio));
        orig_audio(idx_start : idx_end) = seg_audio .* env;
    end

    % Normalize audio
    orig_audio = 0.85 * (orig_audio / max(abs(orig_audio)));

    % =========================================================
    % 2. Resample Audio to RF Baseband Rate (240 kHz)
    % =========================================================
    upsample_factor = round(fs_rf / fs_audio);
    m_rf = interp(orig_audio, upsample_factor);
    t_rf = (0 : length(m_rf) - 1)' / fs_rf;

    % =========================================================
    % 3. Standard FM Pre-Emphasis Filter (75 μs)
    % =========================================================
    % Pre-emphasis highpass: H_pre(s) = 1 + s * tau
    tau = 75e-6;
    dt = 1 / fs_rf;
    b_pre = [1 + tau / dt, -tau / dt];
    a_pre = 1;
    m_preemphasized = filter(b_pre, a_pre, m_rf);
    
    % Bound amplitude to avoid over-deviation
    m_preemphasized = 0.80 * (m_preemphasized / max(abs(m_preemphasized) + 1e-6));

    % =========================================================
    % 4. Inject 19 kHz Stereo Pilot & 57 kHz RDS Subcarrier
    % =========================================================
    pilot_19k = 0.09 * sin(2 * pi * 19e3 * t_rf); % 9% injection for 19 kHz pilot
    rds_57k   = 0.05 * sin(2 * pi * 57e3 * t_rf); % 5% injection for 57 kHz RDS
    
    mpx_composite = m_preemphasized + pilot_19k + rds_57k;

    % =========================================================
    % 5. Wideband Frequency Modulation (WBFM Phase Integration)
    % =========================================================
    % s(t) = exp( j * 2π * Δf * ∫ mpx(τ) dτ )
    integrated_phase = 2 * pi * delta_f * cumsum(mpx_composite) / fs_rf;
    tx_rf = exp(1j * integrated_phase);

    % =========================================================
    % 6. Channel Impairments (CFO, Multipath, and AWGN Noise)
    % =========================================================
    % Carrier frequency offset
    if cfo_hz ~= 0
        cfo_rot = exp(1j * (2 * pi * cfo_hz * t_rf));
        tx_rf = tx_rf .* cfo_rot;
    end

    % 2-Ray Multipath Fading (Direct line-of-sight + reflected ray)
    delay_samples = 3;
    reflected_ray = [zeros(delay_samples, 1); tx_rf(1:end-delay_samples)];
    tx_faded = tx_rf + 0.15 * exp(1j * 0.7) * reflected_ray;

    % AWGN Channel Noise
    snr_linear = 10 ^ (snr_db / 10);
    p_signal = mean(abs(tx_faded) .^ 2);
    p_noise = p_signal / snr_linear;
    noise_sigma = sqrt(p_noise / 2);
    
    noise = noise_sigma * (randn(size(tx_faded)) + 1j * randn(size(tx_faded)));
    rf_iq_signal = tx_faded + noise;
end
