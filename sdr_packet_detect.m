function [packet_start_sample, packet_detected, peak_metric, metric_profile] = sdr_packet_detect(rx_signal, tx_data, detect_cfg)
% SDR_PACKET_DETECT - Robust Asynchronous Over-The-Air Packet Acquisition Trigger
%
% Syntax:
%   [start_sample, detected, metric, profile] = sdr_packet_detect(rx_signal, tx_data, detect_cfg)
%
% Algorithm:
%   1. Matched filtering of continuous received buffer y[n] = (r * h_RRC)[n]
%   2. Normalized cross-correlation against the known preamble waveform:
%        M[n] = |∑ y[n+k] * p*[k]|^2 / (∑ |y[n+k]|^2)
%   3. Dynamic thresholding: triggers when M[n] > Threshold (Default: 0.35)
%   4. Calculates the packet arrival sample index for autonomous timing recovery.
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link (Project 162)

    if nargin < 3 || isempty(detect_cfg)
        detect_cfg = struct();
    end
    if ~isfield(detect_cfg, 'threshold'), detect_cfg.threshold = 0.35; end

    h_rrc = tx_data.h_rrc;
    sps   = tx_data.cfg.sps;
    n_acq = tx_data.n_acq;
    
    % 1. RRC Matched Filter
    rx_mf = filter(h_rrc, 1, rx_signal);

    % 2. Synthesize Normalized Preamble Template
    % Use the first 40 symbols of the acquisition sequence
    acq_len_tmpl = min(40, n_acq);
    if isfield(tx_data.cfg, 'mod_scheme') && strcmpi(tx_data.cfg.mod_scheme, 'QPSK')
        diag_scale = (1 + 1j) / sqrt(2);
        tmpl_syms = repmat(diag_scale * [1; -1], acq_len_tmpl / 2, 1);
    else
        tmpl_syms = repmat([1; -1], acq_len_tmpl / 2, 1);
    end
    
    tmpl_up = zeros(acq_len_tmpl * sps, 1);
    tmpl_up(1 : sps : end) = tmpl_syms;
    tmpl_wf = filter(h_rrc, 1, tmpl_up);
    tmpl_wf = tmpl_wf / sqrt(sum(abs(tmpl_wf) .^ 2));
    L_tmpl = length(tmpl_wf);

    % 3. Sliding Normalized Cross-Correlation Metric
    if length(rx_mf) < L_tmpl
        packet_start_sample = 1;
        packet_detected = false;
        peak_metric = 0;
        metric_profile = 0;
        return;
    end

    corr_seq = conv(rx_mf, conj(flipud(tmpl_wf)), 'valid');
    pwr_seq  = conv(abs(rx_mf) .^ 2, ones(L_tmpl, 1), 'valid') + 1e-12;
    metric_profile = (abs(corr_seq) .^ 2) ./ pwr_seq;

    [peak_metric, peak_idx] = max(metric_profile);

    % 4. Decision & Packet Boundary Estimation
    if peak_metric >= detect_cfg.threshold
        packet_detected = true;
        % The template peaked when fully inside the preamble.
        % The start of the packet is approximately peak_idx - L_tmpl:
        packet_start_sample = max(1, round(peak_idx - L_tmpl / 2));
    else
        packet_detected = false;
        packet_start_sample = 1; % Fallback
    end
end
