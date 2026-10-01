%% SDR_BER_SWEEP
% =========================================================================
% Monte Carlo Bit Error Rate (BER) Waterfall Curve vs. Theoretical AWGN
% MathWorks Challenge Project: Build a Wireless Communications Link (Project 162)
% =========================================================================
%
% This script runs a multi-point Monte Carlo sweep across channel SNRs
% and compares the empirical bit error rate against the analytical Q-function:
%   P_e = Q(sqrt(2 * Eb/N0)) = 0.5 * erfc(sqrt(Eb/N0))
%
% Author: DSP & Communications Systems Engineer

clear; close all; clc;

fprintf('========================================================================\n');
fprintf('   MONTE CARLO BIT ERROR RATE (BER) SWEEP - MATLAB ENGINE               \n');
fprintf('========================================================================\n\n');

%% 1. SWEEP PARAMETERS
snr_db_vec = -4.0 : 1.5 : 11.0;     % SNR (Eb/N0) range in dB
num_frames_per_snr = 5;             % Independent frames per SNR point
payload_bits_per_frame = 4000;      % Bits per frame

% System Configuration
tx_cfg.num_payload_bits = payload_bits_per_frame;
tx_cfg.sps              = 8;
tx_cfg.beta             = 0.35;
tx_cfg.span             = 8;
tx_cfg.mod_scheme       = 'BPSK';

% RF Impairments Configuration (Simulating Real Hardware)
chan_cfg.fs                    = 100000.0;
chan_cfg.timing_offset_samples = 2.75;
chan_cfg.cfo_hz                = 150.0;
chan_cfg.phase_offset_deg      = 30.0;
chan_cfg.dc_offset_bias        = 0.12;
chan_cfg.gain_imbalance_pct    = 6.0;
chan_cfg.phase_imbalance_deg   = 5.0;

% Receiver Switches
rx_cfg.enable_dc_corr = true;
rx_cfg.enable_gso     = true;
rx_cfg.enable_gardner = true;
rx_cfg.enable_costas  = true;

%% 2. RUN MONTE CARLO SIMULATION
num_snr_points = length(snr_db_vec);
empirical_ber = zeros(num_snr_points, 1);
total_errors = zeros(num_snr_points, 1);
total_bits   = zeros(num_snr_points, 1);

fprintf('Running Monte Carlo simulation across %d SNR points...\n', num_snr_points);
fprintf('------------------------------------------------------------------------\n');
fprintf(' SNR (dB) | Total Bits | Bit Errors | Empirical BER | Theoretical BER   \n');
fprintf('------------------------------------------------------------------------\n');

for i = 1 : num_snr_points
    current_snr = snr_db_vec(i);
    chan_cfg.snr_db = current_snr;
    
    accum_errors = 0;
    accum_bits   = 0;
    
    for f = 1 : num_frames_per_snr
        tx_cfg.seed = 1000 * i + f;
        
        % Transmit
        tx_data = sdr_tx(tx_cfg);
        % Channel
        chan_data = sdr_channel(tx_data, chan_cfg);
        % Receive & Synchronize
        rx_data = sdr_rx(chan_data, tx_data, rx_cfg);
        
        accum_errors = accum_errors + rx_data.bit_errors;
        accum_bits   = accum_bits + length(rx_data.ref_bits);
    end
    
    total_errors(i) = accum_errors;
    total_bits(i)   = accum_bits;
    empirical_ber(i) = accum_errors / max(1, accum_bits);
    
    % Analytical theoretical BPSK BER
    eb_n0_lin = 10.0 ^ (current_snr / 10.0);
    ber_theor = 0.5 * erfc(sqrt(eb_n0_lin));
    
    fprintf('  %+5.1f   |  %8d  |  %8d  |  %1.4e   |  %1.4e\n', ...
        current_snr, accum_bits, accum_errors, empirical_ber(i), ber_theor);
end
fprintf('------------------------------------------------------------------------\n\n');

%% 3. PLOT BER WATERFALL CURVE
snr_dense_db = linspace(-5, 13, 300);
eb_n0_dense_lin = 10.0 .^ (snr_dense_db / 10.0);
ber_dense_theory = 0.5 * erfc(sqrt(eb_n0_dense_lin));

h_fig = figure('Name', 'SDR BER Waterfall Curve', 'Position', [150, 150, 850, 560], 'Color', 'w');

% Theoretical AWGN Curve
semilogy(snr_dense_db, ber_dense_theory, 'b-', 'LineWidth', 2);
hold on;

% Empirical Monte Carlo Data
semilogy(snr_db_vec, max(empirical_ber, 1e-7), 'ro--', 'LineWidth', 1.8, 'MarkerSize', 8, 'MarkerFaceColor', [0.85 0.33 0.1]);

grid on;
set(gca, 'YScale', 'log');
ylim([1e-6, 1.0]);
xlim([-5, 12]);
xlabel('Channel SNR: E_b / N_0 (dB)', 'FontSize', 11);
ylabel('Bit Error Rate (BER)', 'FontSize', 11);
title({'SDR Transceiver: Empirical vs. Theoretical BER Performance', ...
    'Full Closed-Loop Synchronization under RF Impairments (CFO, Delay, DC, IQ Imbalance)'}, 'FontSize', 11);
legend({'Theoretical BPSK: P_b = Q(\surd(2 E_b/N_0))', 'Empirical SDR Transceiver (Monte Carlo)'}, ...
    'Location', 'southwest', 'FontSize', 10);

fprintf('BER Waterfall plot generated.\n');
