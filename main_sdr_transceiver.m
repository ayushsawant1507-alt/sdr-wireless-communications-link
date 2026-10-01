%% MAIN_SDR_TRANSCEIVER
% =========================================================================
% Software-Defined Radio (SDR) Wireless Communications Link Simulator
% MathWorks Challenge Project: Build a Wireless Communications Link (Project 162)
% =========================================================================
%
% Features:
%   1. Full Transmit/Receive Baseband Chain (BPSK/QPSK, RRC Pulse Shaping)
%   2. RF Hardware Impairments (Clock Drift, CFO, Phase Offset, DC Bias, IQ Imbalance)
%   3. Complete Receiver Calibration Chain (DC Removal, GSO, Gardner TED, Costas PLL)
%   4. 11-bit Barker Preamble Packet Framing & 180° Phase Ambiguity Resolver
%   5. Comprehensive 4-Panel Visualization Dashboard & Console Diagnostics
%
% Author: DSP & Communications Systems Engineer

clear; close all; clc;

fprintf('========================================================================\n');
fprintf('   SOFTWARE-DEFINED RADIO (SDR) TRANSCEIVER SIMULATOR - MATLAB ENGINE   \n');
fprintf('   MathWorks Challenge Project 162: Wireless Communications Link        \n');
fprintf('========================================================================\n\n');

%% 1. SYSTEM CONFIGURATION & PARAMETERS
% --- Transmitter Parameters ---
tx_cfg.source_type      = 'text';  % Payload source: 'text', 'image', or 'random'
tx_cfg.source_text      = 'MathWorks SDR Challenge 162: Wireless Link with Pluto/USRP!';
tx_cfg.num_payload_bits = 4000;    % Payload bits (used if source_type is 'random')
tx_cfg.sps              = 8;       % Samples per symbol (oversampling factor)
tx_cfg.beta             = 0.35;    % Root-Raised-Cosine roll-off factor
tx_cfg.span             = 8;       % Filter span in symbols
tx_cfg.mod_scheme       = 'QPSK';  % Modulation scheme: 'BPSK' or 'QPSK'
tx_cfg.enable_crc       = true;    % Enable IEEE 802.3 CRC-32 Checksum
tx_cfg.enable_fec       = true;    % Enable Rate 1/2 K=7 Convolutional + Viterbi FEC
tx_cfg.seed             = 42;      % RNG Seed for reproducibility

% --- Channel & Hardware Impairment Parameters ---
chan_cfg.fs                    = 100000.0; % Sampling frequency (100 kHz)
chan_cfg.snr_db                = 16.0;     % Channel SNR: Eb/N0 in dB
chan_cfg.timing_offset_samples = 3.25;     % Fractional symbol delay (0 to SPS-1)
chan_cfg.cfo_hz                = 250.0;    % Carrier Frequency Offset in Hz
chan_cfg.phase_offset_deg      = 45.0;     % Carrier Phase Offset in degrees
chan_cfg.dc_offset_bias        = 0.15;     % LO self-mixing DC leakage magnitude
chan_cfg.gain_imbalance_pct    = 8.0;      % I/Q amplitude gain imbalance (%)
chan_cfg.phase_imbalance_deg   = 6.0;      % I/Q quadrature phase imbalance (deg)

% --- Receiver Calibration Switches ---
rx_cfg.enable_dc_corr  = true;     % Stage 1: DC Estimation & Subtraction
rx_cfg.enable_gso      = true;     % Stage 2: Gram-Schmidt I/Q Orthogonalization
rx_cfg.enable_gardner  = true;     % Stage 4: Gardner Symbol Timing Recovery
rx_cfg.enable_costas   = true;     % Stage 5: Costas Phase-Locked Loop (PLL)

%% 2. EXECUTE TRANSCEIVER PIPELINE
fprintf('[1/3] Generating Transmit Waveform (RRC Pulse-Shaped)...\n');
tx_data = sdr_tx(tx_cfg);

fprintf('[2/3] Simulating RF Impairments & AWGN Channel...\n');
chan_data = sdr_channel(tx_data, chan_cfg);

fprintf('[3/3] Executing Receiver DSP Calibration & Synchronization...\n');
rx_data = sdr_rx(chan_data, tx_data, rx_cfg);

