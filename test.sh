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

assert 0 "main(){ return 0; }"
assert 42 "main(){ return 42; }"
assert 6 "main(){ return 9-5+2; }"
assert 6 "main(){ return 6/3*2+2; }"
assert 16 "main(){ return ((4/2)*2)*4; }"
assert 1 "main(){ return -3*2 + 7; }"
assert 1 "main(){ return 0==0; }"
assert 0 "main(){ return 3!=3; }"
assert 1 "main(){ return 3<5; }"
assert 2 "main(){ return (2>1) + (3<=5); }"
assert 3 "main(){ return a=3;b=5;cc=6;return a; }"
assert 5 "main(){ return 5; return 4; }"
assert 4 "main(){ if(0)return 5; return 4; }"
assert 15 "main(){ if(1)return 15; return 4; }"
assert 14 "main(){ if(0)return 15; else return 14; return 4; }"
assert 21 "main(){ a=10;if(a==1)return 5; else if(a==10) return 21; else return 4; return 6; }"
assert 3 "main(){ a = 10; while(a==0)a = a - 1; return 3; }"
assert 5 "main(){ if(1){a = 10;a = a - 5; return a;} return 1; }"
assert 12 "main(){ a = 0;for(i = 0;i < 3; i = i + 1){a = a + 4;5;} return a; }"
assert 4 "foo(){ return 5;} main(){ return 4;}"
assert 5 "foo(){ return 5;} main(){ return foo();}"

echo OK