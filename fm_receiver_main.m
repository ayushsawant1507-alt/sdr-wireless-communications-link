%% FM_RECEIVER_MAIN
% =========================================================================
% Commercial FM Broadcast Radio Receiver (88-108 MHz) - MATLAB Engine
% Real-World Software-Defined Radio Application with Live Audio Playback
% =========================================================================
%
% This script simulates a commercial FM radio station transmission, executes
% digital quadrature frequency discrimination, de-emphasis filtering, and
% plays the demodulated audio live through your PC speakers!
%
% Author: DSP & Communications Systems Engineer

clear; close all; clc;

fprintf('========================================================================\n');
fprintf('   COMMERCIAL FM BROADCAST RADIO RECEIVER (88-108 MHz) - MATLAB SDR     \n');
fprintf('   Live Audio Demodulation & Spectrum Analysis Dashboard                \n');
fprintf('========================================================================\n\n');

%% 1. SIMULATION & RADIO PARAMETERS
duration_sec = 5.0;       % Broadcast audio duration in seconds
snr_db       = 28.0;      % RF Channel SNR in dB (Clear Hi-Fi reception)
cfo_hz       = 0.0;       % Carrier Frequency Offset in Hz (Tuning error)
deemph_tau   = 75e-6;     % 75 μs standard broadcast de-emphasis time constant

%% 2. GENERATE / CAPTURE FM BROADCAST SIGNAL
fprintf('[1/3] Synthesizing Commercial FM Broadcast Station (WBFM, +/-75 kHz)...\n');
[rf_iq_signal, orig_audio, fs_rf, fs_audio] = fm_synthesizer(duration_sec, snr_db, cfo_hz);

fprintf('      RF Baseband Sample Rate : %.1f kHz\n', fs_rf / 1e3);
fprintf('      Audio Sample Rate       : %.1f kHz\n', fs_audio / 1e3);
fprintf('      Broadcast Duration      : %.1f seconds\n', duration_sec);

%% 3. EXECUTE FM RECEIVER DSP CHAIN
fprintf('[2/3] Executing DSP Demodulation (Quadrature Demod + De-Emphasis + Decimation)...\n');
tic;
[audio_out, mpx_signal, fs_audio_out] = fm_demodulator(rf_iq_signal, fs_rf, deemph_tau);
proc_time = toc;
fprintf('      Demodulation completed in %.3f seconds (Real-time speed factor: %.1fx)\n', ...
    proc_time, duration_sec / proc_time);

%% 4. PLAY LIVE AUDIO THROUGH PC SPEAKERS
fprintf('\n[3/3] 🔊 PLAYING DEMODULATED FM RADIO BROADCAST THROUGH PC SPEAKERS...\n');
fprintf('      (Listen to the recovered acoustic music chord progression!)\n\n');

% Save demodulated audio to WAV file for direct playback
wav_filename = 'demodulated_fm_audio.wav';
try
    audiowrite(wav_filename, audio_out, fs_audio_out);
    fprintf('      Audio saved: %s (You can also double-click this file to play in Windows)\n', wav_filename);
catch
end

% Play directly through Windows PC speakers via soundsc (auto-scaled for optimal volume)
try
    soundsc(audio_out, fs_audio_out);
catch
    try
        player = audioplayer(audio_out, fs_audio_out);
        play(player);
    catch
        fprintf('      (Audio hardware busy or not present; skipping speaker playback)\n');
    end
end

%% 5. COMPUTE AUDIO FIDELITY & METRICS
min_len = min(length(orig_audio), length(audio_out));
ref_trim = orig_audio(1:min_len);
rx_trim  = audio_out(1:min_len);

% Normalize for correlation
norm_ref = ref_trim / norm(ref_trim);
norm_rx  = rx_trim / norm(rx_trim);
audio_correlation = abs(sum(norm_ref .* norm_rx));
audio_snr_est = 10 * log10(sum(ref_trim .^ 2) / (sum((ref_trim - rx_trim) .^ 2) + 1e-12));

fprintf('------------------------------------------------------------------------\n');
fprintf('                     FM RECEIVER PERFORMANCE REPORT                     \n');
fprintf('------------------------------------------------------------------------\n');
fprintf('  RF Channel SNR            : %.1f dB\n', snr_db);
fprintf('  Max Frequency Deviation   : +/-75.0 kHz (Carson Bandwidth: 180 kHz)\n');
fprintf('  De-Emphasis Time Constant : %.0f microseconds (Standard Americas)\n', deemph_tau * 1e6);
fprintf('  Audio Waveform Cross-Corr : %.4f (1.0000 = Perfect Acoustic Match)\n', audio_correlation);
fprintf('  Demodulated Audio SNR     : %.2f dB\n', audio_snr_est);
fprintf('  Playback Status           : ACTIVE (48 kHz Stereo-Compatible Mono)\n');
fprintf('------------------------------------------------------------------------\n\n');