%% 3. PERFORMANCE EVALUATION & CONSOLE REPORT
eb_n0_lin = 10.0 ^ (chan_cfg.snr_db / 10.0);
ber_theoretical = 0.5 * erfc(sqrt(eb_n0_lin));
est_cfo = rx_data.freq_estimates_hz(end);
cfo_err = abs(est_cfo - chan_cfg.cfo_hz);

fprintf('\n------------------------------------------------------------------------\n');
fprintf('                        LINK PERFORMANCE SUMMARY                        \n');
fprintf('------------------------------------------------------------------------\n');
fprintf('  Payload Bits Transmitted  : %d bits\n', length(tx_data.payload_bits));
if strcmpi(tx_data.source_type, 'text')
    fprintf('  Source Payload Type       : Text Message (%d characters)\n', length(tx_data.source_text));
    fprintf('  Transmitted Text          : "%s"\n', tx_data.source_text);
    fprintf('  Received Decoded Text     : "%s"\n', rx_data.rx_text);
elseif strcmpi(tx_data.source_type, 'image')
    fprintf('  Source Payload Type       : Image Bitmap (%dx%d pixels)\n', tx_data.img_dims(1), tx_data.img_dims(2));
end
fprintf('  Channel Bits (with FEC)   : %d bits (Rate 1/2 Convolutional)\n', length(tx_data.channel_bits));
fprintf('  Channel SNR (Eb/N0)       : %.1f dB (Linear: %.2f)\n', chan_cfg.snr_db, eb_n0_lin);
fprintf('  Injected CFO              : %.1f Hz\n', chan_cfg.cfo_hz);
fprintf('  Estimated CFO (Costas)    : %.1f Hz (Residual Error: %.2f Hz)\n', est_cfo, cfo_err);
fprintf('  Injected DC Magnitude     : %.3f V\n', abs(chan_data.dc_true));
fprintf('  Estimated DC Magnitude    : %.3f V (%+.3f %+.3fj)\n', abs(rx_data.dc_est), real(rx_data.dc_est), imag(rx_data.dc_est));
fprintf('  Barker Sync Peak Value    : %.2f (Peak at symbol index: %d)\n', rx_data.peak_val, rx_data.peak_idx);
fprintf('  180-deg Phase Ambiguity   : Inversion Factor = %+d\n', rx_data.ambig_sign);
if rx_data.fec_applied
    fprintf('  Raw Channel BER (Pre-FEC) : %.4e (%d channel errors)\n', rx_data.channel_ber, rx_data.channel_bit_errors);
end
if rx_data.crc_applied
    if rx_data.crc_pass
        crc_str = '[PASS] Clean Packet Verified';
    else
        crc_str = sprintf('[FAIL] %d Parity Errors Detected', rx_data.crc_parity_errs);
    end
    fprintf('  CRC-32 Checksum Status    : %s\n', crc_str);
end
fprintf('  Bit Errors in Payload     : %d / %d bits\n', rx_data.bit_errors, length(rx_data.ref_bits));
fprintf('  Final Info BER (Post-FEC) : %.4e\n', rx_data.ber);
fprintf('  Theoretical Uncoded BER   : %.4e\n', ber_theoretical);
if rx_data.ber == 0
    fprintf('  Status                    : [SUCCESS] PERFECT ERROR-FREE LINK ACHIEVED!\n');
elseif rx_data.ber < 1e-2
    fprintf('  Status                    : [SUCCESS] LINK SYNCHRONIZED (Within Expected Noise Threshold)\n');
else
    fprintf('  Status                    : [WARNING] HIGH BER - CHECK CALIBRATION TOGGLES\n');
end
fprintf('------------------------------------------------------------------------\n\n');

%% 4. VISUALIZATION DASHBOARD

% Setup clean figure styles
set(0, 'DefaultAxesFontSize', 10);
set(0, 'DefaultLineLineWidth', 1.5);

% -------------------------------------------------------------------------
% FIGURE 1: Dual-Pane Constellation Comparison
% -------------------------------------------------------------------------
h_fig1 = figure('Name', 'SDR Constellation Analysis', 'Position', [80, 100, 1100, 500], 'Color', 'w');

