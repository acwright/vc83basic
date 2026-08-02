#!/usr/bin/env python3
"""
generate_lexer_data.py

Generates 6502 assembly language data tables for a finite-state lexer directly from regexes.
Outputs ca65-compatible assembly code to stdout.
"""

import sys
from collections import deque

# ==============================================================================
# TOKEN REGEX DEFINITIONS & SUPPORTED SYNTAX
# ==============================================================================
# Supported Regex Constructs:
#   - Literals        : Standard characters (a, b, 0, 1, +, ", etc.)
#   - Wildcard        : . (matches any printable ASCII character; \. for literal dot)
#   - Escape Sequences: \ followed by character (\+, \-, \*, \", \\, \.)
#   - Character Sets  : [...] supporting ranges (e.g. [a-z], [A-Z], [0-9], [ !#-~])
#                       (Note: '^' inside brackets is treated as a literal char)
#   - Grouping        : (...)
#   - Alternation     : | (e.g., cat|dog or ("..."|'...'))
#   - Quantifiers     : * (0 or more), + (1 or more), ? (0 or 1 optional)
# ==============================================================================
TOKEN_SPECS = [
    ("TOK_EOL", r'\0'),
    ("TOK_COMMA", r','),
    ("TOK_SEMI", r';'),
    ("TOK_LPAREN", r'\('),
    ("TOK_RPAREN", r'\)'),
    ("TOK_STRING", r'("[ !#-~]*")+'),
    ("TOK_NUM", r'([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)?'),
    ("TOK_OPERATOR", r'[-+/*^&<=>][>=]?'),
    ("TOK_NAME", r'[a-zA-Z][a-zA-Z0-9_]+\$?'),
]


class NFAState:
    """Represents a state in a Non-deterministic Finite Automaton (NFA)."""

    def __init__(self, state_id):
        self.id = state_id
        self.transitions = {}

    def add_transition(self, char_or_epsilon, target_state):
        if char_or_epsilon not in self.transitions:
            self.transitions[char_or_epsilon] = []
        self.transitions[char_or_epsilon].append(target_state)


class NFA:
    """Represents an NFA fragment with start and end states."""

    def __init__(self, start_state, end_state):
        self.start = start_state
        self.end = end_state