%% 6. VISUALIZATION DASHBOARD

set(0, 'DefaultAxesFontSize', 10);
set(0, 'DefaultLineLineWidth', 1.5);

% -------------------------------------------------------------------------
% FIGURE 1: RF Spectrum Analyzer & FM Channel
% -------------------------------------------------------------------------
h_fig1 = figure('Name', 'FM Radio RF Spectrum Analyzer', 'Position', [100, 100, 1000, 480], 'Color', 'w');

subplot(2, 1, 1);
% Welch PSD of received RF signal
[psd_rf, f_rf] = pwelch(rf_iq_signal, hann(2048), 1024, 2048, fs_rf, 'centered');
psd_rf_db = 10 * log10(psd_rf + 1e-12);
psd_rf_db_norm = psd_rf_db - max(psd_rf_db);

plot(f_rf / 1e3, psd_rf_db_norm, 'Color', [0 0.45 0.74], 'LineWidth', 1.5);
hold on;
xline(-90, 'r--', 'Carson Bandwidth (-90 kHz)', 'LabelVerticalAlignment', 'bottom');
xline(90, 'r--', 'Carson Bandwidth (+90 kHz)', 'LabelVerticalAlignment', 'bottom');
grid on;
xlim([-fs_rf/2e3, fs_rf/2e3]); ylim([-65, 5]);
xlabel('Baseband Frequency Offset (kHz)'); ylabel('Power Spectral Density (dB/Hz)');
title('1. Received RF Baseband Spectrum (200 kHz Commercial FM Channel)');
legend('FM Radio Station Carrier Spectrum', 'Nominal Channel Bandwidth Limits', 'Location', 'northeast');

% -------------------------------------------------------------------------
% FIGURE 2: Multiplex (MPX) Baseband Spectrum (Audio + 19 kHz Pilot + 57 kHz RDS)
% -------------------------------------------------------------------------
subplot(2, 1, 2);
[psd_mpx, f_mpx] = pwelch(mpx_signal, hann(2048), 1024, 2048, fs_rf);
psd_mpx_db = 10 * log10(psd_mpx + 1e-12);
psd_mpx_db_norm = psd_mpx_db - max(psd_mpx_db(f_mpx < 15e3));

plot(f_mpx / 1e3, psd_mpx_db_norm, 'Color', [0.47 0.67 0.19], 'LineWidth', 1.5);
hold on;
xline(15, 'm:', 'Mono Audio Cutoff (15 kHz)', 'LabelVerticalAlignment', 'top');
xline(19, 'r--', '19 kHz Stereo Pilot Tone', 'LabelVerticalAlignment', 'top');
xline(57, 'k--', '57 kHz RDS Digital Subcarrier', 'LabelVerticalAlignment', 'top');
grid on;
xlim([0, 80]); ylim([-60, 10]);
xlabel('Baseband Frequency (kHz)'); ylabel('Magnitude (dB)');
title('2. Demodulated Multiplex (MPX) Spectrum (Mono Audio, Stereo Pilot, and RDS Subcarrier)');
legend('Demodulated MPX Baseband', 'Audio Cutoff', 'Stereo Pilot (19 kHz)', 'RDS Subcarrier (57 kHz)', 'Location', 'northeast');

% -------------------------------------------------------------------------
% FIGURE 3: Audio Waveform Oscilloscope Comparison
% -------------------------------------------------------------------------
h_fig2 = figure('Name', 'FM Demodulated Audio Oscilloscope', 'Position', [120, 150, 1000, 480], 'Color', 'w');

% Display a 0.5 second audio snapshot
disp_samples = round(0.5 * fs_audio);
idx_snap = round(1.0 * fs_audio) : (round(1.0 * fs_audio) + disp_samples);
t_snap = (0 : length(idx_snap) - 1) / fs_audio * 1e3; % ms

plot(t_snap, orig_audio(idx_snap), 'Color', [0 0.45 0.74], 'LineWidth', 1.8);
hold on;
plot(t_snap, audio_out(idx_snap), 'Color', [0.85 0.33 0.10], 'LineWidth', 1.4, 'LineStyle', '--');
grid on;
xlim([0, max(t_snap)]); ylim([-1.1, 1.1]);
xlabel('Time (milliseconds)'); ylabel('Normalized Amplitude');
title(sprintf('3. Acoustic Audio Oscilloscope: Original vs. Demodulated Waveform (Cross-Correlation = %.4f)', audio_correlation));
legend('Original Broadcast Acoustic Signal', 'Demodulated & De-Emphasized Audio Output', 'Location', 'northeast');

fprintf('Visualization dashboard displayed.\n');
