%% SDR_OPTIMIZATION_STUDY
% =========================================================================
% SDR System Design Optimization & Trade-Off Study: Throughput vs. Reliability
% MathWorks Challenge Project: Build a Wireless Communications Link (Project 162)
% =========================================================================
%
% This study fulfills Step 7 of MathWorks Challenge 162:
%   "Optimize your design for selected criteria such as throughput, or
%    reliability, or your own design criterion."
%
% Comparative Modes Analyzed:
%   1. Mode A: High-Reliability Mode (BPSK + Rate 1/2 Convolutional FEC)
%   2. Mode B: High-Throughput Mode (Uncoded QPSK - 2x Raw Data Rate)
%   3. Mode C: Balanced High-Speed Protected Mode (QPSK + Rate 1/2 FEC)
%   4. Mode D: Standard Baseline (Uncoded BPSK)
%
% Metrics Evaluated:
%   - Bit Error Rate (BER) Waterfall Curve (demonstrating Viterbi Coding Gain)
%   - Effective Throughput (Goodput in kbps) based on CRC-32 Frame Success Rate
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link (Project 162)

clear; close all; clc;

fprintf('========================================================================\n');
fprintf('   SDR COMMUNICATIONS LINK DESIGN OPTIMIZATION & TRADE-OFF STUDY        \n');
fprintf('   Throughput vs. Reliability Evaluation (MathWorks Challenge Step 7)  \n');
fprintf('========================================================================\n\n');

%% 1. SIMULATION PARAMETERS
snr_db_vec = 2.0 : 2.0 : 14.0;      % Channel SNR (Eb/N0) in dB
num_snr_pts = length(snr_db_vec);
num_frames_per_pt = 4;              % Independent frames per point
payload_bits_per_frame = 2000;      % 2000 information bits per frame
baud_rate = 12500;                  % Symbol rate (12.5 kbaud at Fs=100kHz, SPS=8)

% Define Candidate Design Configurations
modes = struct();

% Mode 1: High Reliability (BPSK + FEC)
modes(1).name       = 'BPSK + Rate 1/2 FEC (High Reliability)';
modes(1).mod_scheme = 'BPSK';
modes(1).enable_fec = true;
modes(1).enable_crc = true;
modes(1).color      = [0 0.5 0];      % Dark Green
modes(1).marker     = 's';
modes(1).line_style = '-';
modes(1).raw_rate_bps = baud_rate * 1 * 0.5; % 1 bit/sym * rate 1/2 = 6.25 kbps

% Mode 2: Uncoded BPSK (Baseline)
modes(2).name       = 'Uncoded BPSK (Baseline Reference)';
modes(2).mod_scheme = 'BPSK';
modes(2).enable_fec = false;
modes(2).enable_crc = true;
modes(2).color      = [0 0.45 0.74];   % Blue
modes(2).marker     = 'o';
modes(2).line_style = '--';
modes(2).raw_rate_bps = baud_rate * 1; % 12.5 kbps

% Mode 3: High Throughput (Uncoded QPSK)
modes(3).name       = 'Uncoded QPSK (Maximum Throughput)';
modes(3).mod_scheme = 'QPSK';
modes(3).enable_fec = false;
modes(3).enable_crc = true;
modes(3).color      = [0.85 0.33 0.1]; % Red/Orange
modes(3).marker     = '^';
modes(3).line_style = '-.';
modes(3).raw_rate_bps = baud_rate * 2; % 2 bits/sym = 25.0 kbps

% Mode 4: Protected QPSK (QPSK + FEC)
modes(4).name       = 'QPSK + Rate 1/2 FEC (Balanced Protected)';
modes(4).mod_scheme = 'QPSK';
modes(4).enable_fec = true;
modes(4).enable_crc = true;
modes(4).color      = [0.49 0.18 0.56];% Purple
modes(4).marker     = 'd';
modes(4).line_style = '-';
modes(4).raw_rate_bps = baud_rate * 2 * 0.5; % 12.5 kbps

num_modes = length(modes);

% Base RF Impairments
chan_cfg_base.fs                    = 100000.0;
chan_cfg_base.timing_offset_samples = 2.85;
chan_cfg_base.cfo_hz                = 180.0;
chan_cfg_base.phase_offset_deg      = 35.0;
chan_cfg_base.dc_offset_bias        = 0.12;
chan_cfg_base.gain_imbalance_pct    = 6.0;
chan_cfg_base.phase_imbalance_deg   = 5.0;

rx_cfg.enable_async_detect = false;
rx_cfg.enable_dc_corr      = true;
rx_cfg.enable_gso          = true;
rx_cfg.enable_gardner      = true;
rx_cfg.enable_costas       = true;

%% 2. RUN SYSTEMATIC MONTE CARLO SWEEP
ber_matrix      = zeros(num_modes, num_snr_pts);
goodput_matrix  = zeros(num_modes, num_snr_pts);
crc_pass_matrix = zeros(num_modes, num_snr_pts);

fprintf('Evaluating %d transceiver design configurations across %d SNR points...\n', num_modes, num_snr_pts);
fprintf('------------------------------------------------------------------------------------------------\n');
fprintf('  SNR (dB)  |  Mode 1 (BPSK+FEC)  |  Mode 2 (BPSK Raw)  |  Mode 3 (QPSK Raw)  |  Mode 4 (QPSK+FEC) \n');
fprintf('------------------------------------------------------------------------------------------------\n');

