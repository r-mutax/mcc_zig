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

assert 0 "return 0;"
assert 42 "return 42;"
assert 6 "return 9-5+2;"
assert 6 "return 6/3*2+2;"
assert 16 "return ((4/2)*2)*4;"
assert 1 "return -3*2 + 7;"
assert 1 "return 0==0;"
assert 0 "return 3!=3;"
assert 1 "return 3<5;"
assert 2 "return (2>1) + (3<=5);"
assert 3 "return a=3;b=5;cc=6;return a;"
assert 5 "return 5; return 4;"
assert 4 "if(0)return 5; return 4;"
assert 15 "if(1)return 15; return 4;"

echo OK