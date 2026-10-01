# Software-Defined Radio (SDR) Wireless Communications Link

> **MathWorks Challenge Project 162:** *Build a wireless communications link with software-defined radio.*  
> **Repository Reference:** [MATLAB-Simulink-Challenge-Project-Hub](https://github.com/mathworks/MATLAB-Simulink-Challenge-Project-Hub/tree/main/projects/Build%20a%20wireless%20communications%20link%20with%20software%20defined%20radio)

---

## 📌 Project Overview

This MATLAB codebase provides an end-to-end, modular physical-layer **Software-Defined Radio (SDR) transceiver**. It models full-stack digital communications:
1. **Transmitter**: Preamble framing, 11-bit Barker code sync word, BPSK/QPSK modulation, and Root-Raised-Cosine (RRC) pulse shaping.
2. **RF Hardware Impairment Channel**: Fractional sample clock drift, Carrier Frequency Offset (CFO), carrier phase rotation, mixer DC leakage bias, analog I/Q gain/phase imbalance, and AWGN noise.
3. **Software DSP Calibration & Synchronization**:
   - **DC Estimator & Subtractor**: Cancels mixer LO self-mixing bias.
   - **Gram-Schmidt Orthogonalization (GSO)**: Blind real-time I/Q quadrature balancing.
   - **RRC Matched Filter**: Maximizes output SNR and eliminates ISI.
   - **Gardner Timing Error Detector (TED)**: Closed-loop continuous cubic Hermite interpolator locking to optimal symbol strobe instants.
   - **2nd-Order Costas Loop PLL**: Tracks and eliminates residual CFO and carrier phase rotation.
   - **Barker Frame Synchronizer**: Detects frame boundary and resolves $180^\circ$ Costas phase ambiguity.
4. **Hardware Support**: Ready for over-the-air deployment on **ADALM-PLUTO**, **RTL-SDR**, or **USRP** hardware.

---

## 📂 File Directory & Architecture

```
SS_project/
│
├── main_sdr_transceiver.m    % Master script: Runs end-to-end transceiver & plots 4-figure dashboard
├── sdr_tx.m                  % Transmitter function: Frame assembly, BPSK/QPSK, RRC filtering
├── sdr_channel.m             % Channel emulator: Injects delay, CFO, phase, DC, IQ imbalance, AWGN
├── sdr_rx.m                  % Receiver function: DC cancel, GSO, Gardner TED, Costas PLL, Frame sync
├── sdr_ber_sweep.m           % Monte Carlo script: Automated SNR sweep vs theoretical Q(√(2Eb/N0))
├── sdr_hardware_pluto.m      % Over-the-air (OTA) script for ADALM-PLUTO / RTL-SDR hardware
└── README_MATLAB.md          % User guide and DSP theoretical derivations
```

---

## 🚀 How to Run the MATLAB Scripts

### 1. Run the Main Transceiver Simulation
Open MATLAB, set current folder to `SS_project/`, and execute:
```matlab
main_sdr_transceiver
```
**Expected Output:**
- Terminal prints a detailed link diagnostic report (injected vs estimated CFO, DC magnitude, Barker peak, bit errors, and empirical vs theoretical BER).
- Spawns 4 visualization windows:
  1. **Figure 1: Dual-Pane Constellation** (Raw spinning impaired front-end vs. synchronized output).
  2. **Figure 2: Closed-Loop Convergence** (Gardner TED transient and Costas PLL frequency acquisition in Hz).
  3. **Figure 3: Time-Domain Waveforms & Eye Diagram** (Tx pulse vs Rx matched filter output and folded 2-symbol eye opening).
  4. **Figure 4: Barker Cross-Correlation Profile** (Sharp correlation spike at frame boundary).

---

### 2. Run the Monte Carlo BER Waterfall Sweep
To evaluate Bit Error Rate performance across a range of SNRs ($-4\text{ dB}$ to $+11\text{ dB}$):
```matlab
sdr_ber_sweep
```
**Expected Output:**
- A console progress table reporting bit errors for each SNR point.
- A semi-logarithmic plot showing empirical SDR receiver BER matching the analytical theoretical curve:
  $$P_b = Q\left(\sqrt{\frac{2E_b}{N_0}}\right) = \frac{1}{2}\text{erfc}\left(\sqrt{\frac{E_b}{N_0}}\right)$$

---

### 3. Run Over-The-Air with Hardware (ADALM-PLUTO / RTL-SDR)
If you have an **ADALM-PLUTO** or **RTL-SDR** radio connected:
```matlab
sdr_hardware_pluto
```
*(If no hardware is detected, the script automatically falls back to loopback emulation mode with zero crashes).*

---

## 📚 Mathematical Formulations & DSP Derivations

### 1. Root-Raised-Cosine (RRC) Pulse Shaping
To satisfy the Nyquist Inter-Symbol Interference (ISI) Criterion with roll-off factor $\beta \in [0, 1]$:
$$h_{\text{RRC}}(t) = \begin{cases}
1 - \beta + \frac{4\beta}{\pi}, & t = 0 \\
\frac{\beta}{\sqrt{2}} \left[ \left(1 + \frac{2}{\pi}\right)\sin\left(\frac{\pi}{4\beta}\right) + \left(1 - \frac{2}{\pi}\right)\cos\left(\frac{\pi}{4\beta}\right) \right], & t = \pm \frac{T_s}{4\beta} \\
\frac{\sin\left(\pi \frac{t}{T_s}(1-\beta)\right) + 4\beta \frac{t}{T_s} \cos\left(\pi \frac{t}{T_s}(1+\beta)\right)}{\pi \frac{t}{T_s}\left(1 - (4\beta \frac{t}{T_s})^2\right)}, & \text{otherwise}
\end{cases}$$

### 2. Direct-Conversion DC Bias Cancellation
Direct-conversion homodyne receivers suffer from LO leakage resulting in a constant complex DC offset:
$$\hat{\mu}_{\text{DC}} = \frac{1}{N}\sum_{n=0}^{N-1} r[n], \quad r_1[n] = r[n] - \hat{\mu}_{\text{DC}}$$

### 3. Gram-Schmidt Orthogonalization (GSO) I/Q Balancing
Quadrature mixer phase imbalance $\phi$ causes cross-talk between In-Phase and Quadrature branches:
$$\sin(\phi) \approx \frac{\mathbb{E}[I \cdot Q]}{\mathbb{E}[I^2]}$$
Orthogonalization:
$$Q' = Q - \sin(\phi) \cdot I, \quad I_{\text{cal}} = \frac{I}{\sqrt{\mathbb{E}[I^2]}}, \quad Q_{\text{cal}} = \frac{Q'}{\sqrt{\mathbb{E}[(Q')^2]}}$$

### 4. Gardner Symbol Timing Error Detector (TED)
Non-data-aided timing recovery using 2 samples per symbol ($T/2$ spacing):
$$e_t[k] = \text{Re}\left\{ \left(y[k] - y[k-1]\right) \cdot y^*\left[k - \frac{1}{2}\right] \right\}$$
Proportional-Integral (PI) loop filter adjusts a continuous 4-point cubic Hermite interpolator to sample at optimal strobe instants.

### 5. 2nd-Order Costas Loop Phase-Locked Loop (PLL)
Tracks Carrier Frequency Offset (CFO) and phase rotation $\theta[k]$:
$$e_p[k] = \text{sign}\left(\text{Re}\{z[k]\}\right) \cdot \text{Im}\{z[k]\}$$
$$\Delta\omega[k+1] = \Delta\omega[k] + K_i e_p[k], \quad \theta[k+1] = \theta[k] + \Delta\omega[k+1] + K_p e_p[k]$$
$$z[k] = y[k] \cdot e^{-j \theta[k]}$$

### 6. Barker Sequence Correlation & 180° Ambiguity Resolution
Cross-correlates against 11-bit Barker sequence $P = [+1, +1, +1, -1, -1, -1, +1, -1, -1, +1, -1]$:
$$k_{\text{start}} = \arg\max_k |(z_{\text{rot}} * P)[k]|, \quad s_{\text{ambig}} = \text{sign}\left((z_{\text{rot}} * P)[k_{\text{start}}]\right)$$
If $s_{\text{ambig}} < 0$, the received constellation is inverted to resolve the BPSK Costas loop $180^\circ$ ambiguity.

---

## ⚙️ Configurable Parameters (in `main_sdr_transceiver.m`)

| Parameter | Default | Description |
|---|---|---|
| `tx_cfg.num_payload_bits` | `4000` | Payload data bits per frame |
| `tx_cfg.sps` | `8` | Samples per symbol (oversampling factor) |
| `tx_cfg.beta` | `0.35` | RRC filter roll-off factor |
| `chan_cfg.snr_db` | `16.0 dB` | Channel Signal-to-Noise Ratio ($E_b/N_0$) |
| `chan_cfg.timing_offset_samples` | `3.25` | Fractional clock timing delay |
| `chan_cfg.cfo_hz` | `250.0 Hz` | Carrier Frequency Offset (CFO) |
| `chan_cfg.dc_offset_bias` | `0.15 V` | Direct-conversion DC offset |
| `chan_cfg.gain_imbalance_pct` | `8.0%` | Mixer I/Q amplitude imbalance |
| `chan_cfg.phase_imbalance_deg`| `6.0°` | Mixer I/Q phase quadrature error |
