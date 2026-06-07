# AdminDoctorCore Resources

The local network scanner uses bundled IEEE Registration Authority CSV data for offline MAC address vendor lookup:

- `oui.csv`: MA-L/OUI assignments from `https://standards-oui.ieee.org/oui/oui.csv`
- `mam.csv`: MA-M assignments from `https://standards-oui.ieee.org/oui28/mam.csv`
- `oui36.csv`: MA-S/OUI-36 assignments from `https://standards-oui.ieee.org/oui36/oui36.csv`

AdminDoctor does not query these sources at runtime. The files are bundled so LAN scans stay local.
