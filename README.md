# Iptables_Semantics

This is a fork of <https://github.com/diekmann/Iptables_Semantics>.
Read the original Readme for more details.

## Changes in this fork

- routing tables
  - support for blackhole routes
  - assumption that interfaces that are not mentioned in the table are never used to send traffic
  - more robust parser
- iptables files
  - fix parsing the protcol ``sctp``