% Left Subplot: Raw Impaired Front-End Constellation
subplot(1, 2, 1);
raw_pts = chan_data.raw_decimated_symbols(1 : min(1500, length(chan_data.raw_decimated_symbols)));
plot(real(raw_pts), imag(raw_pts), '.', 'Color', [0.85 0.33 0.10 0.6], 'MarkerSize', 8);
hold on;
plot(real(chan_data.dc_true), imag(chan_data.dc_true), 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'y');
grid on; axis equal;
xlim([-2.5 2.5]); ylim([-2.5 2.5]);
xlabel('In-Phase (I)'); ylabel('Quadrature (Q)');
title({'Raw Impaired Front-End Constellation', sprintf('CFO: %.0f Hz | DC: %.2fV | IQ Imb: %.0f%%/%.0f°', ...
    chan_cfg.cfo_hz, chan_cfg.dc_offset_bias, chan_cfg.gain_imbalance_pct, chan_cfg.phase_imbalance_deg)});
legend('Impaired Cloud (Spinning)', 'Injected DC Center', 'Location', 'northeast');

% Right Subplot: Calibrated & Synchronized Output Constellation
subplot(1, 2, 2);
cal_start = rx_data.peak_idx + 11;
cal_pts = rx_data.resolved_symbols(cal_start : min(cal_start + 1500, length(rx_data.resolved_symbols)));
plot(real(cal_pts), imag(cal_pts), '.', 'Color', [0 0.45 0.74 0.7], 'MarkerSize', 9);
hold on;
if strcmpi(tx_cfg.mod_scheme, 'QPSK')
    ideal_pts = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2);
    plot(real(ideal_pts), imag(ideal_pts), 'r+', 'MarkerSize', 14, 'LineWidth', 2);
    xline(0, 'r--', 'Decision Boundary', 'LineWidth', 1.2);
    yline(0, 'r--', 'Decision Boundary', 'LineWidth', 1.2);
else
    plot([-1 1], [0 0], 'r+', 'MarkerSize', 14, 'LineWidth', 2);
    xline(0, 'r--', 'Decision Boundary', 'LineWidth', 1.2, 'LabelVerticalAlignment', 'top');
end
grid on; axis equal;
xlim([-2.5 2.5]); ylim([-2.5 2.5]);
xlabel('In-Phase (I)'); ylabel('Quadrature (Q)');
if isreal(rx_data.ambig_sign)
    ambig_str = sprintf('%+d', rx_data.ambig_sign);
else
    ambig_str = sprintf('%+.0f%+.0fj', real(rx_data.ambig_sign), imag(rx_data.ambig_sign));
end
title({'Calibrated & Synchronized Constellation', sprintf('Mod: %s | BER: %.2e (%d errors) | Ambiguity: %s', ...
    tx_cfg.mod_scheme, rx_data.ber, rx_data.bit_errors, ambig_str)});
legend(sprintf('Recovered %s Symbols', tx_cfg.mod_scheme), 'Ideal Reference Points', 'Location', 'northeast');

% -------------------------------------------------------------------------
% FIGURE 2: Closed-Loop Convergence Dynamics (Gardner & Costas)
% -------------------------------------------------------------------------
h_fig2 = figure('Name', 'SDR Closed-Loop Convergence', 'Position', [100, 120, 1100, 520], 'Color', 'w');

% Gardner Timing Error Transient
subplot(2, 1, 1);
plot(rx_data.gardner_errors(1 : min(600, length(rx_data.gardner_errors))), 'b', 'LineWidth', 1.3);
hold on; yline(0, 'r--', 'Zero Error');
grid on;
xlabel('Symbol Index (k)'); ylabel('Timing Error Metric');
title('1. Gardner Timing Error Detector (TED) Transient Settling');
legend('e_t[k] (Gardner TED)', 'Target Strobe', 'Location', 'northeast');

% Costas Carrier Frequency Acquisition & Phase Error
subplot(2, 1, 2);
yyaxis left;
plot(rx_data.freq_estimates_hz(1 : min(600, length(rx_data.freq_estimates_hz))), 'Color', [0 0.5 0], 'LineWidth', 1.8);
hold on;
yline(chan_cfg.cfo_hz, 'm--', sprintf('True CFO (%.0f Hz)', chan_cfg.cfo_hz), 'LineWidth', 1.3);
ylabel('Estimated CFO (Hz)');
ylim([min(0, chan_cfg.cfo_hz - 50), chan_cfg.cfo_hz + 100]);

