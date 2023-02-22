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

assert 0 "0;"
assert 42 "42;"
assert 6 "9-5+2;"
assert 6 "6/3*2+2;"
assert 16 "((4/2)*2)*4;"
assert 1 "-3*2 + 7;"
assert 1 "0==0;"
assert 0 "3!=3;"
assert 1 "3<5;"
assert 2 "(2>1) + (3<=5);"
assert 3 "a=3;b=5;cc=6;a;"

echo OK