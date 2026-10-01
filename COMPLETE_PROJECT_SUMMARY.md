# Complete SDR Project Summary & Implementation Guide
=====================================================
**Project Title:** Software-Defined Radio (SDR) Wireless Communications Transceiver & Commercial FM Broadcast Receiver  
**Repository Reference:** [MathWorks Challenge Project 162](https://github.com/mathworks/MATLAB-Simulink-Challenge-Project-Hub/tree/main/projects/Build%20a%20wireless%20communications%20link%20with%20software%20defined%20radio)

---

## 📌 Executive Summary

This project implements two complete real-world SDR systems in MATLAB with 100% completion of MathWorks Challenge Project 162:

1. **End-to-End Digital BPSK/QPSK Transceiver**:
   - **Transmitter (`sdr_tx.m`)**: Framing (120-sym preamble + 11-bit Barker code sync word + payload bits), BPSK/QPSK mapping, Root-Raised-Cosine (RRC) pulse shaping.
   - **Error Control Coding (`sdr_crc.m`, `sdr_fec.m`)**: Standard IEEE 802.3 CRC-32 integrity checking and Rate 1/2 $K=7$ Convolutional Encoding with 64-state Viterbi decoding.
   - **Source Data Engine (`sdr_source_data.m`)**: Real ASCII text message and 2D image bitmap serialization and reconstruction.
   - **RF Impairment Channel (`sdr_channel.m`)**: Emulates fractional clock drift, Carrier Frequency Offset (CFO), phase rotation, direct-conversion DC leakage bias, I/Q gain/phase imbalance, and AWGN noise.
   - **Receiver DSP Calibration (`sdr_rx.m`)**: Sample mean DC subtractor, Gram-Schmidt I/Q orthogonalization (GSO), RRC matched filtering, continuous cubic Hermite Gardner Timing Error Detector (TED), Squaring/4th-power FFT Coarse CFO correction, 2nd-order Costas Phase-Locked Loop (PLL), Barker frame sync, 4-quadrant phase ambiguity resolver, and Viterbi decoding.
   - **Autonomous Packet Trigger (`sdr_packet_detect.m`)**: Over-the-air normalized cross-correlation trigger for asynchronous hardware buffers without pre-known delay.
   - **Hardware Over-The-Air (`sdr_hardware_transceiver.m`, `sdr_hardware_pluto.m`)**: Unified script for National Instruments USRP (B200/B210/N210/X310) and ADALM-PLUTO.
   - **Design Optimization Study (`sdr_optimization_study.m`)**: Challenge Step 7 systematic Throughput vs. Reliability evaluation across SNR.
   - **Image Transmission Demonstrator (`demo_image_transceiver.m`)**: Visual side-by-side transmission and recovery of 2D image bitmaps.
   - **Monte Carlo BER Sweep (`sdr_ber_sweep.m`)**: Sweeps SNR against theoretical analytical curves.

2. **Commercial FM Broadcast Radio Receiver (88–108 MHz) with Live Audio Playback**:
   - **Core DSP Demodulator (`fm_demodulator.m`)**: 200 kHz channel bandpass filtering, quadrature frequency discriminator ($\Delta \theta[n] = \angle(r[n] \cdot r^*[n-1])$), standard $75\ \mu\text{s}$ de-emphasis filtering, and decimation to 48 kHz audio.
   - **FM Broadcast Synthesizer (`fm_synthesizer.m`)**: Multi-harmonic acoustic chord progression melody, $75\ \mu\text{s}$ pre-emphasis, 19 kHz stereo pilot tone, 57 kHz RDS subcarrier, $\pm 75\text{ kHz}$ WBFM modulation, and multipath fading.
   - **Master FM Player (`fm_receiver_main.m`)**: Runs receiver, displays RF spectrum + MPX spectrum + oscilloscope, and **plays live audio through PC speakers**!
   - **Live RTL-SDR Radio (`fm_rtlsdr_live.m`)**: Streams live local commercial radio stations (88–108 MHz) in real-time.

---

## 📂 File Architecture

```
SS_project/
│
├── COMPLETE_PROJECT_SUMMARY.md    % Comprehensive project notes, math, and execution steps
├── README_MATLAB.md               % Digital Transceiver documentation & DSP derivations
├── README_FM_RADIO.md             % FM Radio Receiver documentation & derivations
│
├── main_sdr_transceiver.m         % [RUN] Master Transceiver: Text/Random, BPSK/QPSK, FEC, CRC
├── sdr_optimization_study.m       % [RUN] MathWorks Step 7: Throughput vs. Reliability Study
├── demo_image_transceiver.m       % [RUN] Side-by-side 2D image transmission & recovery
├── sdr_hardware_transceiver.m     % [RUN] Unified OTA transceiver for NI USRP & ADALM-Pluto
├── sdr_ber_sweep.m                % [RUN] Monte Carlo BER vs. Theoretical SNR sweep
├── test_async_ota_link.m          % [RUN] Verification of autonomous OTA packet acquisition
│
├── sdr_tx.m                       % Transmitter engine (Preamble, Barker, RRC, FEC, CRC)
├── sdr_rx.m                       % Receiver DSP (DC, GSO, Gardner, Costas, Ambiguity, Viterbi)
├── sdr_channel.m                  % Channel emulator (Delay, CFO, DC, IQ Imbalance, Noise)
├── sdr_fec.m                      % Rate 1/2 K=7 Convolutional Encoder & Viterbi Decoder
├── sdr_crc.m                      % IEEE 802.3 CRC-32 Checksum Generator & Detector
├── sdr_source_data.m              % Text and 2D image bitmap serialization engine
├── sdr_packet_detect.m            % Autonomous OTA packet arrival trigger
├── sdr_hardware_pluto.m           % ADALM-PLUTO hardware interface
│
├── fm_receiver_main.m             % [RUN] Master Commercial FM Radio (Plays Live Audio!)
├── fm_demodulator.m               % FM Demodulator (Quadrature Demod, De-Emphasis, 48 kHz)
├── fm_synthesizer.m               % FM Broadcast Station Generator (Acoustic audio, WBFM)
└── fm_rtlsdr_live.m               % [RUN] Live RTL-SDR broadcast receiver
```

---

## 🚀 How to Run on Any Computer with MATLAB

1. Copy the `SS_project` folder to the target computer.
2. Open **MATLAB**.
3. In the MATLAB Current Folder toolbar, browse to `SS_project`.
4. Run any of the master scripts in the Command Window:
   - To test the **Digital SDR Transceiver**:
     ```matlab
     main_sdr_transceiver
     ```
   - To test the **Commercial FM Radio with Live Sound**:
     ```matlab
     fm_receiver_main
     ```
   - To run the **Monte Carlo BER Waterfall Curve**:
     ```matlab
     sdr_ber_sweep
     ```

---

## 🧠 Key Theoretical DSP Derivations

### 1. Root-Raised-Cosine (RRC)
$$h_{\text{RRC}}(t) = \frac{\sin(\pi t (1-\beta)) + 4\beta t \cos(\pi t (1+\beta))}{\pi t (1 - (4\beta t)^2)}$$
Splits the Nyquist Raised-Cosine filter evenly between transmitter and receiver to maximize SNR while maintaining zero ISI.

### 2. DC Offset Estimation & Removal
$$\hat{\mu}_{\text{DC}} = \frac{1}{N}\sum_{n=0}^{N-1} r[n], \quad r_1[n] = r[n] - \hat{\mu}_{\text{DC}}$$

### 3. Gram-Schmidt I/Q Orthogonalization (GSO)
$$\sin(\phi) \approx \frac{\mathbb{E}[I \cdot Q]}{\mathbb{E}[I^2]}, \quad Q' = Q - \sin(\phi) \cdot I$$

### 4. Gardner Timing Error Detector (TED)
$$e_t[k] = \text{Re}\left\{ (y[k] - y[k-1]) \cdot y^*\left[k - \frac{1}{2}\right] \right\}$$

### 5. Costas Loop Carrier Recovery PLL
$$e_p[k] = \text{sign}(\text{Re}\{z[k]\}) \cdot \text{Im}\{z[k]\}, \quad \theta[k+1] = \theta[k] + \Delta\omega[k+1] + K_p e_p[k]$$

### 6. FM Quadrature Frequency Discrimination & De-Emphasis
$$m[n] = \frac{F_s}{2\pi \Delta f} \cdot \angle\left(r[n] \cdot r^*[n-1]\right)$$
$$y[n] = \alpha \cdot x[n] + (1 - \alpha) \cdot y[n-1], \quad \alpha = \frac{\Delta t}{\tau + \Delta t}, \quad \tau = 75\ \mu\text{s}$$
