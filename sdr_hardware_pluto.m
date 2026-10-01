%% SDR_HARDWARE_PLUTO
% =========================================================================
% Over-The-Air (OTA) Wireless Link with ADALM-PLUTO / RTL-SDR Hardware
% MathWorks Challenge Project: Build a Wireless Communications Link (Project 162)
% =========================================================================
%
% Requirements:
%   - Communications Toolbox
%   - Communications Toolbox Support Package for Analog Devices ADALM-PLUTO Radio
%     (or RTL-SDR Radio Support Package)
%
% Author: DSP & Communications Systems Engineer

clear; close all; clc;

fprintf('========================================================================\n');
fprintf('   ADALM-PLUTO OVER-THE-AIR (OTA) SDR TRANSCEIVER - MATLAB ENGINE       \n');
fprintf('========================================================================\n\n');

%% 1. RADIO HARDWARE CONFIGURATION
CenterFrequency = 915e6;     % 915 MHz ISM Band (Adjust per regional license)
BasebandSampleRate = 1e6;    % 1 MSPS
TxGain = -10;                % dBm (Keep low for benchtop loopback)
RxGain = 20;                 % dB

% Baseband DSP Configuration
tx_cfg.num_payload_bits = 4000;
tx_cfg.sps              = 8;
tx_cfg.beta             = 0.35;
tx_cfg.span             = 8;
tx_cfg.mod_scheme       = 'BPSK';

%% 2. GENERATE TRANSMIT BASEBAND FRAME
fprintf('[1/4] Synthesizing Baseband Pulse-Shaped Frame...\n');
tx_data = sdr_tx(tx_cfg);

% Repeat frame to ensure continuous buffer transmission
tx_burst = repmat(tx_data.tx_signal, 10, 1);
tx_burst = tx_burst / max(abs(tx_burst)); % Normalize to avoid DAC clipping

%% 3. INITIALIZE SDR HARDWARE INTERFACES
fprintf('[2/4] Initializing ADALM-PLUTO Transceiver Hardware...\n');

try
    % Check for Pluto radio hardware
    radio_tx = sdrtx('Pluto', ...
        'CenterFrequency',    CenterFrequency, ...
        'BasebandSampleRate', BasebandSampleRate, ...
        'Gain',               TxGain);
        
    radio_rx = sdrrx('Pluto', ...
        'CenterFrequency',    CenterFrequency, ...
        'BasebandSampleRate', BasebandSampleRate, ...
        'GainSource',         'Manual', ...
        'Gain',               RxGain, ...
        'SamplesPerFrame',    length(tx_data.tx_signal) * 3, ...
        'OutputDataType',     'double');
        
    fprintf('Hardware connected successfully.\n');
catch ME
    warning('Pluto SDR Hardware not detected. Running in Loopback Emulation Mode.');
    fprintf('Error details: %s\n\n', ME.message);
    
    % Fallback: Run software channel emulation
    chan_cfg.fs                    = BasebandSampleRate;
    chan_cfg.snr_db                = 18.0;
    chan_cfg.timing_offset_samples = 3.25;
    chan_cfg.cfo_hz                = 1200.0; % 1.2 kHz offset
    chan_cfg.phase_offset_deg      = 60.0;
    chan_cfg.dc_offset_bias        = 0.15;
    chan_cfg.gain_imbalance_pct    = 5.0;
    chan_cfg.phase_imbalance_deg   = 4.0;
    
    chan_data = sdr_channel(tx_data, chan_cfg);
    rx_signal = chan_data.rx_impaired_signal;
end

%% 4. TRANSMIT & RECEIVE LIVE RF SIGNALS (IF HARDWARE CONNECTED)
if exist('radio_tx', 'var') && exist('radio_rx', 'var')
    fprintf('[3/4] Transmitting and Capturing Over-The-Air RF Signal...\n');
    
    % Transmit in loop mode
    transmitRepeat(radio_tx, tx_burst);
    
    % Flush buffer and capture clean frame
    for k = 1:5
        rx_signal = radio_rx();
    end
    
    % Release radio
    release(radio_tx);
    release(radio_rx);
    
    % Wrap captured signal into chan_data structure
    chan_data = struct();
    chan_data.rx_impaired_signal    = rx_signal;
    chan_data.raw_decimated_symbols = rx_signal(1:tx_cfg.sps:end);
    chan_data.dc_true               = 0;
    chan_data.cfo_hz                = 0;
    chan_data.fir_delay_total       = tx_cfg.span * tx_cfg.sps;
    chan_data.chan_cfg.fs           = BasebandSampleRate;
end

%% 5. EXECUTE RECEIVER DSP CALIBRATION & SYNCHRONIZATION
fprintf('[4/4] Executing Baseband DSP Recovery (DC, GSO, Gardner, Costas, Sync)...\n');
rx_cfg.enable_dc_corr = true;
rx_cfg.enable_gso     = true;
rx_cfg.enable_gardner = true;
rx_cfg.enable_costas  = true;

rx_data = sdr_rx(chan_data, tx_data, rx_cfg);

%% 6. DISPLAY OVER-THE-AIR LINK RESULTS
fprintf('\n========================================================================\n');
fprintf('                     OVER-THE-AIR LINK RESULTS                          \n');
fprintf('========================================================================\n');
fprintf('  Carrier Frequency     : %.2f MHz\n', CenterFrequency / 1e6);
fprintf('  Sampling Rate         : %.2f MSPS\n', BasebandSampleRate / 1e6);
fprintf('  Recovered Payload BER : %.4e (%d bit errors / %d bits)\n', ...
    rx_data.ber, rx_data.bit_errors, length(rx_data.ref_bits));
fprintf('  Barker Frame Sync     : Peak = %.2f (Index: %d, Inversion: %+d)\n', ...
    rx_data.peak_val, rx_data.peak_idx, rx_data.ambig_sign);
if ~isempty(rx_data.freq_estimates_hz)
    fprintf('  Recovered CFO (PLL)   : %.2f Hz\n', rx_data.freq_estimates_hz(end));
end
fprintf('========================================================================\n\n');

% Plot Live Constellation
figure('Name', 'Live Over-The-Air Constellation', 'Position', [200, 200, 700, 500], 'Color', 'w');
cal_start = rx_data.peak_idx + 11;
cal_pts = rx_data.resolved_symbols(cal_start : min(cal_start + 1500, length(rx_data.resolved_symbols)));
plot(real(cal_pts), imag(cal_pts), 'b.', 'MarkerSize', 8);
hold on;
plot([-1 1], [0 0], 'r+', 'MarkerSize', 14, 'LineWidth', 2);
xline(0, 'r--', 'Decision Boundary');
grid on; axis equal;
xlim([-2.5 2.5]); ylim([-2.5 2.5]);
xlabel('In-Phase (I)'); ylabel('Quadrature (Q)');
title(sprintf('Live Over-The-Air Synchronized Constellation (BER: %.2e)', rx_data.ber));
legend('Received Symbols', 'Ideal BPSK Points');
