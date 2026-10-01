%% DEMO_IMAGE_TRANSCEIVER
% =========================================================================
% SDR Real-World Image Transmission & Over-The-Air Recovery Demo
% MathWorks Challenge Project: Build a Wireless Communications Link (Project 162)
% =========================================================================
%
% This script demonstrates digital wireless transmission of a 2D image bitmap
% over an impaired RF channel (CFO, Delay, DC Offset, IQ Imbalance, and Noise).
% It compares image reconstruction with and without Forward Error Correction (FEC).
%
% Author: DSP & Communications Systems Engineer

clear; close all; clc;

fprintf('========================================================================\n');
fprintf('   SDR REAL-WORLD IMAGE TRANSMISSION & RECOVERY DEMONSTRATOR            \n');
fprintf('   MathWorks Challenge Project 162: Wireless Communications Link        \n');
fprintf('========================================================================\n\n');

%% 1. CONFIGURE IMAGE TRANSMITTER
tx_cfg.source_type   = 'image';
tx_cfg.source_image  = sdr_source_data('get_default_image'); % 36x36 SDR Logo
tx_cfg.sps           = 8;
tx_cfg.beta          = 0.35;
tx_cfg.span          = 8;
tx_cfg.mod_scheme    = 'BPSK';
tx_cfg.enable_crc    = true;
tx_cfg.enable_fec    = true; % Rate 1/2 Viterbi protection
tx_cfg.seed          = 101;

% Impairments: Moderate SNR to illustrate visual error resilience
chan_cfg.fs                    = 100000.0;
chan_cfg.snr_db                = 11.0;     % Challenging SNR
chan_cfg.timing_offset_samples = 2.45;
chan_cfg.cfo_hz                = 180.0;
chan_cfg.phase_offset_deg      = 35.0;
chan_cfg.dc_offset_bias        = 0.12;
chan_cfg.gain_imbalance_pct    = 6.0;
chan_cfg.phase_imbalance_deg   = 5.0;

rx_cfg.enable_dc_corr = true;
rx_cfg.enable_gso     = true;
rx_cfg.enable_gardner = true;
rx_cfg.enable_costas  = true;

%% 2. TRANSMIT & RECEIVE WITH FEC (PROTECTED LINK)
fprintf('[1/2] Transmitting Image with Forward Error Correction (Rate 1/2 FEC)...\n');
tx_data = sdr_tx(tx_cfg);
chan_data = sdr_channel(tx_data, chan_cfg);
rx_data = sdr_rx(chan_data, tx_data, rx_cfg);

%% 3. TRANSMIT WITHOUT FEC (UNPROTECTED BASELINE AT SAME SNR)
fprintf('[2/2] Transmitting Image without FEC (Raw Channel Baseline)...\n');
tx_cfg_nofec = tx_cfg;
tx_cfg_nofec.enable_fec = false;
tx_data_nofec = sdr_tx(tx_cfg_nofec);
chan_data_nofec = sdr_channel(tx_data_nofec, chan_cfg);
rx_data_nofec = sdr_rx(chan_data_nofec, tx_data_nofec, rx_cfg);

%% 4. PERFORMANCE SUMMARY
img_orig  = tx_data.source_image;
img_fec   = rx_data.rx_image;
img_nofec = rx_data_nofec.rx_image;

fprintf('\n------------------------------------------------------------------------\n');
fprintf('                     IMAGE LINK PERFORMANCE SUMMARY                     \n');
fprintf('------------------------------------------------------------------------\n');
fprintf('  Image Dimensions          : %d x %d pixels (%d bits)\n', size(img_orig,1), size(img_orig,2), numel(img_orig));
fprintf('  Channel SNR (Eb/N0)       : %.1f dB\n', chan_cfg.snr_db);
fprintf('  Injected CFO              : %.1f Hz\n', chan_cfg.cfo_hz);
fprintf('  Estimated CFO             : %.1f Hz\n', rx_data.freq_estimates_hz(end));
fprintf('  Uncoded Channel Bit Errors: %d / %d (BER: %.4e)\n', rx_data_nofec.bit_errors, length(rx_data_nofec.ref_bits), rx_data_nofec.ber);
fprintf('  Viterbi Coded Bit Errors  : %d / %d (BER: %.4e)\n', rx_data.bit_errors, length(rx_data.ref_bits), rx_data.ber);
if rx_data.crc_pass
    fprintf('  CRC-32 Checksum (FEC)     : [PASS] Perfect Error-Free Image Frame!\n');
else
    fprintf('  CRC-32 Checksum (FEC)     : [FAIL] Parity errors detected\n');
end
fprintf('------------------------------------------------------------------------\n\n');

%% 5. VISUALIZATION: SIDE-BY-SIDE IMAGE COMPARISON
figure('Name', 'SDR Wireless Image Transmission Demonstration', 'Position', [100, 150, 1100, 480], 'Color', 'w');

% Subplot 1: Original Transmitted Image
subplot(1, 3, 1);
imshow(img_orig, 'InitialMagnification', 'fit');
title({'1. Transmitted Image', sprintf('Original Source (%dx%d)', size(img_orig,1), size(img_orig,2))}, 'FontSize', 11);

% Subplot 2: Uncoded Received Image (Noisy / Pixel Errors)
subplot(1, 3, 2);
imshow(img_nofec, 'InitialMagnification', 'fit');
title({'2. Received Uncoded Image', sprintf('SNR: %.1fdB | BER: %.2e (%d px errors)', chan_cfg.snr_db, rx_data_nofec.ber, rx_data_nofec.bit_errors)}, 'FontSize', 11);

% Subplot 3: Viterbi FEC Decoded Image (Clean / Error Corrected)
subplot(1, 3, 3);
imshow(img_fec, 'InitialMagnification', 'fit');
title({'3. Received Coded Image (FEC Active)', sprintf('Rate 1/2 Viterbi | BER: %.2e (%d errors)', rx_data.ber, rx_data.bit_errors)}, 'FontSize', 11);

colormap(gray);
fprintf('Side-by-side image comparison figure generated.\n');
