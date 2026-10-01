# Commercial FM Broadcast Radio Receiver (88–108 MHz) with Live Audio Playback

> **Software-Defined Radio Real-World Application**  
> **Repository Reference:** [MATLAB-Simulink-Challenge-Project-Hub](https://github.com/mathworks/MATLAB-Simulink-Challenge-Project-Hub/tree/main/projects/Build%20a%20wireless%20communications%20link%20with%20software%20defined%20radio)

---

## 📻 1. Project Overview

This project implements a complete physical-layer **Commercial FM Broadcast Radio Receiver** in MATLAB. It transforms complex baseband radio frequency (I/Q) signals into Hi-Fi audio playing **live through your PC speakers or headphones**.

---

## 📂 2. File Architecture

```
SS_project/
│
├── fm_receiver_main.m       % Master Script: Simulates FM station, demodulates, plots spectra, plays live audio
├── fm_demodulator.m         % Core DSP: Quadrature frequency discriminator, 75 μs de-emphasis, decimation
├── fm_synthesizer.m         % FM Station Generator: Multi-harmonic acoustic melody, pre-emphasis, ±75 kHz WBFM
├── fm_rtlsdr_live.m         % Hardware Streaming: Connects RTL-SDR / Pluto SDR to listen to real radio stations
└── README_FM_RADIO.md       % Comprehensive documentation & DSP derivations
```

---

## 🚀 3. How to Run

### Step 1: Run the Complete FM Receiver Simulation (No Hardware Required!)
1. Open MATLAB.
2. Ensure your Current Folder is set to `C:\Users\Students\Desktop\SS_project`.
3. In the MATLAB Command Window, run:
   ```matlab
   fm_receiver_main
   ```
4. **Turn up your PC speakers!** You will immediately hear the recovered acoustic music chord progression playing with high fidelity.
5. Two diagnostic figures will pop up:
   - **Figure 1 (RF & MPX Spectra):** Shows the $200\text{ kHz}$ RF channel spectrum, $15\text{ kHz}$ mono audio, $19\text{ kHz}$ stereo pilot tone spike, and $57\text{ kHz}$ RDS subcarrier.
   - **Figure 2 (Oscilloscope):** Shows the original acoustic music waveform vs. the demodulated audio signal (with correlation $> 0.99$).

---

### Step 2: Listen to Real Local FM Radio Stations (with RTL-SDR / Pluto)
If you have an **RTL-SDR USB dongle** ($25) or **ADALM-PLUTO** with an antenna:
1. Open [`fm_rtlsdr_live.m`](file:///c:/Users/Students/Desktop/SS_project/fm_rtlsdr_live.m) and edit `StationFrequency` to your local radio station (e.g. `98.5e6`, `101.1e6`, `104.5e6`):
   ```matlab
   StationFrequency = 98.5e6; % Set your favorite local station
   ```
2. In the MATLAB Command Window, run:
   ```matlab
   fm_rtlsdr_live
   ```
3. You will hear **live broadcast music, news, and talk radio** streaming in real time straight to your speakers!

---

## 🧠 4. DSP Theory & Mathematical Derivations

### A. Wideband Frequency Modulation (WBFM)
Commercial FM stations modulate the instantaneous frequency of the RF carrier:
$$s(t) = A_c \exp\left(j \left(2\pi f_c t + 2\pi \Delta f \int_{-\infty}^t m(\tau) d\tau\right)\right)$$
Where:
- Peak frequency deviation: $\Delta f = \pm 75\text{ kHz}$.
- Maximum audio frequency: $f_m = 15\text{ kHz}$.
- Carson's Rule Bandwidth: $B_{\text{FM}} \approx 2(\Delta f + f_m) = 2(75 + 15) = 180\text{ kHz}$.

### B. Quadrature Frequency Discrimination
At baseband, the received signal is $r[n] = I[n] + j Q[n] = A[n] e^{j \theta[n]}$.  
The instantaneous phase difference between consecutive samples is computed via conjugate multiplication:
$$r[n] \cdot r^*[n-1] = A[n] A[n-1] e^{j (\theta[n] - \theta[n-1])}$$
$$\Delta \theta[n] = \text{angle}\left(r[n] \cdot r^*[n-1]\right)$$
The recovered audio/multiplex signal is directly proportional to the phase derivative:
$$m[n] = \frac{F_s}{2\pi \Delta f} \cdot \Delta \theta[n]$$

### C. Standard De-Emphasis Filtering ($75\ \mu\text{s}$)
Transmitters boost high-frequency audio (pre-emphasis) to counteract triangular FM noise. The receiver cancels this using a first-order de-emphasis lowpass filter:
$$H(s) = \frac{1}{1 + s \tau}, \quad \tau = 75\ \mu\text{s}$$
In discrete time via the bilinear transform:
$$y[n] = \alpha \cdot x[n] + (1 - \alpha) \cdot y[n-1], \quad \alpha = \frac{\Delta t}{\tau + \Delta t}$$

### D. Audio Decimation & Resampling
The RF signal sampled at $F_{s,\text{RF}} = 240\text{ kHz}$ is filtered with a 5th-order Butterworth anti-aliasing filter ($f_{\text{cutoff}} = 15\text{ kHz}$) and decimated by factor $M = 5$ down to standard Hi-Fi $F_{s,\text{audio}} = 48\text{ kHz}$.
