%% TEST_ASYNC_OTA_LINK
% =========================================================================
% Verification of Autonomous Asynchronous Over-The-Air Packet Acquisition
% MathWorks Challenge Project: Build a Wireless Communications Link (Project 162)
% =========================================================================
%
% This script simulates a real-world SDR antenna capture where the receiver
% receives an unknown duration of random channel noise before the transmission starts.
% The receiver autonomously triggers, synchronizes, and decodes the message.
%
% Author: DSP & Communications Systems Engineer

clear; close all; clc;

fprintf('========================================================================\n');
fprintf('   AUTONOMOUS ASYNCHRONOUS PACKET ACQUISITION VERIFICATION              \n');
fprintf('   Simulating Real-World Hardware Buffer with Unknown Arrival Delay     \n');
fprintf('========================================================================\n\n');

%% 1. TRANSMITTER CONFIGURATION
tx_cfg.source_type   = 'text';
tx_cfg.source_text   = 'Asynchronous Over-The-Air Packet Trigger Verified!';
tx_cfg.sps           = 8;
tx_cfg.beta          = 0.35;
tx_cfg.span          = 8;
tx_cfg.mod_scheme    = 'QPSK';
tx_cfg.enable_crc    = true;
tx_cfg.enable_fec    = true;
tx_cfg.seed          = 2026;

tx_data = sdr_tx(tx_cfg);

%% 2. SIMULATE HARDWARE BUFFER WITH RANDOM UNKNOWN DELAY
leading_noise_samples  = 1240; % Unknown delay before packet transmission
trailing_noise_samples = 850;  % Noise after packet ends
noise_sigma = 0.08;

rx_hardware_buffer = [
    noise_sigma * (randn(leading_noise_samples, 1) + 1j * randn(leading_noise_samples, 1));
    tx_data.tx_signal;
    noise_sigma * (randn(trailing_noise_samples, 1) + 1j * randn(trailing_noise_samples, 1))
];

% Apply Carrier Frequency Offset and Phase Rotation across entire buffer
fs = 100000.0;
cfo_hz = 120.0;
t_vec = (0 : length(rx_hardware_buffer) - 1)' / fs;
rx_impaired_buffer = rx_hardware_buffer .* exp(1j * (2 * pi * cfo_hz * t_vec + pi/6));

% Package as hardware capture without pre-known delay!
chan_data = struct();
chan_data.rx_impaired_signal = rx_impaired_buffer;
chan_data.fir_delay_total    = []; % NO SIMULATION DELAY PROVIDED!
chan_data.chan_cfg.fs        = fs;

%% 3. RECEIVER EXECUTION (AUTONOMOUS PACKET TRIGGER)
rx_cfg.enable_async_detect = true;
rx_cfg.enable_dc_corr      = true;
rx_cfg.enable_gso          = true;
rx_cfg.enable_gardner      = true;
rx_cfg.enable_costas       = true;

rx_data = sdr_rx(chan_data, tx_data, rx_cfg);

%% 4. REPORT DIAGNOSTICS
fprintf('------------------------------------------------------------------------\n');
fprintf('                   ASYNCHRONOUS LINK DIAGNOSTIC REPORT                  \n');
fprintf('------------------------------------------------------------------------\n');
fprintf('  Injected Random Delay     : %d samples (~%.2f ms)\n', leading_noise_samples, leading_noise_samples / fs * 1e3);
fprintf('  Pre-known Delay Given     : NONE (Autonomous hardware trigger mode)\n');
fprintf('  Barker Sync Peak Index    : Symbol %d\n', rx_data.peak_idx);
fprintf('  CRC-32 Checksum Status    : ');
if rx_data.crc_pass
    fprintf('[PASS] Clean Frame Verified!\n');
else
    fprintf('[FAIL] Parity Mismatch\n');
end
fprintf('  Payload Bit Errors        : %d / %d bits (BER: %.4e)\n', rx_data.bit_errors, length(rx_data.ref_bits), rx_data.ber);
fprintf('  Transmitted Message       : "%s"\n', tx_data.source_text);
fprintf('  Recovered Message         : "%s"\n', rx_data.rx_text);
if strcmp(tx_data.source_text, rx_data.rx_text)
    fprintf('  Trigger Verification      : [SUCCESS] 100%% ERROR-FREE ASYNCHRONOUS PACKET RECOVERY!\n');
else
    fprintf('  Trigger Verification      : [FAIL] Packet corrupted\n');
end
fprintf('------------------------------------------------------------------------\n\n');
