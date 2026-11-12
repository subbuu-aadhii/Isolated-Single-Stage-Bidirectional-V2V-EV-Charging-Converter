# Isolated-Single-Stage-Bidirectional-V2V-EV-Charging-Converter
Design, simulation and real-time (software-in-the-loop) validation of an isolated, single-stage, bidirectional **vehicle-to-vehicle (V2V)** charging converter, with a comparison of three charging-current controllers
- **PI** – proportional–integral control
- **ISMC** – integral sliding-mode control
- **FLC** – Mamdani fuzzy logic control

> **Status:** simulation and OPAL-RT software-in-the-loop (SIL) study. No hardware prototype has been built yet; see [Limitations](#limitations).

---

## Contents

1. [Introduction](#introduction)
2. [Repository structure](#repository-structure)
3. [Requirements](#requirements)
4. [How to run](#how-to-run)
5. [Converter topology and operation](#converter-topology-and-operation)
6. [Design calculations](#design-calculations)
7. [Controller design](#controller-design)
8. [Results](#results)
9. [Analysis and discussion](#analysis-and-discussion)
10. [Limitations](#limitations)
11. [Future work](#future-work)
12. [Authors](#authors)
13. [Citation and license](#citation-and-license)

---

## Introduction

V2V charging lets an EV with spare energy charge another EV directly, without a charging station. This is useful in emergencies or where charging infrastructure is sparse. A V2V converter has to:

- transfer power **in both directions** with the same hardware,
- match batteries of **different voltages** (here 350 V and 450 V),
- **regulate the charging current** of the receiving battery, and
- **galvanically isolate** the two vehicles for safety.

This project models the isolated single-stage topology proposed by Zhou et al. (2026). The three-phase **onboard-charger (OBC) bridges of both vehicles are reused**, and the vehicles are coupled through an external connector that contains a **series-resonant LC tank on each side and a 1:1 high-frequency transformer (HFT)**. Together with the battery-side filters, each side behaves like an isolated Ćuk-type converter, so a single stage handles both voltage matching and isolation.

On this topology the project:

1. builds the converter in MATLAB/Simulink and identifies the open-loop duty-ratio operating points for both power-flow directions,
2. designs PI, ISMC and FLC current controllers that share one gate-signal structure,
3. compares them on start-up transient, steady-state current tracking, efficiency and semiconductor losses, and
4. runs all three controllers in real time on an **OPAL-RT OP4610XG** simulator (SIL).

**Operating modes**

| Mode | Power flow | Source | Receiver | Regulated current |
|---|---|---|---|---|
| Mode 1 | EV1 → EV2 | EV1 (350 V) | EV2 (450 V) | $I_{B2}$ |
| Mode 2 | EV2 → EV1 | EV2 (450 V) | EV1 (350 V) | $I_{B1}$ |

---

## Repository structure

> The model files are added separately. Rename the entries below to match your actual file names.

```
.
├── README.md
├── models/
│   ├── open_loop/
│   │   └── v2v_open_loop.slx            # EV1 battery as source, EV2 as equivalent resistance (and reverse)
│   ├── closed_loop/
│   │   ├── v2v_closed_loop_pi.slx       # PI current controller
│   │   ├── v2v_closed_loop_ismc.slx     # Integral sliding-mode controller
│   │   ├── v2v_closed_loop_fuzzy.slx    # Fuzzy logic controller
│   │   └── ev_v2v.fis                   # Mamdani FIS used by the fuzzy controller
│   ├── losses/
│   │   ├── v2v_loss_model.slx           # Conduction + switching loss subsystem per switch
│   │   └── avg_loss.m                   # Average-loss post-processing script
│   └── opal_rt/
│       └── v2v_opalrt.slx               # Model partitioned into SM_ / SC_ subsystems for RT-LAB
├── scripts/
│   ├── triangle_carrier.m               # Carrier generator used in the MATLAB Function block
│   └── compare_plots.m                  # Overlay plots of PI / ISMC / FLC from workspace data
└── docs/
    └── images/                          # Figures used in this README
```

---

## Requirements

| Software | Used for |
|---|---|
| MATLAB / Simulink **R2024a** (or later) | All models |
| Simscape Electrical (Specialized Power Systems) | Power stage, batteries, switches |
| Fuzzy Logic Toolbox | `ev_v2v.fis` and the fuzzy controller block |
| OPAL-RT **RT-LAB** + OP4610XG target | Real-time SIL execution (optional) |

> The OPAL-RT model was built in R2024a. Check that your RT-LAB release supports the MATLAB version you are using before compiling.

---

## How to run

### Open-loop model

1. Open `models/open_loop/v2v_open_loop.slx`.
2. Set the duty ratio `D` (the study sweeps 0.40–0.60).
3. Select the mode. For **Mode 1**, EV1 (350 V, 60 Ah) is the source and EV2 is represented by $R_L$ = 8.4375 Ω. For **Mode 2**, EV2 (450 V, 80 Ah) is the source and EV1 is represented by $R_L$ = 5.1042 Ω.
4. Run the model. The receiving voltage reaches its nominal value at **D = 0.5724 (Mode 1)** and **D = 0.5710 (Mode 2)**.

### Closed-loop models (PI / ISMC / FLC)

1. Open the model for the controller you want to test.
2. For the fuzzy model, make sure `ev_v2v.fis` is on the MATLAB path.
3. Set the **SOC mode** input to select Mode 1 or Mode 2.
4. The reference is a staircase from **10 A to 50 A in 10 A steps every 3 s**.
5. Stop time: **15 s** for the stepped-reference study, **0.2 s** for the start-up transient study.

### Loss model

1. Run the loss model (or the closed-loop model with the loss subsystem enabled).
2. Run `avg_loss.m` to average the logged instantaneous loss over the chosen window.

### OPAL-RT (SIL)

1. Open `models/opal_rt/v2v_opalrt.slx` in RT-LAB. It contains a computation subsystem (`SM_b1`) and a supervisory subsystem (`SC_b1`).
2. Use a fixed step of **5 µs**.
3. Compile, load and execute on the OP4610XG.
4. Route the analog outputs to an oscilloscope. Eleven signals are exchanged: VB1, IB1, PB1, SOC1, VB2, IB2, PB2, SOC2, input, feedback and reference.

---

## Converter topology and operation

![Converter topology](docs/images/converter_topology.png)

*Isolated single-stage bidirectional V2V converter: reconfigured OBC bridge of EV1 (left), external resonant HFT connector (centre), reconfigured OBC bridge of EV2 (right). Topology after Zhou et al. (2026).*

### Components

| Symbol | Component | Function |
|---|---|---|
| $V_{S,A}$, $V_{S,B}$ | EV1 / EV2 batteries | Source or sink, depending on mode |
| $L_F$, $C_F$ | Battery-side filter | Limit battery current and voltage ripple |
| $M_{x,1}$–$M_{x,2}$ + $C_D$ | Boost/buck leg + DC link | Voltage-gain stage |
| $M_{x,3}$–$M_{x,6}$ | High-frequency H-bridge | Excites the connector ($M_{x,5}$ held on, $M_{x,6}$ held off) |
| $C_R$, $L_R$ | Series-resonant tank ($L_R$ = transformer leakage) | Shapes current, supports soft switching |
| HFT ($L_M$, $R_M$) | 1:1 high-frequency transformer | Galvanic isolation; magnetizing inductance and core loss modelled |

### Gate-signal assignment

The controller produces a PWM signal with duty ratio $D$ and its complement (NPWM). The two modes use the same hardware and differ only in this mapping:

| Signal | Mode 1 (EV1 → EV2) | Mode 2 (EV2 → EV1) |
|---|---|---|
| PWM ($D$) | M1,2, M1,3, M2,1, M2,4 | M1,1, M1,4, M2,2, M2,3 |
| NPWM ($1-D$) | M1,1, M1,4, M2,2, M2,3 | M1,2, M1,3, M2,1, M2,4 |
| Constant 1 | M1,5, M2,5 | M1,5, M2,5 |
| Constant 0 | M1,6, M2,6 | M1,6, M2,6 |

**Mode 1, stage 1 (PWM high):** battery A stores energy in $L_{F,A}$ through $M_{1,2}$, $C_{R,A}$ discharges through the resonant network, and the HFT transfers energy to side B, where $L_{F,B}$ releases energy into battery B.

**Mode 1, stage 2 (NPWM high):** the energy in $L_{F,A}$ is released, together with energy from the source, into the DC link, and the source bridge recharges the tank. Energy again passes through the HFT, and $L_{F,B}$ charges while battery B keeps charging.

**Mode 2:** the PWM and NPWM assignments are swapped, so power flows from battery B to battery A.

---

## Design calculations

### Specifications

| Parameter | Value |
|---|---|
| EV1 battery | 350 V, 60 Ah |
| EV2 battery | 450 V, 80 Ah |
| Rated power | 24 kW |
| Switching frequency $f_S$ | 20 kHz |
| Filter inductance $L_{F,A}$ / $L_{F,B}$ | 3.14 mH / 4.8 mH |
| Filter capacitance $C_{F,A}$ / $C_{F,B}$ | 2 µF / 1.3 µF |
| DC-link capacitance $C_{D,A}$ / $C_{D,B}$ | 0.5 mF / 0.8 mF |
| Resonant capacitance $C_R$ (each side) | 0.21 mF |
| Resonant (leakage) inductance $L_R$ (each side) | 0.3015 µH |
| HFT turns ratio | 1:1 |
| Switch model (loss study) | Infineon IKWH75N65EH7 IGBT |

### 1. Battery-side filters

The filter inductor and capacitor are sized for a 5 % current ripple at $D = 0.57$:

$$L_F = \frac{V_L\,D}{\Delta I_L\, f_S}, \qquad C_F = \frac{\Delta I}{8\, f_S\, \Delta V}$$

**EV1 side** ($I_{L,rated}$ = 63.5 A, $V_L$ = 350 V):

$$L_{F,A} = \frac{350 \times 0.57}{0.05 \times 63.5 \times 20\times10^{3}} = 3.14\ \text{mH}$$

$$\frac{\Delta V}{V} = \frac{0.05 \times 63.5}{8 \times 20\times10^{3} \times 2\times10^{-6} \times 350} \approx 2.8\% \approx 3\% \quad (C_{F,A} = 2\ \mu\text{F})$$

**EV2 side** ($I_{L,rated}$ = 52.9 A, $V_L$ = 450 V):

$$L_{F,B} = \frac{450 \times 0.57}{0.05 \times 52.9 \times 20\times10^{3}} = 4.8\ \text{mH}$$

$$\frac{\Delta V}{V} = \frac{0.05 \times 52.9}{8 \times 20\times10^{3} \times 1.3\times10^{-6} \times 450} \approx 2.8\% \approx 3\% \quad (C_{F,B} = 1.3\ \mu\text{F})$$

### 2. Resonant tank

$$f_R = \frac{1}{2\pi\sqrt{L_R C_R}} = \frac{1}{2\pi\sqrt{0.3015\times10^{-6} \times 0.21\times10^{-3}}} \approx 20\ \text{kHz} = f_S$$

The switching frequency is set equal to the resonant frequency. The open-loop gain study confirms that the gain is highest at $f_S/f_R = 1$.

### 3. Voltage gain (idealized)

Treat the series tank and the 1:1 HFT, operated at resonance, as the energy-transfer path of a Ćuk converter with average transfer voltage $V_T$. Volt–second balance on the two filter inductors gives:

$$D\,V_{S,A} + (1-D)(V_{S,A}-V_T) = 0 \;\Rightarrow\; V_T = \frac{V_{S,A}}{1-D}$$

$$D\,(V_T - V_{S,B}) - (1-D)\,V_{S,B} = 0 \;\Rightarrow\; V_{S,B} = D\,V_T$$

$$\boxed{\frac{V_{S,B}}{V_{S,A}} = \frac{D}{1-D}\ \ (\text{Mode 1}), \qquad \frac{V_{S,A}}{V_{S,B}} = \frac{1-D}{D}\ \ (\text{Mode 2})}$$

These relations assume lossless components, unity tank gain and continuous inductor current. They locate the operating region; the actual duty ratios come from simulation (see [Results](#results)).

### 4. Equivalent load for the open-loop tests

$$R_L = \frac{V_{nom}^2}{P_{rated}}: \qquad R_{L,EV2} = \frac{450^2}{24\,000} = 8.4375\ \Omega, \qquad R_{L,EV1} = \frac{350^2}{24\,000} = 5.1042\ \Omega$$

---

## Controller design

All three controllers regulate the receiving battery's current and use the same structure:

`mode selection → error e = I_ref − I_meas → control law → duty-ratio limiter → compare with triangular carrier → PWM / NPWM → gate mapping`

The regulated current is $I_{B2}$ in Mode 1 and $I_{B1}$ in Mode 2. Only the control law changes between the three models.

### PI controller

$$u(t) = K_p\,e(t) + K_i \int_0^t e(\tau)\,d\tau$$

| Parameter | Value |
|---|---|
| Tuning method | Ziegler–Nichols |
| $K_p$ | 0.0001 |
| $K_i$ | 0.015 |

### Integral sliding-mode controller (ISMC)

Sliding surface and boundary-layer control law:

$$s(t) = e(t) + \lambda \int_0^t e(\tau)\,d\tau, \qquad D_{cmd} = D_0 + k\,\text{sat}\!\left(\frac{s}{\phi}\right)$$

| Parameter | Value | Role |
|---|---|---|
| $\lambda$ | 2 | Weight of the integral error |
| $\phi$ | 0.5 | Boundary-layer width (scales $s$ before saturation) |
| $k$ | 0.005 | Correction gain |
| $D_0$ | 0.5 | Nominal duty ratio |

The saturation function replaces the sign function to reduce chattering.

### Fuzzy logic controller (FLC)

Mamdani system, file `ev_v2v.fis`. Inputs are the error $e(k)$ and the change in error $\Delta e(k) = e(k) - e(k-1)$, both normalized to [−1, 1]. The output is the duty command on [0, 1].

| Variable | Membership functions (triangular, `[a b c]`) |
|---|---|
| `error`, `del_error` | NB `[-1 -1 -0.5]` · NS `[-1 -0.5 0]` · Z `[-0.25 0 0.25]` · PS `[0 0.5 1]` · PB `[0.5 1 1]` |
| `control` | Low `[0.30 0.40 0.50]` · Medium `[0.45 0.50 0.55]` · High `[0.50 0.60 0.70]` |

**Rule base** (L = Low, M = Medium, H = High). Rows are `error`, columns are `del_error`:

| e \ Δe | NB | NS | Z | PS | PB |
|---|---|---|---|---|---|
| **NB** | H | H | H | M | M |
| **NS** | H | H | M | M | L |
| **Z** | H | M | M | M | L |
| **PS** | M | M | M | L | L |
| **PB** | M | L | L | L | L |

Inference uses AND = min, OR = max, implication = min and aggregation = max, with **centroid** defuzzification:

$$u^* = \frac{\int_0^1 u\,\mu_{agg}(u)\,du}{\int_0^1 \mu_{agg}(u)\,du}$$

> ⚠️ **Check the `.fis` file.** In the original file, rule 10 was `1 5, 1 (1) : 1`. That duplicates the NB/PB cell (rule 5 gives Medium) and leaves NS/PB undefined. The table above assumes the intended rule `2 5, 1 (1) : 1`. Correct the file if it still has the typo.

---

## Results

### 1. Open-loop: voltage gain and operating points

![Voltage gain surface](docs/images/openloop_gain_surface.png)

The gain is highest at $f_S/f_R = 1$ and falls as the switching frequency moves away from resonance. At a given frequency ratio, a larger $D$ raises the gain.

![Duty-ratio sweep](docs/images/openloop_duty_sweep.png)

| Mode | Target voltage | Simulated $D$ | Ideal voltage from gain equation | Deviation |
|---|---|---|---|---|
| Mode 1 | 450 V | **0.5724** | 468.5 V | −3.9 % |
| Mode 2 | 350 V | **0.5710** | 338.1 V | +3.5 % |

The simulated operating points are within 4 % of the idealized gain. The difference comes from the switch, tank and transformer effects that the ideal equation neglects.

### 2. Open-loop waveforms

**Mode 1 (EV1 → EV2), rated operating point**

| Source side | Receiving side | Power |
|---|---|---|
| ![](docs/images/openloop_mode1_source_side.png) | ![](docs/images/openloop_mode1_receiving_side.png) | ![](docs/images/openloop_mode1_power.png) |

| Quantity (Mode 1) | Value (read from waveforms) |
|---|---|
| Source current | ≈ 94 A (ripple ≈ ±3 A) |
| DC-link voltage (CDC1) | ≈ 936 V |
| Primary bridge voltage | 0–950 V unipolar pulses |
| Transformer primary current | ≈ −250 A to +300 A |
| Load voltage / current | ≈ 446 V (±2 V) / ≈ 52.9 A |
| Input / output power | ≈ 33.1 kW / ≈ 23.6 kW → **η ≈ 71 %** |

**Mode 2 (EV2 → EV1)**

| Source side | Power |
|---|---|
| ![](docs/images/openloop_mode2_source_side.png) | ![](docs/images/openloop_mode2_power.png) |

| Quantity (Mode 2) | Value (read from waveforms) |
|---|---|
| Source voltage / current | 450 V / ≈ 47.8 A |
| DC-link voltage | ≈ 786 V |
| Load voltage / current | ≈ 322 V / ≈ 63.3 A |
| Input / output power | ≈ 21.5 kW / ≈ 20.4 kW → **η ≈ 95 %** |

### 3. Closed-loop steady-state current tracking

Reference: 10 → 50 A in 10 A steps every 3 s. Each value is the mean regulated current between 0.6 s and 2.8 s after a step.

| Mode 1 – EV1 current I<sub>B1</sub> | Mode 1 – EV2 current I<sub>B2</sub> (negative = charging) |
|---|---|
| ![](docs/images/steadystate_IB1_comparison.png) | ![](docs/images/steadystate_IB2_comparison.png) |

| Reference (A) | 10 | 20 | 30 | 40 | 50 | Resolution |
|---|---|---|---|---|---|---|
| **Mode 1 – PI** | ≈0 | 9.4 | 19.2 | 29.1 | 39.3 | ±0.6 |
| **Mode 1 – ISMC** | 10.2 | 19.8 | 29.7 | 39.5 | 49.7 | ±0.6 |
| **Mode 1 – FLC** | ≈0 | 10 | 19 | 29 | 39 | ±1.5 |
| **Mode 2 – PI** | 10 | 21 | 31 | 40 | 51 | ±3 |
| **Mode 2 – ISMC** | 9.9 | 20\* | 29.8 | 39.8 | 49.7 | ±0.5 |
| **Mode 2 – FLC** | ≈0 | 12 | 21 | 31 | 42 | ±2 |

\* Converges slowly within this step, from about 17 A to 22 A.
Peak-to-peak ripple of the regulated current is about 9–11 A for all three controllers.

> In the overlay plots the FLC trace (blue) is hidden under the PI trace, because in Mode 1 they settle at the same levels.

### 4. Start-up transient (Mode 1, first 0.1 s)

| EV1 current | EV2 current |
|---|---|
| ![](docs/images/transient_IB1.png) | ![](docs/images/transient_IB2.png) |
| **EV1 voltage** | **EV2 voltage** |
| ![](docs/images/transient_VB1.png) | ![](docs/images/transient_VB2.png) |

| Controller | Peak \|I<sub>B1</sub>\| (A) | Peak \|I<sub>B2</sub>\| (A) | Max ΔV<sub>B2</sub> (V) | t<sub>s</sub> V<sub>B1</sub> (ms) | t<sub>s</sub> V<sub>B2</sub> (ms) | t<sub>s</sub> I<sub>B2</sub> (ms) |
|---|---|---|---|---|---|---|
| PI | 625 | 1567 | 86.2 | 74.3 | 70.6 | 84.5 |
| ISMC | 600 | 594 | 34.1 | 22.1 | 8.6 | 14.5 |
| FLC | ≈600 | ≈594 | ≈34 | 21.8 | 8.6 | 14.2 |

$t_s$ is the settling time to ±2 % of the final value for voltages and to ±20 A for currents. FLC coincides with ISMC during the first 5 ms. Extraction resolution is about ±2.5 A, ±0.15 V and ±0.07 ms.

### 5. Efficiency

![Efficiency vs SOC](docs/images/efficiency_vs_soc.png)

The receiving battery is held at 25 % SOC while the source-battery SOC is swept.

| SOC of source (%) | 40 | 45 | 50 | 55 | 65 | 75 | **Mean** |
|---|---|---|---|---|---|---|---|
| **Mode 1 – PI** | 91.78 | 89.95 | 90.78 | 92.52 | 91.28 | 92.76 | **91.51** |
| **Mode 1 – ISMC** | 89.24 | 88.06 | 87.75 | 87.25 | 88.17 | 89.62 | **88.35** |
| **Mode 1 – FLC** | 89.54 | 89.16 | 87.60 | 88.62 | 89.87 | 89.58 | **89.06** |
| **Mode 2 – PI** | 88.29 | 90.19 | 90.27 | 90.38 | 90.10 | 90.10 | **89.89** |
| **Mode 2 – ISMC** | 91.76 | 93.25 | 92.14 | 93.50 | 92.09 | 90.90 | **92.27** |
| **Mode 2 – FLC** | 92.58 | 93.84 | 92.85 | 94.60 | 94.64 | 93.13 | **93.61** |

$\eta = P_{out}/P_{in} \times 100\%$

### 6. Semiconductor losses (ISMC, Mode 2)

Conduction loss uses the datasheet $V_{CE,sat}(I_C)$ curve, and switching loss uses the datasheet $E_{on}$/$E_{off}$ energies at each detected gate transition:

$$P_{cond} = V_{CE,sat}(I_C)\, I_C, \qquad P_{sw} = \frac{\sum E_{on} + \sum E_{off}}{t_{end} - t_{start}}$$

![Loss per switch](docs/images/semiconductor_losses_per_switch.png)

| Side | Conduction (W) | Switching (W) | Total (W) |
|---|---|---|---|
| EV1 | 124.96 | 147.23 | 272.19 |
| EV2 | 140.95 | 125.19 | 266.13 |
| **Total** | **265.91** | **272.42** | **538.32** |

- Switching loss dominates in the switched legs (EV1-S1, EV1-S2).
- The always-on switches (EV1-S7, EV2-S7) have conduction loss only.
- Inactive switches show zero loss.

> ⚠️ The report text gives the averaging window as 0.2–1.5 s, but `avg_loss.m` uses `t >= 0.2 & t <= 10`. Make the two match. The window falls in the first (10 A) reference step, so do **not** quote these losses as a percentage of the 24 kW rating.

### 7. OPAL-RT software-in-the-loop

| Setup | PI – Mode 1 |
|---|---|
| ![](docs/images/opalrt_setup.png) | ![](docs/images/opalrt_pi_mode1.png) |
| **ISMC – Mode 1** | **FLC – Mode 1** |
| ![](docs/images/opalrt_ismc_mode1.png) | ![](docs/images/opalrt_flc_mode1.png) |

The model runs in real time on the OP4610XG with a 5 µs step. Oscilloscope captures of battery voltage, current, power and SOC show the stepwise response and a monotonic SOC change for all three controllers in both modes, matching the offline results. These are **SIL** results: the converter is simulated, not hardware.

---

## Analysis and discussion

| Criterion | PI | ISMC | FLC |
|---|---|---|---|
| Steady-state tracking, Mode 1 | Offset ≈ 10 A | Within ≈ 0.5 A | Offset ≈ 10 A |
| Steady-state tracking, Mode 2 | Within ≈ 1 A | Within ≈ 0.5 A (slow in one step) | Offset 8–11 A |
| Start-up peak \|I<sub>B2</sub>\| (Mode 1) | 1567 A | 594 A | ≈594 A |
| Settling time of V<sub>B2</sub> (Mode 1) | 70.6 ms | 8.6 ms | 8.6 ms |
| Mean efficiency, Mode 1 / Mode 2 | 91.51 % / 89.89 % | 88.35 % / 92.27 % | 89.06 % / 93.61 % |
| Real-time SIL | ✔ both modes | ✔ both modes | ✔ both modes |

**1. Performance depends on the power-flow direction.** ISMC is the **only controller that tracks the reference in both directions**. With the present tuning, PI tracks only in Mode 2, and FLC tracks in neither mode. The gate mapping changes with the mode, so a controller tuned for one direction cannot be assumed to work in the other.

**2. ISMC and FLC improve start-up behaviour.** They cut the start-up current peak by about **62 %** and the voltage dip by about **60 %**, and settle **3–8× faster** than PI. The two behave almost identically in this interval.

**3. The efficiency ranking is confounded.** In each direction, the most efficient controller (PI in Mode 1, FLC in Mode 2) is also one that delivers about 10 A **less** current than the reference. Losses grow with current, so part of the difference reflects the operating point rather than the control law. The cleaner comparison is Mode 2, where both ISMC and PI track the reference: ISMC is about **2.4 points** more efficient there. Efficiency should be re-measured at equal delivered power.

**4. The modes behave very differently in open loop.** Mode 1 has a large circulating primary current (±250–300 A) and only about 71 % efficiency at rated power. Mode 2 shows about 95 % at its recorded operating point. The resonant link needs optimizing for Mode 1.

**Why the offsets appear (likely causes):**
- **PI:** the Ziegler–Nichols gains ($K_p$ = 0.0001, $K_i$ = 0.015) were tuned once and reused in both directions. The integral action is too weak to remove the Mode 1 error within a 3 s step.
- **FLC:** there is no explicit integral state, and the narrow output membership functions (0.3–0.7) limit the duty correction to about ±0.1 around 0.5.

**Overall:** of the three controllers as tuned here, **ISMC is the most suitable for this topology**.

---

## Limitations

- **Simulation and SIL only.** No hardware-in-the-loop (HIL) testing or prototype yet.
- **Tuning.** PI and FLC were not retuned per direction, and their steady-state offsets make the efficiency comparison partly unfair.
- **Initial conditions.** Some runs start from different SOCs, so absolute SOC traces are not directly comparable.
- **Metric extraction.** The transient and steady-state metrics were read from recorded waveform plots (resolutions are listed). Re-extracting them from logged data, for example with `stepinfo`, would tighten them.
- **Device ratings.** The simulated DC link reaches about 936 V (Mode 1) and about 786 V (Mode 2), and the primary current reaches about 300 A. The IGBT used for the loss model is rated 650 V / 75 A. A real design needs 1200 V-class devices (for example SiC MOSFETs), so the loss figures are indicative only.
- **Not modelled.** Soft-start, protection, thermal behaviour, EMI and inter-vehicle communication.

---

## Future work

- Retune PI per direction and add integral action to the FLC; repeat the efficiency comparison at equal delivered power.
- HIL validation on the OPAL-RT platform.
- Compare Si and SiC devices for losses and efficiency.
- Optimize the resonant tank to reduce circulating current in Mode 1.
- PCB design and a hardware prototype with OBC-compatible interfaces and a vehicle-to-vehicle communication link.

---

## Authors

- **N. Subramanian**
- **Sahas Vishanth M. V.**
- **Tanukasree R.**

**Supervisor:** Dr. G. Kanimozhi

School of Electrical Engineering (SELECT), Vellore Institute of Technology, Chennai, India.

The authors thank the School of Electrical Engineering, VIT Chennai, for access to the OPAL-RT real-time simulation laboratory.

---

## Citation and license

The converter topology modelled here is from:

> R. Zhou, B. Chong, B. Labaleine, J. Arnett, and L. Zhang, "A novel isolated connector for bidirectional direct V2V charging using onboard chargers," *e-Prime – Nexus of Electrical, Electronic, and Intelligent Engineering*, vol. 17, Art. no. 201193, 2026. https://doi.org/10.1016/j.eprime.2026.201193

Switch data for the loss model: Infineon IKWH75N65EH7 (650 V TRENCHSTOP IGBT7) datasheet.

If you use this repository, please cite it as:

```
N. Subramanian, Sahas Vishanth M. V., Tanukasree R., and G. Kanimozhi,
"Isolated Single-Stage Bidirectional V2V EV Charging Converter: PI, ISMC and Fuzzy Current Control,"
GitHub repository, 2026.
```
