function rx_data = sdr_rx(chan_data, tx_data, rx_cfg)
% SDR_RX - Software-Defined Radio Digital Baseband Receiver & Calibrator
%
% Syntax:
%   rx_data = sdr_rx(chan_data, tx_data, rx_cfg)
%
% Inputs:
%   chan_data - Output structure from sdr_channel()
%   tx_data   - Output structure from sdr_tx()
%   rx_cfg    - Receiver configuration switches & parameters:
%       .enable_dc_corr  - Enable DC estimation & subtraction (true/false)
%       .enable_gso      - Enable Gram-Schmidt I/Q Orthogonalization (true/false)
%       .enable_gardner  - Enable Gardner Timing Recovery Loop (true/false)
%       .enable_costas   - Enable Costas Carrier Phase/Frequency PLL (true/false)
%
% Outputs:
%   rx_data - Structure containing:
%       .recovered_symbols  - Symbol vector after timing & carrier recovery
%       .resolved_symbols   - Symbols after 180° phase ambiguity resolution
%       .rx_payload_bits    - Demodulated received data bits
%       .bit_errors         - Number of bit errors in payload
%       .ber                - Bit Error Rate (BER)
%       .dc_est             - Estimated complex DC bias
%       .freq_estimates_hz  - Estimated CFO trajectory in Hz over symbols
%       .phase_errors       - Costas loop phase error trajectory
%       .gardner_errors     - Gardner TED timing error trajectory
%       .barker_corr        - Cross-correlation output with Barker sequence
%       .peak_idx           - Detected sync word symbol index
%       .peak_val           - Barker correlation peak magnitude
%       .ambig_sign         - Ambiguity inversion sign (+1 or -1)
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link (Project 162)

    if nargin < 3 || isempty(rx_cfg)
        rx_cfg = struct();
    end

    % Default toggle switches (all calibrations enabled)
    if ~isfield(rx_cfg, 'enable_dc_corr'), rx_cfg.enable_dc_corr = true; end
    if ~isfield(rx_cfg, 'enable_gso'),     rx_cfg.enable_gso = true; end
    if ~isfield(rx_cfg, 'enable_gardner'), rx_cfg.enable_gardner = true; end
    if ~isfield(rx_cfg, 'enable_costas'),  rx_cfg.enable_costas = true; end

    rx_raw = chan_data.rx_impaired_signal;
    h_rrc  = tx_data.h_rrc;
    sps    = tx_data.cfg.sps;
    fs     = chan_data.chan_cfg.fs;
    sym_rate = fs / sps;
    barker_seq = tx_data.barker_seq;
    n_acq = tx_data.n_acq;

    % =========================================================
    % STAGE 1: DC Offset Estimation & Removal
    % =========================================================
    if rx_cfg.enable_dc_corr
        dc_est = mean(rx_raw);
        rx_stage1 = rx_raw - dc_est;
    else
        dc_est = 0.0 + 0.0j;
        rx_stage1 = rx_raw;
    end

    % =========================================================
    % STAGE 2: Gram-Schmidt Orthogonalization (GSO) I/Q Calibration
    % =========================================================
    if rx_cfg.enable_gso
        I_in = real(rx_stage1);
        Q_in = imag(rx_stage1);
        
        p_I = mean(I_in .^ 2);
        cross_corr = mean(I_in .* Q_in);
        sin_phi_est = cross_corr / (p_I + 1e-12);
        
        % Orthogonalize Q with respect to I
        Q_orth = Q_in - sin_phi_est * I_in;
        gain_est = sqrt(mean(Q_orth .^ 2) / (p_I + 1e-12));
        
        % Normalize power
        I_gso = I_in / sqrt(p_I + 1e-12);
        Q_gso = Q_orth / (sqrt(p_I + 1e-12) * (gain_est + 1e-12));
        rx_stage2 = I_gso + 1j * Q_gso;
    else
        rx_stage2 = rx_stage1;
    end

    % =========================================================
    % STAGE 3: Root-Raised-Cosine (RRC) Matched Filtering
    % =========================================================
    rx_mf = filter(h_rrc, 1, rx_stage2);

    % =========================================================
    % STAGE 4: Asynchronous Packet Trigger & Gardner Timing Recovery
    % =========================================================
    if isfield(rx_cfg, 'enable_async_detect') && rx_cfg.enable_async_detect
        % Autonomous Over-The-Air Trigger Detection
        [packet_start_idx, packet_detected, peak_detect_metric] = sdr_packet_detect(rx_stage2, tx_data);
    elseif isfield(chan_data, 'fir_delay_total') && ~isempty(chan_data.fir_delay_total)
        packet_start_idx = chan_data.fir_delay_total + 1;
        packet_detected = true;
        peak_detect_metric = 1.0;
    else
        [packet_start_idx, packet_detected, peak_detect_metric] = sdr_packet_detect(rx_stage2, tx_data);
    end
    
    if rx_cfg.enable_gardner
        % Loop filter parameters
        Kp_t = 0.03;
        Ki_t = 0.0003;
        
        idx = packet_start_idx;
        prev_strobe = local_hermite_interp(rx_mf, idx);
        idx = idx + sps / 2.0;
        prev_half = local_hermite_interp(rx_mf, idx);
        idx = idx + sps / 2.0;
        
        recovered_syms = prev_strobe;
        gardner_errors = [];
        loop_int_t = 0.0;
        
        while idx < length(rx_mf) - sps
            curr_strobe = local_hermite_interp(rx_mf, idx);
            recovered_syms(end+1, 1) = curr_strobe; %#ok<AGROW>
            
            % Gardner TED: e_t = Re{(curr_strobe - prev_strobe) * conj(prev_half)}
            diff_strobe = curr_strobe - prev_strobe;
            e_t = real(diff_strobe) * real(prev_half) + imag(diff_strobe) * imag(prev_half);
            gardner_errors(end+1, 1) = e_t; %#ok<AGROW>
            
            % Proportional-Integral (PI) loop filter
            loop_int_t = loop_int_t + Ki_t * e_t;
            loop_int_t = max(min(loop_int_t, 0.5), -0.5);
            tau_adj = Kp_t * e_t + loop_int_t;
            
            % Strobe advance
            prev_strobe = curr_strobe;
            idx_half = idx + (sps / 2.0) - (tau_adj / 2.0);
            prev_half = local_hermite_interp(rx_mf, idx_half);
            
            idx = idx + sps - tau_adj;
        end
    else
        % Static decimation without dynamic timing recovery
        total_syms = length(tx_data.tx_symbols);
        strobe_indices = round(fir_delay_total + 1 : sps : min(length(rx_mf), fir_delay_total + total_syms * sps));
        recovered_syms = rx_mf(strobe_indices);
        gardner_errors = zeros(size(recovered_syms));
    end

    % =========================================================
    % STAGE 5: Coarse CFO Estimation & 2nd-Order Costas Loop PLL
    % =========================================================
    if rx_cfg.enable_costas
        % Coarse CFO Estimation via Squaring (BPSK) / 4th-power (QPSK) FFT
        Nfft = 2^nextpow2(max(2048, length(recovered_syms)));
        if isfield(tx_data.cfg, 'mod_scheme') && strcmpi(tx_data.cfg.mod_scheme, 'QPSK')
            power_order = 4;
            syms_powered = recovered_syms .^ 4;
        else
            power_order = 2;
            syms_powered = recovered_syms .^ 2;
        end
        fft_spectrum = fftshift(fft(syms_powered, Nfft));
        f_axis = (-Nfft/2 : Nfft/2 - 1)' * (sym_rate / Nfft);
        [~, max_idx] = max(abs(fft_spectrum));
        coarse_cfo_hz = f_axis(max_idx) / power_order;
        
        % Pre-derotate symbols by coarse frequency offset
        t_sym = (0 : length(recovered_syms) - 1)' / sym_rate;
        coarse_derotated = recovered_syms .* exp(-1j * 2 * pi * coarse_cfo_hz * t_sym);
        
        Kp_c = 0.06;
        Ki_c = 0.001;
        
        phase_est = 0.0;
        freq_est = 0.0;
        
        is_qpsk = isfield(tx_data.cfg, 'mod_scheme') && strcmpi(tx_data.cfg.mod_scheme, 'QPSK');
        num_syms = length(coarse_derotated);
        despun_syms = zeros(num_syms, 1);
        phase_errors = zeros(num_syms, 1);
        freq_estimates_hz = zeros(num_syms, 1);
        
        for k = 1 : num_syms
            sym = coarse_derotated(k);
            % De-rotate symbol by estimated residual carrier phase
            rot = sym * exp(-1j * phase_est);
            despun_syms(k) = rot;
            
            mag_sq = real(rot)^2 + imag(rot)^2 + 1e-6;
            if is_qpsk
                % 4-Phase Cross-Product QPSK PED: (sign(I)*Q - sign(Q)*I) / |rot|
                e_p = (sign(real(rot)) * imag(rot) - sign(imag(rot)) * real(rot)) / sqrt(mag_sq);
            else
                % Normalized BPSK Phase Error Detector (PED): sign(I) * Q / |rot|
                e_p = (sign(real(rot)) * imag(rot)) / sqrt(mag_sq);
            end
            phase_errors(k) = e_p;
            
            % 2nd-order loop filter updates
            freq_est = freq_est + Ki_c * e_p;
            phase_est = phase_est + freq_est + Kp_c * e_p;
            phase_est = mod(phase_est + pi, 2 * pi) - pi; % Wrap to [-pi, pi]
            
            % Total estimated carrier frequency in Hz (Coarse + Fine)
            freq_estimates_hz(k) = coarse_cfo_hz + (freq_est * sym_rate) / (2 * pi);
        end
    else
        is_qpsk = isfield(tx_data.cfg, 'mod_scheme') && strcmpi(tx_data.cfg.mod_scheme, 'QPSK');
        despun_syms = recovered_syms;
        phase_errors = zeros(size(recovered_syms));
        freq_estimates_hz = zeros(size(recovered_syms));
    end

    % =========================================================
    % STAGE 6: Barker Preamble Frame Sync & 4-Quadrant Ambiguity Resolution
    % =========================================================
    search_start = max(1, n_acq - 20);
    search_end   = min(length(despun_syms), n_acq + 40);
    search_window = despun_syms(search_start : search_end);
    
    if length(search_window) >= length(barker_seq)
        barker_ref = barker_seq(:);
        barker_corr_cplx = conv(search_window, conj(flipud(barker_ref)), 'valid');
        [peak_val, peak_offset] = max(abs(barker_corr_cplx));
        peak_idx = search_start + peak_offset - 1;
        raw_peak = barker_corr_cplx(peak_offset);
        barker_corr = abs(barker_corr_cplx);
        
        if is_qpsk
            cand_rot = [1, 1j, -1, -1j]; % 0°, 90°, 180°, 270° phase ambiguity
        else
            cand_rot = [1, -1];          % 0°, 180° phase ambiguity
        end
        [~, best_rot_idx] = max(real(raw_peak * conj(cand_rot)));
        ambig_factor = cand_rot(best_rot_idx);
    else
        barker_corr = 0;
        peak_idx = n_acq + 1;
        peak_val = 0;
        ambig_factor = 1;
    end

    % Resolve phase ambiguity
    resolved_symbols = despun_syms * conj(ambig_factor);
    ambig_sign = ambig_factor;

    % =========================================================
    % STAGE 7: Payload Demapping, Viterbi Decoding & CRC Check
    % =========================================================
    payload_start = peak_idx + length(barker_seq);
    
    % Determine if FEC and CRC were used by transmitter
    fec_enabled = false;
    crc_enabled = false;
    if isfield(tx_data.cfg, 'enable_fec') && tx_data.cfg.enable_fec
        fec_enabled = true;
    end
    if isfield(tx_data.cfg, 'enable_crc') && tx_data.cfg.enable_crc
        crc_enabled = true;
    end
    
    if isfield(tx_data, 'num_channel_syms')
        num_channel_syms = tx_data.num_channel_syms;
    elseif isfield(tx_data, 'channel_bits')
        if is_qpsk
            num_channel_syms = ceil(length(tx_data.channel_bits) / 2);
        else
            num_channel_syms = length(tx_data.channel_bits);
        end
    else
        num_channel_syms = length(tx_data.payload_bits);
    end
    
    if payload_start + num_channel_syms - 1 <= length(resolved_symbols)
        rx_channel_syms = resolved_symbols(payload_start : payload_start + num_channel_syms - 1);
    else
        rx_channel_syms = resolved_symbols(payload_start : end);
    end
    
    % Demap channel symbols (BPSK or QPSK Gray demapping)
    if is_qpsk
        b_I_rx = double(real(rx_channel_syms) > 0.0);
        b_Q_rx = double(imag(rx_channel_syms) > 0.0);
        raw_channel_bits = zeros(2 * length(rx_channel_syms), 1);
        raw_channel_bits(1:2:end) = b_I_rx;
        raw_channel_bits(2:2:end) = b_Q_rx;
    else
        raw_channel_bits = double(real(rx_channel_syms) > 0.0);
    end
    
    % Raw Channel BER before FEC
    ref_chan = tx_data.channel_bits(1 : min(length(raw_channel_bits), length(tx_data.channel_bits)));
    channel_bit_errors = sum(ref_chan ~= raw_channel_bits(1 : length(ref_chan)));
    channel_ber = channel_bit_errors / max(1, length(ref_chan));
    
    % Forward Error Correction (Viterbi Decoding)
    if fec_enabled
        num_info_with_crc = length(tx_data.payload_bits);
        if crc_enabled
            num_info_with_crc = num_info_with_crc + 32;
        end
        decoded_bits = sdr_fec('decode', raw_channel_bits, num_info_with_crc);
    else
        decoded_bits = raw_channel_bits;
    end
    
    % CRC-32 Checksum Validation
    if crc_enabled
        if length(decoded_bits) >= 32
            [rx_payload_bits, crc_pass, crc_parity_errs] = sdr_crc('decode', decoded_bits);
        else
            rx_payload_bits = decoded_bits;
            crc_pass = false;
            crc_parity_errs = 32;
        end
    else
        rx_payload_bits = decoded_bits(1 : min(length(decoded_bits), length(tx_data.payload_bits)));
        crc_pass = true;
        crc_parity_errs = 0;
    end
    
    % Final Info Payload BER after FEC
    ref_bits = tx_data.payload_bits(1 : min(length(rx_payload_bits), length(tx_data.payload_bits)));
    bit_errors = sum(ref_bits ~= rx_payload_bits(1 : length(ref_bits)));
    ber = bit_errors / max(1, length(ref_bits));

    % Reconstruct Source Data (Text or Image)
    rx_text = '';
    rx_image = [];
    if isfield(tx_data, 'source_type')
        switch lower(tx_data.source_type)
            case 'text'
                rx_text = sdr_source_data('bits_to_text', rx_payload_bits);
            case 'image'
                if isfield(tx_data, 'img_dims') && ~isempty(tx_data.img_dims)
                    rx_image = sdr_source_data('bits_to_image', rx_payload_bits, tx_data.img_dims);
                end
        end
    end

    % Assemble structured output
    rx_data = struct();
    rx_data.recovered_symbols  = recovered_syms;
    rx_data.despun_syms        = despun_syms;
    rx_data.resolved_symbols   = resolved_symbols;
    rx_data.raw_channel_bits   = raw_channel_bits;
    rx_data.channel_bit_errors = channel_bit_errors;
    rx_data.channel_ber        = channel_ber;
    rx_data.fec_applied        = fec_enabled;
    rx_data.crc_applied        = crc_enabled;
    rx_data.crc_pass           = crc_pass;
    rx_data.crc_parity_errs    = crc_parity_errs;
    rx_data.rx_payload_bits    = rx_payload_bits;
    rx_data.rx_text            = rx_text;
    rx_data.rx_image           = rx_image;
    rx_data.ref_bits           = ref_bits;
    rx_data.bit_errors         = bit_errors;
    rx_data.ber                = ber;
    rx_data.dc_est             = dc_est;
    rx_data.freq_estimates_hz  = freq_estimates_hz;
    rx_data.phase_errors       = phase_errors;
    rx_data.gardner_errors     = gardner_errors;
    rx_data.barker_corr        = barker_corr;
    rx_data.search_start       = search_start;
    rx_data.peak_idx           = peak_idx;
    rx_data.peak_val           = peak_val;
    rx_data.ambig_sign         = ambig_sign;
end

% =========================================================
% Helper: Continuous Cubic Hermite Interpolator
% =========================================================
function val = local_hermite_interp(sig, pos)
    b = floor(pos);
    f = pos - b;
    if b < 2 || b + 2 > length(sig)
        val = 0.0 + 0.0j;
        return;
    end
    p0 = sig(b - 1);
    p1 = sig(b);
    p2 = sig(b + 1);
    p3 = sig(b + 2);
    
    a0 = -0.5*p0 + 1.5*p1 - 1.5*p2 + 0.5*p3;
    a1 = p0 - 2.5*p1 + 2.0*p2 - 0.5*p3;
    a2 = -0.5*p0 + 0.5*p2;
    a3 = p1;
    val = a0 * (f^3) + a1 * (f^2) + a2 * f + a3;
end
