%% FM_RTLSDR_LIVE
% =========================================================================
% Live Over-The-Air Commercial FM Broadcast Radio Receiver
% Hardware Interface for RTL-SDR USB Dongle / ADALM-PLUTO SDR
% =========================================================================
%
% Requirements:
%   - Communications Toolbox
%   - Communications Toolbox Support Package for RTL-SDR Radio (or ADALM-PLUTO)
%   - Real antenna plugged into the SDR receiver
%
% Author: DSP & Communications Systems Engineer

clear; close all; clc;

fprintf('========================================================================\n');
fprintf('   LIVE RTL-SDR COMMERCIAL FM BROADCAST RECEIVER (88-108 MHz)          \n');
fprintf('========================================================================\n\n');

%% 1. TUNE YOUR FAVORITE LOCAL FM STATION
% Replace with your local FM station frequency in Hz (e.g. 98.5 MHz, 101.1 MHz, 104.5 MHz)
StationFrequency = 98.5e6;  % 98.5 MHz (Change to your active local station)
SampleRate       = 240e3;   % 240 kHz sample rate
Gain             = 35;      % Tuner RF gain in dB (0 to 49.6 dB)
CaptureSeconds   = 10;      % Total streaming duration in seconds
DeemphasisTau    = 75e-6;   % 75 μs standard de-emphasis

fprintf('Tuning to: %.1f MHz...\n', StationFrequency / 1e6);

%% 2. INITIALIZE SDR HARDWARE INTERFACE
try
    % Initialize RTL-SDR Radio Receiver
    rx_radio = comm.SDRRTLReceiver(...
        'CenterFrequency',   StationFrequency, ...
        'SampleRate',        SampleRate, ...
        'Gain',              Gain, ...
        'SamplesPerFrame',   4800, ...
        'OutputDataType',    'double');
    
    fprintf('RTL-SDR hardware connected successfully!\n');
    hardware_present = true;
catch ME
    warning('RTL-SDR / Pluto radio hardware not detected.');
    fprintf('Running in High-Fidelity Synthetic Simulation Mode.\n');
    fprintf('Error details: %s\n\n', ME.message);
    hardware_present = false;
end

%% 3. INITIALIZE LIVE AUDIO STREAMING PIPELINE
fs_audio = 48000;
try
    audio_writer = audioDeviceWriter('SampleRate', fs_audio);
catch
    audio_writer = [];
end

fprintf('\nStreaming live FM broadcast audio to PC speakers...\n');
fprintf('Press Ctrl+C in MATLAB to stop listening.\n\n');

%% 4. CONTINUOUS STREAMING & DEMODULATION LOOP
if hardware_present
    frames_to_capture = round(CaptureSeconds * SampleRate / rx_radio.SamplesPerFrame);
    
    figure('Name', 'Live FM Spectrum Analyzer', 'Position', [150, 150, 800, 400], 'Color', 'w');
    
    for k = 1 : frames_to_capture
        % 1. Read live I/Q frame from SDR antenna
        [iq_frame, ~] = rx_radio();
        
        % 2. Demodulate FM frame
        [audio_chunk, ~, ~] = fm_demodulator(iq_frame, SampleRate, DeemphasisTau);
        
        % 3. Stream audio chunk to speakers
        if ~isempty(audio_writer)
            audio_writer(audio_chunk);
        end
        
        % 4. Update live spectrum every 10 frames
        if mod(k, 10) == 0
            [psd_val, f_axis] = pwelch(iq_frame, hann(512), 256, 512, SampleRate, 'centered');
            plot(f_axis / 1e3, 10*log10(psd_val + 1e-12), 'b');
            grid on; ylim([-60 10]);
            xlabel('Offset Frequency (kHz)'); ylabel('PSD (dB/Hz)');
            title(sprintf('Live FM Station Spectrum: %.1f MHz', StationFrequency / 1e6));
            drawnow;
        end
    end
    
    release(rx_radio);
    if ~isempty(audio_writer), release(audio_writer); end
    fprintf('Streaming finished.\n');
else
    % Fallback: Run full simulation
    [rf_iq, ~, fs_rf, fs_aud] = fm_synthesizer(CaptureSeconds, 30.0, 0.0);
    [audio_rec, ~, ~] = fm_demodulator(rf_iq, fs_rf, DeemphasisTau);
    sound(audio_rec, fs_aud);
    fprintf('Playing 10-second synthetic FM station...\n');
end