yyaxis right;
plot(rx_data.phase_errors(1 : min(600, length(rx_data.phase_errors))), 'Color', [0.85 0.33 0.1 0.4], 'LineWidth', 1);
ylabel('Phase Error (rad)');

grid on;
xlabel('Symbol Index (k)');
title('2. 2nd-Order Costas Loop Carrier Frequency & Phase Acquisition');
legend('Estimated CFO (Hz)', 'True CFO Target', 'Phase Error e_p[k]', 'Location', 'northeast');

% -------------------------------------------------------------------------
% FIGURE 3: Time-Domain Waveforms & Eye Diagram
% -------------------------------------------------------------------------
h_fig3 = figure('Name', 'SDR Time-Domain & Eye Diagram', 'Position', [120, 140, 1100, 550], 'Color', 'w');

% Waveform Evolution
subplot(2, 1, 1);
disp_syms = 25;
sps = tx_cfg.sps;
t_disp = (0 : disp_syms * sps - 1) / sps;
fir_del = chan_data.fir_delay_total;

tx_wave = real(tx_data.tx_signal(1 : disp_syms * sps));
rx_filt_wave = real(filter(tx_data.h_rrc, 1, chan_data.rx_impaired_signal));
rx_filt_slice = rx_filt_wave(fir_del + 1 : fir_del + disp_syms * sps);

plot(t_disp, tx_wave, 'Color', [0 0.45 0.74], 'LineWidth', 1.5);
hold on;
plot(t_disp, rx_filt_slice, 'Color', [0.49 0.18 0.56], 'LineWidth', 1.3);
strobe_t = (0 : disp_syms - 1);
strobe_vals = real(rx_data.resolved_symbols(1 : disp_syms));
plot(strobe_t, strobe_vals, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', [0.47 0.67 0.19]);
grid on;
xlabel('Symbol Period (t / T_s)'); ylabel('Amplitude');
title('Transceiver Waveform Evolution (Tx vs. Rx Matched Filter Output)');
legend('Tx RRC Pulse-Shaped Waveform x(t)', 'Rx Matched Filter Waveform y(t)', 'Decimated Strobe Points', 'Location', 'northeast');

% In-Phase Eye Diagram
subplot(2, 1, 2);
eye_syms = min(300, length(rx_data.resolved_symbols) - 4);
eye_span = 2 * sps;
t_eye = linspace(-1, 1, eye_span + 1);

rx_mf_clean = real(filter(tx_data.h_rrc, 1, chan_data.rx_impaired_signal));
hold on;
for i = 0 : 2 : eye_syms
    idx_start = fir_del + i * sps + 1;
    if idx_start + eye_span <= length(rx_mf_clean)
        seg = rx_mf_clean(idx_start : idx_start + eye_span);
        plot(t_eye, seg, 'Color', [0 0.45 0.74 0.18], 'LineWidth', 1.1);
    end
end
xline(0, 'g--', 'Optimal Strobe (t=0)', 'LineWidth', 1.5);
yline(0, 'r:', 'Decision Threshold', 'LineWidth', 1.2);
grid on;
xlim([-1 1]); ylim([-2.2 2.2]);
xlabel('Normalized Time (t / T_s)'); ylabel('In-Phase Amplitude');
title('In-Phase (I) Eye Diagram (Folded over 2 T_s)');

% -------------------------------------------------------------------------
% FIGURE 4: Barker Cross-Correlation & Frame Layout
% -------------------------------------------------------------------------
h_fig4 = figure('Name', 'SDR Frame Synchronization', 'Position', [140, 160, 950, 420], 'Color', 'w');

x_corr = rx_data.search_start : (rx_data.search_start + length(rx_data.barker_corr) - 1);
plot(x_corr, rx_data.barker_corr, 'b.-', 'LineWidth', 1.3, 'MarkerSize', 10);
hold on;
plot(rx_data.peak_idx, rx_data.peak_val, 'rp', 'MarkerSize', 14, 'MarkerFaceColor', 'g');
grid on;
xlabel('Symbol Index (Search Window)'); ylabel('Cross-Correlation Magnitude');
title(sprintf('11-Bit Barker Preamble Sync (Peak Magnitude: %.1f at Index %d)', rx_data.peak_val, rx_data.peak_idx));
legend('Cross-Correlation Profile', 'Detected Sync Peak (Frame Boundary)', 'Location', 'northeast');

fprintf('Visualization figures generated successfully.\n');