for s_idx = 1 : num_snr_pts
    curr_snr = snr_db_vec(s_idx);
    chan_cfg = chan_cfg_base;
    chan_cfg.snr_db = curr_snr;
    
    row_bers = zeros(num_modes, 1);
    
    for m = 1 : num_modes
        mode = modes(m);
        
        tx_cfg.source_type      = 'random';
        tx_cfg.num_payload_bits = payload_bits_per_frame;
        tx_cfg.sps              = 8;
        tx_cfg.beta             = 0.35;
        tx_cfg.span             = 8;
        tx_cfg.mod_scheme       = mode.mod_scheme;
        tx_cfg.enable_fec       = mode.enable_fec;
        tx_cfg.enable_crc       = mode.enable_crc;
        
        total_bit_errors = 0;
        total_info_bits  = 0;
        frames_passed    = 0;
        
        for f = 1 : num_frames_per_pt
            tx_cfg.seed = 5000 * m + 100 * s_idx + f;
            
            % Transmit -> Channel -> Receive
            tx_data = sdr_tx(tx_cfg);
            chan_data = sdr_channel(tx_data, chan_cfg);
            rx_data = sdr_rx(chan_data, tx_data, rx_cfg);
            
            total_bit_errors = total_bit_errors + rx_data.bit_errors;
            total_info_bits  = total_info_bits + length(rx_data.ref_bits);
            if rx_data.crc_pass
                frames_passed = frames_passed + 1;
            end
        end
        
        empirical_ber = total_bit_errors / max(1, total_info_bits);
        frame_success_rate = frames_passed / num_frames_per_pt;
        
        ber_matrix(m, s_idx) = empirical_ber;
        crc_pass_matrix(m, s_idx) = frame_success_rate;
        % Goodput in kbps = Raw Rate * Frame Success Rate (1 - FER)
        goodput_matrix(m, s_idx) = (mode.raw_rate_bps * frame_success_rate) / 1000.0;
        row_bers(m) = empirical_ber;
    end
    
    fprintf('   %+5.1f    |     %9.2e     |     %9.2e     |     %9.2e     |     %9.2e\n', ...
        curr_snr, row_bers(1), row_bers(2), row_bers(3), row_bers(4));
end
fprintf('------------------------------------------------------------------------------------------------\n\n');

%% 3. VISUALIZATION DASHBOARD: OPTIMIZATION TRADE-OFF STUDY
h_fig = figure('Name', 'SDR Design Optimization Study: Throughput vs. Reliability', ...
    'Position', [100, 100, 1150, 520], 'Color', 'w');

% Subplot 1: Bit Error Rate (BER) Waterfall Curves & Viterbi Coding Gain
subplot(1, 2, 1);
% Analytical AWGN curves
snr_dense = linspace(1, 15, 200);
eb_n0_lin = 10 .^ (snr_dense / 10);
ber_theor_bpsk = 0.5 * erfc(sqrt(eb_n0_lin));

semilogy(snr_dense, ber_theor_bpsk, 'k:', 'LineWidth', 1.5);
hold on;

for m = 1 : num_modes
    semilogy(snr_db_vec, max(ber_matrix(m, :), 1e-6), ...
        'Color', modes(m).color, 'LineStyle', modes(m).line_style, ...
        'Marker', modes(m).marker, 'LineWidth', 1.8, 'MarkerSize', 7, ...
        'MarkerFaceColor', modes(m).color);
end

grid on;
set(gca, 'YScale', 'log');
xlim([1, 15]); ylim([1e-5, 1.0]);
xlabel('Channel SNR: E_b / N_0 (dB)', 'FontSize', 11);
ylabel('Information Bit Error Rate (BER)', 'FontSize', 11);
title({'1. Reliability Analysis: BER Waterfall Curves', 'Empirical Closed-Loop SDR Link under RF Impairments'}, 'FontSize', 11);
legend_entries = [{'Theoretical AWGN (Uncoded)'}, {modes.name}];
legend(legend_entries, 'Location', 'southwest', 'FontSize', 9);

% Subplot 2: Effective Goodput (Throughput in kbps) vs SNR
subplot(1, 2, 2);

for m = 1 : num_modes
    plot(snr_db_vec, goodput_matrix(m, :), ...
        'Color', modes(m).color, 'LineStyle', modes(m).line_style, ...
        'Marker', modes(m).marker, 'LineWidth', 1.8, 'MarkerSize', 7, ...
        'MarkerFaceColor', modes(m).color);
    hold on;
end

grid on;
xlim([1, 15]); ylim([0, 27]);
xlabel('Channel SNR: E_b / N_0 (dB)', 'FontSize', 11);
ylabel('Effective Goodput (kbps)', 'FontSize', 11);
title({'2. Throughput Analysis: CRC-Verified Goodput', 'Goodput = R_{info} \times (1 - FER) vs. Channel Quality'}, 'FontSize', 11);
legend({modes.name}, 'Location', 'northwest', 'FontSize', 9);

% Highlight Operating Regimes
xline(6.0, 'm--', 'Low-SNR Boundary', 'LabelVerticalAlignment', 'bottom');
xline(10.0, 'b--', 'High-Throughput Boundary', 'LabelVerticalAlignment', 'bottom');

fprintf('Optimization trade-off study figures generated successfully.\n');
