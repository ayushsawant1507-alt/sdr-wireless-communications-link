function tx_data = sdr_tx(cfg)
% SDR_TX - Software-Defined Radio Baseband Transmitter Engine
%
% Syntax:
%   tx_data = sdr_tx(cfg)
%
% Inputs:
%   cfg - Configuration structure containing:
%       .num_payload_bits   - Number of random payload data bits (e.g., 3000)
%       .sps                - Samples per symbol (e.g., 8)
%       .beta               - RRC roll-off factor (e.g., 0.35)
%       .span               - RRC filter span in symbols (e.g., 8)
%       .mod_scheme         - 'BPSK' or 'QPSK' (default: 'BPSK')
%       .seed               - Random seed (optional)
%
% Outputs:
%   tx_data - Structure containing:
%       .tx_signal          - Continuous-like pulse-shaped baseband I/Q signal
%       .payload_bits       - Original generated payload bits
%       .tx_symbols         - Complex symbol vector (Training + Barker + Payload)
%       .barker_seq         - 11-bit Barker sequence symbols
%       .n_acq              - Length of training preamble in symbols
%       .h_rrc              - Root-Raised-Cosine filter coefficients
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link (Project 162)

    if nargin < 1 || isempty(cfg)
        cfg = struct();
    end
    
    % Default parameters
    if ~isfield(cfg, 'num_payload_bits'), cfg.num_payload_bits = 3000; end
    if ~isfield(cfg, 'sps'),              cfg.sps = 8; end
    if ~isfield(cfg, 'beta'),             cfg.beta = 0.35; end
    if ~isfield(cfg, 'span'),             cfg.span = 8; end
    if ~isfield(cfg, 'mod_scheme'),        cfg.mod_scheme = 'BPSK'; end
    if ~isfield(cfg, 'enable_crc'),       cfg.enable_crc = false; end
    if ~isfield(cfg, 'enable_fec'),       cfg.enable_fec = false; end
    if ~isfield(cfg, 'source_type'),      cfg.source_type = 'random'; end
    if isfield(cfg, 'seed') && ~isempty(cfg.seed)
        rng(cfg.seed);
    end

    % 1. Standard 11-bit Barker Preamble Sequence
    % Autocorrelation has peak of 11 at lag 0, and <= 1 elsewhere
    barker_bits = [1 1 1 0 0 0 1 0 0 1 0]; % Binary representation
    n_acq = 120;
    
    if strcmpi(cfg.mod_scheme, 'QPSK')
        % Align preamble and sync word with QPSK diagonal constellation grid
        diag_scale = (1 + 1j) / sqrt(2);
        barker_seq = diag_scale * [1 1 1 -1 -1 -1 1 -1 -1 1 -1];
        acq_seq    = repmat(diag_scale * [1; -1], n_acq / 2, 1);
    else
        barker_seq = [1 1 1 -1 -1 -1 1 -1 -1 1 -1];
        acq_seq    = repmat([1; -1], n_acq / 2, 1);
    end

    % 3. Source Payload Bits (Random, Text String, or Image Bitmap)
    switch lower(cfg.source_type)
        case 'text'
            if ~isfield(cfg, 'source_text') || isempty(cfg.source_text)
                cfg.source_text = 'MathWorks SDR Challenge 162: Wireless Communications Link with Pluto/USRP!';
            end
            payload_bits = sdr_source_data('text_to_bits', cfg.source_text);
            cfg.img_dims = [];
            
        case 'image'
            if ~isfield(cfg, 'source_image') || isempty(cfg.source_image)
                cfg.source_image = sdr_source_data('get_default_image');
            end
            [payload_bits, img_dims] = sdr_source_data('image_to_bits', cfg.source_image);
            cfg.img_dims = img_dims;
            
        otherwise % 'random'
            if isfield(cfg, 'payload_bits') && ~isempty(cfg.payload_bits)
                payload_bits = cfg.payload_bits(:);
            else
                payload_bits = randi([0 1], cfg.num_payload_bits, 1);
            end
            cfg.img_dims = [];
    end

    % 3a. CRC-32 Error Detection Checksum (Optional)
    if cfg.enable_crc
        bits_with_crc = sdr_crc('encode', payload_bits);
    else
        bits_with_crc = payload_bits;
    end

    % 3b. Forward Error Correction (Rate 1/2, K=7 Convolutional Coding)
    if cfg.enable_fec
        channel_bits = sdr_fec('encode', bits_with_crc);
    else
        channel_bits = bits_with_crc;
    end

    % 4. Constellation Mapping
    switch upper(cfg.mod_scheme)
        case 'BPSK'
            % Mapping: 0 -> -1, 1 -> +1
            payload_symbols = 2 * channel_bits - 1;
            
        case 'QPSK'
            % Gray mapping for QPSK: 2 bits per symbol
            if mod(length(channel_bits), 2) ~= 0
                channel_bits = [channel_bits; 0];
            end
            b_I = channel_bits(1:2:end);
            b_Q = channel_bits(2:2:end);
            sym_I = (2 * b_I - 1) / sqrt(2);
            sym_Q = (2 * b_Q - 1) / sqrt(2);
            payload_symbols = sym_I + 1j * sym_Q;
            
        otherwise
            error('Unsupported modulation scheme: %s. Use ''BPSK'' or ''QPSK''.', cfg.mod_scheme);
    end

    % 5. Assemble Complete Transmit Frame
    % [Training Acquisition Preamble] + [11-bit Barker Sync Word] + [Payload Symbols]
    tx_symbols = [acq_seq; barker_seq(:); payload_symbols(:)];
    total_symbols = length(tx_symbols);

    % 6. Upsample by SPS (Insert SPS-1 zeros between symbols + flush tail zeros)
    pad_tail_syms = cfg.span * 2;
    upsampled_signal = zeros((total_symbols + pad_tail_syms) * cfg.sps, 1);
    upsampled_signal(1 : cfg.sps : total_symbols * cfg.sps) = tx_symbols;

    % 7. Design Root-Raised-Cosine (RRC) Transmit Pulse-Shaping Filter
    if exist('rcosdesign', 'file') == 2 || exist('rcosdesign', 'builtin') == 5
        try
            h_rrc = rcosdesign(cfg.beta, cfg.span, cfg.sps, 'sqrt');
        catch
            h_rrc = local_rrc_design(cfg.beta, cfg.span, cfg.sps);
        end
    else
        h_rrc = local_rrc_design(cfg.beta, cfg.span, cfg.sps);
    end
    % Normalize to unit energy: sum(h_rrc.^2) == 1
    h_rrc = h_rrc / sqrt(sum(h_rrc .^ 2));

    % 8. Transmit Pulse Shaping (FIR Filtering)
    tx_signal = filter(h_rrc, 1, upsampled_signal);

    % Return structured output
    tx_data = struct();
    tx_data.tx_signal         = tx_signal;
    tx_data.payload_bits      = payload_bits;
    tx_data.bits_with_crc     = bits_with_crc;
    tx_data.channel_bits      = channel_bits;
    tx_data.tx_symbols        = tx_symbols;
    tx_data.barker_seq        = barker_seq;
    tx_data.n_acq             = n_acq;
    tx_data.h_rrc             = h_rrc;
    tx_data.num_channel_syms  = length(payload_symbols);
    tx_data.source_type       = cfg.source_type;
    if isfield(cfg, 'source_text'),  tx_data.source_text = cfg.source_text; else, tx_data.source_text = ''; end
    if isfield(cfg, 'source_image'), tx_data.source_image = cfg.source_image; else, tx_data.source_image = []; end
    tx_data.img_dims          = cfg.img_dims;
    tx_data.cfg               = cfg;
end

% =========================================================
% Helper: Analytical Root-Raised-Cosine (RRC) FIR Filter
% =========================================================
function h = local_rrc_design(beta, span, sps)
    N = span * sps;
    t = (-N/2 : N/2)' / sps;
    h = zeros(size(t));
    for i = 1 : length(t)
        ti = t(i);
        if abs(ti) < 1e-8
            h(i) = 1.0 - beta + 4 * beta / pi;
        elseif beta > 0 && abs(abs(4 * beta * ti) - 1.0) < 1e-5
            c1 = (1 + 2 / pi) * sin(pi / (4 * beta));
            c2 = (1 - 2 / pi) * cos(pi / (4 * beta));
            h(i) = (beta / sqrt(2)) * (c1 + c2);
        else
            num = sin(pi * ti * (1 - beta)) + 4 * beta * ti * cos(pi * ti * (1 + beta));
            den = pi * ti * (1 - (4 * beta * ti)^2);
            h(i) = num / den;
        end
    end
    h = h / sqrt(sum(h .^ 2));
end
