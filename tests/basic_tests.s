; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

enable_io_channels = 1
enable_trig_functions = 1

.include "sim6502.inc"
.include "basic.s"
.include "sim6502_init.s"
.include "sim6502_extension.s"
.include "sim6502_io.s"
.include "c_wrappers.s"
