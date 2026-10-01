function chan_data = sdr_channel(tx_data, chan_cfg)
% SDR_CHANNEL - RF Hardware Impairment Injector & Channel Emulator
%
% Syntax:
%   chan_data = sdr_channel(tx_data, chan_cfg)
%
% Inputs:
%   tx_data  - Output structure from sdr_tx()
%   chan_cfg - Channel parameters structure containing:
%       .timing_offset_samples - Fractional timing delay in samples (e.g., 3.25)
%       .cfo_hz                - Carrier Frequency Offset in Hz (e.g., 250)
%       .phase_offset_deg      - Initial Carrier Phase Offset in deg (e.g., 45)
%       .dc_offset_bias        - Complex DC bias magnitude (e.g., 0.15)
%       .gain_imbalance_pct    - I/Q Gain Imbalance in percent (e.g., 8.0)
%       .phase_imbalance_deg   - I/Q Phase Imbalance in deg (e.g., 6.0)
%       .snr_db                - Channel SNR (Eb/N0) in dB (e.g., 15.0)
%       .fs                    - Sampling frequency in Hz (e.g., 100000)
%
% Outputs:
%   chan_data - Structure containing:
%       .rx_impaired_signal    - Corrupted continuous-time-like received signal
%       .raw_decimated_symbols - Raw decimated symbols prior to software calibration
%       .dc_true               - Injected complex DC offset
%       .cfo_hz                - Injected CFO in Hz
%       .fir_delay_total       - Total cascade filter delay in samples
%       .chan_cfg              - Copy of applied channel configuration
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link (Project 162)

    if nargin < 2 || isempty(chan_cfg)
        chan_cfg = struct();
    end

    % Default channel and impairment parameters
    if ~isfield(chan_cfg, 'timing_offset_samples'), chan_cfg.timing_offset_samples = 3.25; end
    if ~isfield(chan_cfg, 'cfo_hz'),                chan_cfg.cfo_hz = 250.0; end
    if ~isfield(chan_cfg, 'phase_offset_deg'),      chan_cfg.phase_offset_deg = 45.0; end
    if ~isfield(chan_cfg, 'dc_offset_bias'),        chan_cfg.dc_offset_bias = 0.15; end
    if ~isfield(chan_cfg, 'gain_imbalance_pct'),    chan_cfg.gain_imbalance_pct = 8.0; end
    if ~isfield(chan_cfg, 'phase_imbalance_deg'),   chan_cfg.phase_imbalance_deg = 6.0; end
    if ~isfield(chan_cfg, 'snr_db'),                chan_cfg.snr_db = 15.0; end
    if ~isfield(chan_cfg, 'fs'),                    chan_cfg.fs = 100000.0; end

    tx_signal = tx_data.tx_signal;
    sps = tx_data.cfg.sps;
    span = tx_data.cfg.span;

    % =========================================================
    % 1. Continuous Fractional Timing Offset (Sinc Interpolation)
    % =========================================================
    n_sinc = 41;
    t_sinc = (-(n_sinc - 1) / 2 : (n_sinc - 1) / 2)' - chan_cfg.timing_offset_samples;
    sinc_filter = local_sinc(t_sinc);
    sinc_filter = sinc_filter / sum(sinc_filter);
    
    delayed_signal = filter(sinc_filter, 1, tx_signal);
    
    % Sinc filter group delay
    sinc_delay = (n_sinc - 1) / 2;

    % =========================================================
    % 2. Carrier Frequency Offset (CFO) and Phase Rotation
    % =========================================================
    t_vec = (0 : length(delayed_signal) - 1)' / chan_cfg.fs;
    phase_rad = chan_cfg.phase_offset_deg * (pi / 180);
    cfo_phasor = exp(1j * (2 * pi * chan_cfg.cfo_hz * t_vec + phase_rad));
    
    cfo_signal = delayed_signal .* cfo_phasor;

    % =========================================================
    % 3. Analog I/Q Imbalance (Gain & Phase Mismatch in Mixer)
    % =========================================================
    gain_imb = chan_cfg.gain_imbalance_pct / 100.0;
    phase_imb = chan_cfg.phase_imbalance_deg * (pi / 180);
    
    I_c = real(cfo_signal);
    Q_c = imag(cfo_signal);
    
    I_imb = (1.0 + gain_imb / 2.0) * I_c;
    Q_imb = (1.0 - gain_imb / 2.0) * (Q_c * cos(phase_imb) - I_c * sin(phase_imb));
    
    imb_signal = I_imb + 1j * Q_imb;

    % =========================================================
    % 4. Direct-Conversion DC Offset (LO Leakage / Mixer Self-Mixing)
    % =========================================================
    dc_i = chan_cfg.dc_offset_bias * cos(pi / 4.0);
    dc_q = chan_cfg.dc_offset_bias * sin(pi / 4.0);
    dc_true = dc_i + 1j * dc_q;
    
    dc_signal = imb_signal + dc_true;

    % =========================================================
    % 5. Additive White Gaussian Noise (AWGN Channel)
    % =========================================================
    % Unit energy symbol Eb = 1
    eb_n0_linear = 10.0 ^ (chan_cfg.snr_db / 10.0);
    sigma_noise = sqrt(1.0 / (2.0 * eb_n0_linear));
    
    noise_i = sigma_noise * randn(size(dc_signal));
    noise_q = sigma_noise * randn(size(dc_signal));
    
    rx_impaired_signal = dc_signal + (noise_i + 1j * noise_q);

    % Total FIR cascade delay
    fir_delay_total = span * sps + sinc_delay;

    % Raw decimated symbols for impaired constellation visualization
    total_syms = length(tx_data.tx_symbols);
    raw_decimated_indices = round(fir_delay_total + 1 : sps : min(length(rx_impaired_signal), fir_delay_total + total_syms * sps));
    raw_decimated_symbols = rx_impaired_signal(raw_decimated_indices);

    % Return channel output structure
    chan_data = struct();
    chan_data.rx_impaired_signal    = rx_impaired_signal;
    chan_data.raw_decimated_symbols = raw_decimated_symbols;
    chan_data.dc_true               = dc_true;
    chan_data.cfo_hz                = chan_cfg.cfo_hz;
    chan_data.fir_delay_total       = fir_delay_total;
    chan_data.chan_cfg              = chan_cfg;
end

% =========================================================
% Helper: Analytical Sinc Function
% =========================================================
function y = local_sinc(x)
    y = ones(size(x));
    idx = (x ~= 0);
    y(idx) = sin(pi * x(idx)) ./ (pi * x(idx));
end