class NFABuilder:
    """Parses basic regular expressions into NFAs using Thompson's construction."""

    def __init__(self):
        self.next_state_id = 0

    def new_state(self):
        state = NFAState(self.next_state_id)
        self.next_state_id += 1
        return state

    def from_char_set(self, chars):
        start = self.new_state()
        end = self.new_state()
        for c in chars:
            start.add_transition(c, end)
        return NFA(start, end)

    def parse_regex(self, pattern):
        nfa, pos = self._parse_alternation(pattern, 0)
        return nfa

    def _parse_alternation(self, pattern, pos):
        left, pos = self._parse_concat(pattern, pos)
        while pos < len(pattern) and pattern[pos] == '|':
            pos += 1
            right, pos = self._parse_concat(pattern, pos)
            start = self.new_state()
            end = self.new_state()
            start.add_transition(None, left.start)
            start.add_transition(None, right.start)
            left.end.add_transition(None, end)
            right.end.add_transition(None, end)
            left = NFA(start, end)
        return left, pos

    def _parse_concat(self, pattern, pos):
        atoms = []
        while pos < len(pattern) and pattern[pos] not in ')|':
            atom, pos = self._parse_quantifier(pattern, pos)
            atoms.append(atom)

        if not atoms:
            s = self.new_state()
            e = self.new_state()
            s.add_transition(None, e)
            return NFA(s, e), pos

        result = atoms[0]
        for next_atom in atoms[1:]:
            result.end.add_transition(None, next_atom.start)
            result = NFA(result.start, next_atom.end)
        return result, pos

    def _parse_quantifier(self, pattern, pos):
        atom, pos = self._parse_atom(pattern, pos)

        if pos < len(pattern):
            op = pattern[pos]
            if op == '*':
                pos += 1
                start = self.new_state()
                end = self.new_state()
                start.add_transition(None, atom.start)
                start.add_transition(None, end)
                atom.end.add_transition(None, atom.start)
                atom.end.add_transition(None, end)
                atom = NFA(start, end)
            elif op == '+':
                pos += 1
                start = self.new_state()
                end = self.new_state()
                start.add_transition(None, atom.start)
                atom.end.add_transition(None, atom.start)
                atom.end.add_transition(None, end)
                atom = NFA(start, end)
            elif op == '?':
                pos += 1
                start = self.new_state()
                end = self.new_state()
                start.add_transition(None, atom.start)
                start.add_transition(None, end)
                atom.end.add_transition(None, end)
                atom = NFA(start, end)

        return atom, pos

    def _parse_atom(self, pattern, pos):
        if pos >= len(pattern):
            s = self.new_state()
            e = self.new_state()
            s.add_transition(None, e)
            return NFA(s, e), pos

        char = pattern[pos]

        if char == '(':
            pos += 1
            nfa, pos = self._parse_alternation(pattern, pos)
            if pos < len(pattern) and pattern[pos] == ')':
                pos += 1
            return nfa, pos

        elif char == '[':
            pos += 1
            chars = set()
            while pos < len(pattern) and pattern[pos] != ']':
                if pattern[pos] == '\\' and pos + 1 < len(pattern):
                    c = pattern[pos + 1]
                    pos += 2
                else:
                    c = pattern[pos]
                    pos += 1

                if pos + 1 < len(pattern) and pattern[pos] == '-' and pattern[pos + 1] != ']':
                    pos += 1
                    if pattern[pos] == '\\' and pos + 1 < len(pattern):
                        end_c = pattern[pos + 1]
                        pos += 2
                    else:
                        end_c = pattern[pos]
                        pos += 1
                    for code in range(ord(c), ord(end_c) + 1):
                        chars.add(chr(code))
                else:
                    chars.add(c)

            if pos < len(pattern) and pattern[pos] == ']':
                pos += 1
            return self.from_char_set(chars), pos

        elif char == '.':
            pos += 1
            # Wildcard: matches any printable ASCII character (ASCII 32..126)
            any_chars = set(chr(c) for c in range(32, 127))
            return self.from_char_set(any_chars), pos

        elif char == '\\' and pos + 1 < len(pattern):
            escaped_char = pattern[pos + 1]
            pos += 2
            if escaped_char == '0':
                escaped_char = '\x00'
            return self.from_char_set({escaped_char}), pos


        else:
            pos += 1
            return self.from_char_set({char}), pos


def epsilon_closure(states):
    """Compute the epsilon closure for a set of NFA states."""
    closure = set(states)
    stack = list(states)
    while stack:
        state = stack.pop()
        for target in state.transitions.get(None, []):
            if target not in closure:
                closure.add(target)
                stack.append(target)
    return closure


def build_dfa(token_specs):
    """
    Builds a DFA from token regular expressions.
    Returns:
        dfa_transitions: dict[state_id, dict[char, next_state_id]]
        initial_state: int
        dfa_state_types: dict[state_id, token_name]
    """
    builder = NFABuilder()
    named_nfas = []
    for token_name, pattern in token_specs:
        nfa = builder.parse_regex(pattern)
        named_nfas.append((token_name, nfa))

    global_start = builder.new_state()
    nfa_final_tags = {}

    for token_name, nfa in named_nfas:
        global_start.add_transition(None, nfa.start)
        # Tag all terminal states for this token (supports multiple final states per NFA)
        final_states = getattr(nfa, 'final_states', [nfa.end] if hasattr(nfa, 'end') else [])
        for final_state in final_states:
            nfa_final_tags[final_state] = token_name


    start_closure = frozenset(epsilon_closure({global_start}))
    dfa_state_map = {start_closure: 0}
    dfa_transitions = {}
    dfa_state_types = {}

    queue = deque([start_closure])

    while queue:
        current_set = queue.popleft()
        current_id = dfa_state_map[current_set]

        matched_type = None
        for token_name, _ in named_nfas:
            if any(nfa_final_tags.get(s) == token_name for s in current_set):
                matched_type = token_name
                break

        if matched_type:
            dfa_state_types[current_id] = matched_type

        char_targets = {}
        for nfa_state in current_set:
            for char, targets in nfa_state.transitions.items():
                if char is not None:
                    char_targets.setdefault(char, set()).update(targets)

        dfa_transitions[current_id] = {}
        for char, target_nfa_states in char_targets.items():
            target_closure = frozenset(epsilon_closure(target_nfa_states))
            if target_closure not in dfa_state_map:
                next_id = len(dfa_state_map)
                dfa_state_map[target_closure] = next_id
                queue.append(target_closure)

            dfa_transitions[current_id][char] = dfa_state_map[target_closure]

    initial_state_id = dfa_state_map[start_closure]
    return dfa_transitions, initial_state_id, dfa_state_types


