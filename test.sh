#!/bin/bash
assert() {
  expected="$1"
  input="$2"

  ./zig-out/bin/mcc_zig "$input" > tmp.s
  cc -o tmp tmp.s
  ./tmp
  actual="$?"

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

assert 0 0
assert 42 42
assert 6 "9-5+2"
assert 6 "6/3*2+2"
assert 16 "((4/2)*2)*4"

echo OK