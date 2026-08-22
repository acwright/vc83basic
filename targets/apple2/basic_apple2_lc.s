; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

enable_trig_functions = 1

initialize_target = initialize_target_apple2_lc

.include "apple2.inc"
.include "apple2_extension_lc.s"
.include "basic.s"
.include "main.s"
.include "apple2_startup.s"
.include "apple2_reset_lc.s"
.include "apple2_init.s"
.include "apple2_init_lc.s"
.include "apple2_io.s"
