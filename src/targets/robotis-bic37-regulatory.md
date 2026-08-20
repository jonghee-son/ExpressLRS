# ROBOTIS BIC37 regulatory firmware candidates

These builds are inputs to certification testing. They are not evidence of CE,
FCC, KC, or Japanese technical-conformity approval by themselves.

This receiver and every environment in this document support **2.4 GHz only**.
They use the SX1280 driver and do not include a 900 MHz regulatory domain.

The final antenna is the Taoglas GW.48.A151, specified with 1.82 dBi peak gain
at 2.4 GHz. The normal ExpressLRS modes use approximately 600 kHz FLRC or
800 kHz LoRa bandwidth.

## Build matrix

| Region | Production candidate | Laboratory firmware | Firmware restriction |
| --- | --- | --- | --- |
| CE | `ROBOTIS_2400_RX_CE_via_UART` | `ROBOTIS_2400_RX_CE_CERT_TEST_via_UART` | CE LBT; nominal maximum 50 mW |
| FCC | `ROBOTIS_2400_RX_FCC_via_UART` | `ROBOTIS_2400_RX_FCC_CERT_TEST_via_UART` | ISM FHSS; nominal maximum 100 mW |
| Korea | `ROBOTIS_2400_RX_KC_CANDIDATE_via_UART` | `ROBOTIS_2400_RX_KC_CERT_TEST_via_UART` | Nominal 10 mW setting only; calibration required |
| Japan | `ROBOTIS_2400_RX_JP_GITEKI_CANDIDATE_via_UART` | `ROBOTIS_2400_RX_JP_GITEKI_CERT_TEST_via_UART` | Nominal 10 mW setting only; lab must confirm ARIB STD-T66 classification |

The CE limit is 20 dBm EIRP. A nominal 50 mW conducted output is approximately
17 dBm; adding 1.82 dBi antenna gain gives 18.82 dBm EIRP before cable loss and
production tolerance. The 50 mW cap therefore provides about 1.18 dB nominal
margin. This calculation must be replaced by measured worst-case results.

Korean and Japanese limits are based on measured power density. A nominal
10 mW setting is not proof of compliance. At 10 mW/MHz, an idealized 600 kHz
signal corresponds to 6 mW total and an 800 kHz signal corresponds to 8 mW.
The laboratory must measure the actual occupied bandwidth and power density;
the first entry of `power_values` may need to be reduced afterward.

Build all candidates from `src` with:

```powershell
.\build-robotis-regulatory.cmd
```

To embed the same binding phrase in every build:

```powershell
.\build-robotis-regulatory.cmd -BindPhrase "my private phrase"
```

The phrase is passed only to the build process and is not written to
`user_defines.txt` or printed by the helper. To keep it out of PowerShell
history, read it into a variable first:

```powershell
$phrase = Read-Host "ExpressLRS binding phrase"
.\build-robotis-regulatory.ps1 -BindPhrase $phrase
Remove-Variable phrase
```

The same phrase must also be used on the matching 2.4 GHz transmitter.

Artifacts and their SHA-256 hashes are placed under
`artifacts/robotis-regulatory`.

## Conducted-power measurement

Use a 50-ohm RF path:

```text
selected receiver RF port -> coax adapter/cable -> 20 or 30 dB attenuator
                         -> spectrum analyzer or RF power meter
other receiver RF port   -> 50-ohm termination
```

The attenuator must cover 2.4 GHz, tolerate the expected power, and be included
in the analyzer's external-loss correction. Do not run CW into an open port and
do not connect the receiver directly to an analyzer unless its safe input level
is known. Record cable/adapter loss separately.

Flash a `CERT_TEST` environment with `build-flash-robotis-rx.cmd`, for example:

```powershell
.\build-flash-robotis-rx.cmd -EnvironmentName ROBOTIS_2400_RX_FCC_CERT_TEST_via_UART
```

After normal boot, connect to `ExpressLRS RX` using password `expresslrs`, then
open `http://10.0.0.1`. The laboratory-only firmware extends the `/cw` endpoint.
Read its limits with:

```powershell
curl.exe http://10.0.0.1/cw
```

Start CW by selecting radio 1 or 2, a frequency in Hz, and a power-level index:

```powershell
curl.exe -X POST -d "radio=1&frequency=2400400000&power=0" http://10.0.0.1/cw
curl.exe -X POST -d "radio=1&frequency=2440000000&power=0" http://10.0.0.1/cw
curl.exe -X POST -d "radio=1&frequency=2479400000&power=0" http://10.0.0.1/cw
```

Power indices are 0 = 10 mW, 1 = 25 mW, 2 = 50 mW, and 3 = 100 mW nominal.
The endpoint rejects levels above the selected region's firmware cap. Repeat
the requested measurements for both radios. Power-cycle the receiver to stop
CW and return to normal operation.

Continuous CW test firmware must be used only in a shielded test setup or by an
authorized certification laboratory.

## Reference basis

- Taoglas GW.48.A151 antenna data:
  <https://www.taoglas.com/product/gw-48-a151-2dbi-2-4-5-8ghz-dual-band-3-3-5dbi-rubber-duck-dipole-antenna-with-rp-smam/>
- ETSI EN 300 328 V2.2.2:
  <https://www.etsi.org/deliver/etsi_en/300300_300399/300328/02.02.02_60/en_300328v020202p.pdf>
- FCC 47 CFR 15.247:
  <https://www.ecfr.gov/current/title-47/chapter-I/subchapter-A/part-15/subpart-C/section-15.247>
- Korean requirements for unlicensed radio-station equipment (effective
  2026-02-10):
  <https://www.law.go.kr/LSW/admRulInfoP.do?admRulSeq=2100000274462&chrClsCd=010201>
- ARIB STD-T66 overview:
  <https://www.arib.or.jp/kikaku/kikaku_tushin/desc/std-t66.html>

Confirm the applicable rule editions and test plan with the selected
certification body before the formal test campaign.