def get_character_ranges(transitions_dict):
    """
    Compress character transitions dict into contiguous character ranges:
    Returns list of tuples: [(min_char, max_char, target_state), ...]
    """
    if not transitions_dict:
        return []

    sorted_chars = sorted(transitions_dict.keys(), key=lambda c: ord(c))
    ranges = []

    curr_min = sorted_chars[0]
    curr_max = sorted_chars[0]
    curr_target = transitions_dict[curr_min]

    for c in sorted_chars[1:]:
        target = transitions_dict[c]
        if ord(c) == ord(curr_max) + 1 and target == curr_target:
            curr_max = c
        else:
            ranges.append((curr_min, curr_max, curr_target))
            curr_min = c
            curr_max = c
            curr_target = target

    ranges.append((curr_min, curr_max, curr_target))
    return ranges


def generate_6502_asm(token_specs):
    """Generates ca65 assembly data tables for the DFA."""
    dfa_transitions, initial_state_id, dfa_state_types = build_dfa(token_specs)
    num_states = len(dfa_transitions)

    lines = []
    lines.append("; ========================================================")
    lines.append("; Auto-Generated 6502 Assembly Lexer Data Tables")
    lines.append("; ========================================================")
    lines.append("")

    # Output each state's data table
    for state_id in range(num_states):
        token_name = dfa_state_types.get(state_id, "<(-1)")
        ranges = get_character_ranges(dfa_transitions.get(state_id, {}))
        num_trans = len(ranges)

        lines.append(f"state_{state_id}:")
        lines.append(f"    .byte {token_name:<11}       ; Terminal token tag (<(-1) if non-terminal)")

        lines.append(f"    .byte ${num_trans:02X}               ; Number of transitions")

        if num_trans == 0:
            lines.append("    ; (No transitions out of this state)")
        else:
            for min_c, max_c, target_st in ranges:
                count = ord(max_c) - ord(min_c) + 1
                min_code = f"${ord(min_c):02X}"
                count_code = f"${count:02X}"
                target_hex = f"${target_st:02X}"

                if min_c == max_c:
                    char_desc = f"'{min_c}'" if min_c.isprintable() and min_c != "'" else f"ASCII ${ord(min_c):02X}"
                else:
                    min_desc = f"'{min_c}'" if min_c.isprintable() and min_c != "'" else f"${ord(min_c):02X}"
                    max_desc = f"'{max_c}'" if max_c.isprintable() and max_c != "'" else f"${ord(max_c):02X}"
                    char_desc = f"{min_desc} to {max_desc}"

                comment = f"Transition: {char_desc} ({count} chars) -> state_{target_st}"
                lines.append(
                    f"    .byte {min_code}, {count_code}, {target_hex} ; {comment}"
                )

        lines.append("")

    # Output split high/low address tables
    lines.append("; Address tables (low/high bytes split for 6502 indexing)")
    lines.append("state_table_low:")
    for state_id in range(num_states):
        lines.append(f"    .byte <state_{state_id}")
    lines.append("")

    lines.append("state_table_high:")
    for state_id in range(num_states):
        lines.append(f"    .byte >state_{state_id}")

    return "\n".join(lines)


def main():
    asm_output = generate_6502_asm(TOKEN_SPECS)
    sys.stdout.write(asm_output + "\n")


if __name__ == "__main__":
    main()
