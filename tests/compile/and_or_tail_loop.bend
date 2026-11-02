import Base

# A tail Bool.or or Bool.and returns its first argument when that decides,
# and its second is a tail call: on JS a recursive any or all is a loop.
# (At 200000 items JS ran it, where it overflowed the host's stack before;
# the interpreter lane is too slow to check that size here.)
def any.go(xs: List<&2, Nat>, +k: Nat) -> Bool:
  match xs:
    case []:
      False{}
    case x <> rest:
      Bool.or(Nat.is_eq(x, k), any.go(rest, k))

def all.go(xs: List<&2, Nat>, +k: Nat) -> Bool:
  match xs:
    case []:
      True{}
    case x <> rest:
      Bool.and(Nat.is_lt(x, k), all.go(rest, k))

def count(+n: Nat, acc: List<&2, Nat>) -> List<&2, Nat>:
  match n:
    case 0n:
      acc
    case 1n+p:
      count(p, p <> acc)

def main() -> Bool & (Bool & Bool):
  +xs = count(1000n, [])
  (any.go(xs, 999n), (any.go(xs, 1000n), all.go(xs, 1000n)))

#|(True{}, False{}, True{})
