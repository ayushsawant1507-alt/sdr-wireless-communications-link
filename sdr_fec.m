function [out_data, metrics] = sdr_fec(action, in_data, num_info_bits)
% SDR_FEC - Rate 1/2, Constraint Length 7 Convolutional Encoder & Viterbi Decoder
%
% Syntax:
%   coded_bits = sdr_fec('encode', info_bits)
%   [decoded_bits, metrics] = sdr_fec('decode', coded_bits, num_info_bits)
%
% Specifications:
%   - Code Rate: R = 1/2 (2 coded bits per input information bit)
%   - Constraint Length: K = 7 (64-state Trellis)
%   - Generator Polynomials: g1 = 171_8 (1111001), g2 = 133_8 (1011011)
%   - Trellis Termination: 6 zero flush bits
%   - Decoder: Optimal Maximum-Likelihood Viterbi Algorithm with Traceback
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link (Project 162)

    g1 = [1 1 1 1 0 0 1]';
    g2 = [1 0 1 1 0 1 1]';
    flush_len = 6; % K - 1

    switch lower(action)
        case 'encode'
            info_bits = in_data(:);
            % Append K-1 = 6 flush zeros to terminate trellis in state 0
            padded_bits = [info_bits; zeros(flush_len, 1)];
            L = length(padded_bits);
            
            coded_bits = zeros(2 * L, 1);
            reg = zeros(7, 1);
            
            for i = 1 : L
                reg = [padded_bits(i); reg(1:6)];
                c1 = mod(sum(reg .* g1), 2);
                c2 = mod(sum(reg .* g2), 2);
                coded_bits(2*i - 1) = c1;
                coded_bits(2*i)     = c2;
            end
            
            out_data = coded_bits;
            metrics = struct('code_rate', 0.5, 'constraint_length', 7, 'flush_bits', flush_len);

        case 'decode'
            coded = in_data(:);
            total_steps = floor(length(coded) / 2);
            coded = coded(1 : 2 * total_steps);
            if nargin < 3 || isempty(num_info_bits)
                num_info_bits = total_steps - flush_len;
            end
            num_states = 64;
            
            % 1. Precompute Trellis Structure (Single generation)
            persistent prev_states expected_outputs input_bits
            if isempty(prev_states)
                prev_states = zeros(num_states, 2);
                expected_outputs = zeros(num_states, 2, 2);
                input_bits = zeros(num_states, 1);
                
                for S = 0 : num_states - 1
                    % 6-bit state: S1..S6
                    S_bits = zeros(6, 1);
                    temp = S;
                    for b = 1 : 6
                        S_bits(7 - b) = mod(temp, 2);
                        temp = floor(temp / 2);
                    end
                    in_bit = S_bits(1);
                    input_bits(S + 1) = in_bit;
                    
                    for s_old = 0 : 1
                        prev_S_bits = [S_bits(2:6); s_old];
                        prev_S = 0;
                        for b = 1 : 6
                            prev_S = prev_S * 2 + prev_S_bits(b);
                        end
                        prev_states(S + 1, s_old + 1) = prev_S;
                        
                        reg = [S_bits; s_old];
                        c1 = mod(sum(reg .* g1), 2);
                        c2 = mod(sum(reg .* g2), 2);
                        expected_outputs(S + 1, s_old + 1, :) = [c1, c2];
                    end
                end
            end
            
            % 2. Forward Viterbi Trellis Traversal (Add-Compare-Select)
            path_metric = inf(num_states, 1);
            path_metric(1) = 0; % Initial state is 0 at t=0
            
            traceback = zeros(num_states, total_steps, 'uint8');
            
            for t = 1 : total_steps
                r = coded(2*t - 1 : 2*t);
                new_metric = inf(num_states, 1);
                
                for S_idx = 1 : num_states
                    % Predecessor 1
                    p1 = prev_states(S_idx, 1) + 1;
                    o1 = squeeze(expected_outputs(S_idx, 1, :));
                    bm1 = sum(r ~= o1);
                    m1 = path_metric(p1) + bm1;
                    
                    % Predecessor 2
                    p2 = prev_states(S_idx, 2) + 1;
                    o2 = squeeze(expected_outputs(S_idx, 2, :));
                    bm2 = sum(r ~= o2);
                    m2 = path_metric(p2) + bm2;
                    
                    if m1 <= m2
                        new_metric(S_idx) = m1;
                        traceback(S_idx, t) = 1;
                    else
                        new_metric(S_idx) = m2;
                        traceback(S_idx, t) = 2;
                    end
                end
                path_metric = new_metric;
            end
            
            % 3. Traceback from State 0 (Due to zero flush bits)
            curr_state_idx = 1;
            recovered = zeros(total_steps, 1);
            for t = total_steps : -1 : 1
                recovered(t) = input_bits(curr_state_idx);
                branch = traceback(curr_state_idx, t);
                curr_state_idx = prev_states(curr_state_idx, branch) + 1;
            end
            
            avail_len = min(num_info_bits, length(recovered));
            out_data = recovered(1 : avail_len);
            metrics = struct('final_metric', path_metric(1), 'decoded_bits', avail_len);

        otherwise
            error('Unsupported action: %s. Use ''encode'' or ''decode''.', action);
    end
end
