# Software-Defined Radio (SDR) Wireless Communications Link

[![MATLAB](https://img.shields.io/badge/MATLAB-R2025b%20Compatible-orange.svg)](https://www.mathworks.com/products/matlab.html)
[![MathWorks Challenge](https://img.shields.io/badge/MathWorks%20Challenge-Project%20162-blue.svg)](https://github.com/mathworks/MATLAB-Simulink-Challenge-Project-Hub/tree/main/projects/Build%20a%20wireless%20communications%20link%20with%20software%20defined%20radio)
[![Hardware](https://img.shields.io/badge/Hardware-NI%20USRP%20%7C%20ADALM--PLUTO%20%7C%20RTL--SDR-green.svg)](https://www.ni.com/en-us/shop/category/software-defined-radios.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An end-to-end, physical-layer **Software-Defined Radio (SDR) Transceiver** and **Commercial FM Broadcast Receiver** built in MATLAB. 

Developed in response to **MathWorks Challenge Project 162: *Build a wireless communications link with software-defined radio*** (endorsed by **National Instruments**).

---

## 📌 Project Overview

This codebase delivers two complete SDR systems:

1. **Digital Transceiver (BPSK / QPSK)**:
   - **Forward Error Correction (FEC)**: Rate 1/2, Constraint Length $K=7$ Convolutional coding with 64-state soft/hard Viterbi decoding.
   - **Packet Integrity**: IEEE 802.3 standard 32-bit Cyclic Redundancy Check (CRC-32).
   - **Real Source Data Modes**: Arbitrary ASCII text messaging and 2D image bitmap transmission with visual side-by-side reconstruction.
   - **Autonomous Frame Acquisition**: Normalized cross-correlation packet trigger for asynchronous streaming hardware buffers without pre-known time-of-arrival.
   - **Receiver DSP Calibration**: Direct-conversion DC offset cancellation, Gram-Schmidt I/Q orthogonalization (GSO), Gardner timing error detector (TED) with cubic Hermite interpolation, 2nd-order Costas loop PLL, and 4-phase ambiguity resolution.
   - **Hardware Ready**: Supports **NI USRP** (B200, B210, N210, X310) and **ADALM-PLUTO**, with automatic fallback to loopback simulation.
   - **Design Optimization Study**: Systematic throughput vs. reliability trade-off analysis across SNR (MathWorks Challenge Step 7).

2. **Commercial FM Broadcast Radio Receiver (88–108 MHz)**:
   - Wideband FM (WBFM, $\Delta f = \pm 75\text{ kHz}$) demodulator with quadrature frequency discrimination ($\Delta\theta[n] = \angle(r[n] \cdot r^*[n-1])$).
   - 75 μs standard broadcast de-emphasis IIR filter.
   - Synthesizer with 19 kHz stereo pilot tone, 57 kHz RDS digital subcarrier, and acoustic musical melody.
   - Live PC speaker playback (`soundsc`) and automatic export to `.wav`.

---

## 🏗️ System Architecture

```
                  ┌────────────────────────────────────────────────────────┐
                  │                   TRANSMITTER (Tx)                     │
                  │  Source Data ──> CRC-32 ──> Conv Encoder ──> Framing   │
                  │  ──> BPSK/QPSK Mapping ──> RRC Pulse Shaping Filter    │
                  └───────────────────────────┬────────────────────────────┘
                                              │ (RF I/Q Baseband)
                                              ▼
                  ┌────────────────────────────────────────────────────────┐
                  │                 RF IMPAIRMENT CHANNEL                  │
                  │  Fractional Delay + Carrier Frequency Offset (CFO)     │
                  │  + DC Leakage + I/Q Imbalance + Multipath + AWGN       │
                  └───────────────────────────┬────────────────────────────┘
                                              │ (Impaired Signal)
                                              ▼
                  ┌────────────────────────────────────────────────────────┐
                  │                    RECEIVER (Rx)                       │
                  │  1. DC Bias Estimator & Subtractor                     │
                  │  2. Gram-Schmidt I/Q Quadrature Balancing              │
                  │  3. RRC Matched Filter (Zero ISI, Max SNR)             │
                  │  4. Gardner Timing Recovery (Cubic Hermite Strobe)     │
                  │  5. 2nd-Order Costas Loop PLL (CFO & Phase Lock)       │
                  │  6. Barker Cross-Correlation & Ambiguity Resolver      │
                  │  7. Viterbi FEC Decoder (64-State Trellis)             │
                  │  8. CRC-32 Frame Integrity Verification                │
                  └────────────────────────────────────────────────────────┘
```

---

## 📂 File Directory

| File | Description |
| :--- | :--- |
| **`main_sdr_transceiver.m`** | 🚀 **Master Script**: Runs end-to-end transceiver & plots 4-figure diagnostic dashboard |
| **`demo_image_transceiver.m`** | 🖼️ **Image Link**: Transmits 2D image over noisy RF channel with side-by-side visual recovery |
| **`sdr_optimization_study.m`** | 📊 **Trade-Off Study**: Evaluates 4 candidate design modes across SNR for MathWorks Step 7 |
| **`test_async_ota_link.m`** | 📡 **OTA Trigger Test**: Verifies autonomous packet acquisition in asynchronous streaming buffers |
| **`sdr_ber_sweep.m`** | 📉 **BER Waterfall**: Monte Carlo simulation vs. analytical $Q(\sqrt{2E_b/N_0})$ curves |
| **`sdr_hardware_transceiver.m`** | 📻 **Hardware OTA**: Unified interface for NI USRP & ADALM-PLUTO radios |
| **`fm_receiver_main.m`** | 🔊 **FM Broadcast Radio**: Demodulates commercial FM broadcast with live speaker audio |
| **`sdr_tx.m`** | Transmitter engine (Framing, RRC pulse shaping, BPSK/QPSK modulation) |
| **`sdr_channel.m`** | Physical RF channel emulator (CFO, DC, I/Q imbalance, fractional delay, noise) |
| **`sdr_rx.m`** | Receiver DSP calibration chain (DC, GSO, Gardner TED, Costas PLL, Barker sync) |
| **`sdr_fec.m`** | Rate 1/2 $K=7$ Convolutional encoder and 64-state Viterbi decoder |
| **`sdr_crc.m`** | IEEE 802.3 standard 32-bit CRC generator and detector |
| **`sdr_source_data.m`** | ASCII text and 2D image serialization and deserialization |
| **`sdr_packet_detect.m`** | Autonomous OTA packet arrival trigger using normalized cross-correlation |
| **`hann.m`, `butter.m`, `interp.m`, `pwelch.m`** | Standalone mathematical replacements enabling 100% operation on base MATLAB |

---

## 🚀 Getting Started

### Prerequisites
* MATLAB R2020b or later (tested and verified on **MATLAB R2025b**).
* **No paid toolboxes required**: Contains self-contained mathematical implementations of filter design and spectral estimation.
* Optional for live over-the-air RF: NI USRP, ADALM-PLUTO, or RTL-SDR.

### Running the Simulations

1. Clone or download this repository.
2. Open MATLAB and set the Current Folder to the repository root.
3. Execute any of the master scripts:

```matlab
% 1. Run the Digital SDR Transceiver Dashboard
main_sdr_transceiver

% 2. Run the 2D Wireless Image Transmission Demonstrator
demo_image_transceiver

% 3. Run the Commercial FM Radio Receiver (with live audio playback!)
fm_receiver_main

% 4. Run the Throughput vs. Reliability Optimization Study
sdr_optimization_study

% 5. Test Autonomous Over-The-Air Packet Acquisition
test_async_ota_link
```

---

## 📊 Performance & Results

### 1. Digital Transceiver Link Performance
```
========================================================================
   SOFTWARE-DEFINED RADIO (SDR) TRANSCEIVER SIMULATOR - MATLAB ENGINE   
   MathWorks Challenge Project 162: Wireless Communications Link        
========================================================================
  Payload Bits Transmitted  : 472 bits (ASCII Text Message)
  Channel Bits (with FEC)   : 1020 bits (Rate 1/2 Convolutional)
  Channel SNR (Eb/N0)       : 16.0 dB
  Injected CFO              : 250.0 Hz | Estimated CFO: 250.3 Hz (Error: 0.3 Hz)
  Injected DC Offset        : 0.150 V  | Estimated DC: 0.145 V
  Barker Sync Peak Value    : 38.92 (Index 121)
  CRC-32 Checksum Status    : [PASS] Clean Packet Verified
  Final Info BER (Post-FEC) : 0.0000e+00 (0 / 472 bit errors)
  Status                    : [SUCCESS] PERFECT ERROR-FREE LINK ACHIEVED!
========================================================================
```

### 2. Commercial FM Broadcast Receiver Performance
```
------------------------------------------------------------------------
                     FM RECEIVER PERFORMANCE REPORT                     
------------------------------------------------------------------------
  RF Channel SNR            : 28.0 dB
  Max Frequency Deviation   : +/-75.0 kHz (Carson Bandwidth: 180 kHz)
  De-Emphasis Time Constant : 75 microseconds (Standard Americas)
  Audio Waveform Cross-Corr : 0.9902 (99.02% acoustic fidelity)
  Demodulated Audio SNR     : 16.27 dB
  Demodulation Speed        : 26.7x faster than real-time (0.187s for 5.0s audio)
------------------------------------------------------------------------
```

---

## 📚 Mathematical Formulations

### 1. Root-Raised-Cosine (RRC) Pulse Shaping
$$h_{\text{RRC}}(t) = \frac{\sin(\pi t (1-\beta)/T_s) + 4\beta (t/T_s) \cos(\pi t (1+\beta)/T_s)}{\pi (t/T_s) (1 - (4\beta t/T_s)^2)}$$

### 2. Direct-Conversion DC Bias Cancellation
$$\hat{\mu}_{\text{DC}} = \frac{1}{N}\sum_{n=0}^{N-1} r[n], \quad r_{\text{cal}}[n] = r[n] - \hat{\mu}_{\text{DC}}$$

### 3. Gram-Schmidt Orthogonalization (GSO) I/Q Balancing
$$\sin(\phi) \approx \frac{\mathbb{E}[I \cdot Q]}{\mathbb{E}[I^2]}, \quad Q' = Q - \sin(\phi) \cdot I, \quad Q_{\text{cal}} = \frac{Q'}{\sqrt{\mathbb{E}[(Q')^2]}}$$

### 4. Gardner Symbol Timing Error Detector (TED)
$$e_t[k] = \text{Re}\left\{ (y[k] - y[k-1]) \cdot y^*\left[k - \frac{1}{2}\right] \right\}$$

### 5. Costas Loop Carrier Recovery PLL
$$e_p[k] = \text{sign}(\text{Re}\{z[k]\}) \cdot \text{Im}\{z[k]\}$$
$$\Delta\omega[k+1] = \Delta\omega[k] + K_i e_p[k], \quad \theta[k+1] = \theta[k] + \Delta\omega[k+1] + K_p e_p[k]$$

### 6. FM Quadrature Frequency Discrimination & De-Emphasis
$$m[n] = \frac{F_s}{2\pi \Delta f} \cdot \angle\left(r[n] \cdot r^*[n-1]\right)$$
$$y[n] = \alpha x[n] + (1 - \alpha) y[n-1], \quad \alpha = \frac{\Delta t}{\tau + \Delta t}$$

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## 🤝 Acknowledgments

* **MathWorks**: For organizing the [MATLAB & Simulink Challenge Projects](https://github.com/mathworks/MATLAB-Simulink-Challenge-Project-Hub).
* **National Instruments**: For project endorsement and SDR hardware reference models.
