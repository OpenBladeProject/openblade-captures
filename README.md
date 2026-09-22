# OpenBlade capture toolkit

This repository contains Windows tools and reviewed protocol evidence for
researching Razer Blade firmware interfaces. Keeping capture work in a separate
repository helps keep raw evidence out of product releases.

Start with the [capture guide](CAPTURE_GUIDE.md). It explains how to investigate
an unsupported Blade, from device inventory and isolated capture through
readback, restoration, sanitization, and production admission.

Installed Razer driver packages are tracked in the
[`blade-driver-catalog`](https://github.com/OSSBlade/blade-driver-catalog).
Use that catalog for package inventory and export work. This
repository keeps the protocol captures and physical evidence used to decide
whether a package supports a device capability.

General OpenBlade documentation is in
[`OSSBlade/openblade-docs`](https://github.com/OSSBlade/openblade-docs).

## Before you start

- Keep raw PCAP and PCAPNG files local.
- Never commit serial numbers, usernames, local paths, device-instance suffixes,
  or unreviewed payload streams.
- Capture one operator action at a time and investigate queries before writes.
- Never reuse a command from another Blade model without capture and validation
  for the exact target.

The [capture guide](CAPTURE_GUIDE.md) contains the complete safety rules,
commands, tool reference, evidence workflow, and admission checklist.

## Repository layout

- `annotations`: operator actions, provenance, timing, and safety outcomes.
- `decoded`: sanitized request and response fixtures, coverage, and analysis.
- `plans`: reviewed interactive validation plans whose exact bytes are checked.
- `raw`: ignored local PCAP files. Only `.gitkeep` is committed.
- `templates`: versioned starting documents for new investigations.
- `tests`: synthetic offline regressions that never access live hardware.
- `tools`: capture, decoding, comparison, sanitization, and validation scripts.
