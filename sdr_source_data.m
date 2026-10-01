function varargout = sdr_source_data(action, varargin)
% SDR_SOURCE_DATA - Text, Image, and Payload Bitstream Converter
%
% Syntax:
%   bits = sdr_source_data('text_to_bits', text_str)
%   text_str = sdr_source_data('bits_to_text', bits)
%   [bits, dims] = sdr_source_data('image_to_bits', img)
%   img = sdr_source_data('bits_to_image', bits, dims)
%   img = sdr_source_data('get_default_image')
%
% Author: DSP & Communications Systems Engineer
% Project: MathWorks SDR Wireless Communications Link (Project 162)

    switch lower(action)
        case 'text_to_bits'
            text_str = varargin{1};
            uint_vals = uint8(text_str(:));
            num_chars = length(uint_vals);
            bits = zeros(num_chars * 8, 1);
            for b = 1 : 8
                bits(b : 8 : end) = double(bitget(uint_vals, 9 - b));
            end
            varargout{1} = bits;

        case 'bits_to_text'
            bits = varargin{1}(:);
            num_chars = floor(length(bits) / 8);
            if num_chars == 0
                varargout{1} = '';
                return;
            end
            char_bytes = zeros(num_chars, 1, 'uint8');
            for b = 1 : 8
                bit_slice = uint8(bits(b : 8 : num_chars * 8));
                char_bytes = bitset(char_bytes, 9 - b, bit_slice);
            end
            % Replace non-printable ASCII characters (<32 or >126) with '?' for clean display
            raw_chars = char(char_bytes');
            clean_chars = raw_chars;
            unprintable = (char_bytes < 32 & char_bytes ~= 10 & char_bytes ~= 13) | char_bytes > 126;
            clean_chars(unprintable) = '?';
            varargout{1} = clean_chars;

        case 'image_to_bits'
            img = varargin{1};
            if size(img, 3) > 1
                img = rgb2gray(img);
            end
            % Binarize to 0/1 bitmap if not already
            if islogical(img) || max(img(:)) <= 1
                img_bin = double(img > 0.5);
            else
                img_bin = double(img > 127);
            end
            dims = size(img_bin);
            bits = img_bin(:);
            varargout{1} = bits;
            varargout{2} = dims;

        case 'bits_to_image'
            bits = varargin{1}(:);
            dims = varargin{2};
            total_px = prod(dims);
            avail_bits = bits(1 : min(length(bits), total_px));
            if length(avail_bits) < total_px
                avail_bits = [avail_bits; zeros(total_px - length(avail_bits), 1)];
            end
            img = reshape(avail_bits, dims);
            varargout{1} = img;

        case 'get_default_image'
            % Generate a standard 36x36 high-contrast "SDR" logo bitmap
            H = 36; W = 36;
            img = zeros(H, W);
            % Outer border
            img(2:3, 2:W-1) = 1; img(H-2:H-1, 2:W-1) = 1;
            img(2:H-1, 2:3) = 1; img(2:H-1, W-2:W-1) = 1;
            
            % Draw 'S'
            img(7:9, 6:13) = 1;
            img(10:15, 6:8) = 1;
            img(16:18, 6:13) = 1;
            img(19:24, 11:13) = 1;
            img(25:27, 6:13) = 1;
            
            % Draw 'D'
            img(7:27, 16:18) = 1;
            img(7:9, 18:22) = 1;
            img(25:27, 18:22) = 1;
            img(10:24, 22:24) = 1;
            
            % Draw 'R'
            img(7:27, 27:29) = 1;
            img(7:9, 29:33) = 1;
            img(16:18, 29:33) = 1;
            img(10:15, 32:34) = 1;
            for d = 0:8
                img(19 + d, min(W-2, 28 + d : 29 + d)) = 1;
            end
            varargout{1} = img;

        otherwise
            error('Unsupported action: %s.', action);
    end
end
