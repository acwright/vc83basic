; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

.code
 
exec_dos:
        jmp     (old_dosvec)
