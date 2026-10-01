function [out_bits, is_valid, num_parity_errors] = sdr_crc(action, in_bits)
% SDR_CRC - IEEE 802.3 Standard CRC-32 Generator & Error Detector
%
% Syntax:
%   out_bits = sdr_crc('encode', data_bits)
%   [data_bits, is_valid, num_errs] = sdr_crc('decode', rx_bits)
%
% Polynomial:
%   x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link (Project 162)

    in_bits = in_bits(:); % Ensure column vector
    
    % IEEE 802.3 CRC-32 Generator Polynomial (Degree 32, 33 coefficients)
    poly = [1 0 0 0 0 0 1 0 0 1 1 0 0 0 0 0 1 0 0 0 1 1 1 0 1 1 0 1 1 0 1 1 1]';
    deg = 32;

    switch lower(action)
        case 'encode'
            % Append 32 zeros and divide by generator polynomial in GF(2)
            msg_len = length(in_bits);
            pad = [in_bits; zeros(deg, 1)];
            rem_reg = pad;
            
            for i = 1 : msg_len
                if rem_reg(i) == 1
                    rem_reg(i : i + deg) = xor(rem_reg(i : i + deg), poly);
                end
            end
            
            crc_checksum = rem_reg(end - deg + 1 : end);
            out_bits = [in_bits; crc_checksum];
            is_valid = true;
            num_parity_errors = 0;

        case 'decode'
            if length(in_bits) <= deg
                error('Received bitstream too short to contain 32-bit CRC.');
            end
            
            msg_len = length(in_bits) - deg;
            rem_reg = in_bits;
            
            for i = 1 : msg_len
                if rem_reg(i) == 1
                    rem_reg(i : i + deg) = xor(rem_reg(i : i + deg), poly);
                end
            end
            
            syndrome = rem_reg(end - deg + 1 : end);
            num_parity_errors = sum(syndrome);
            is_valid = (num_parity_errors == 0);
            out_bits = in_bits(1 : msg_len);

        otherwise
            error('Unsupported action: %s. Use ''encode'' or ''decode''.', action);
    end
end
