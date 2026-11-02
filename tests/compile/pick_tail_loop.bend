import Base

# A def that gives one of its arguments by the Bool it matches first (a
# pick) computes only the one it gives on JS; in tail position each is a
# tail call, so a recursion through a pick is a loop. (At 200000 JS ran it,
# where it overflowed the host's stack before; the interpreter lane is too
# slow to check that size here.)
def pick(c: Bool, a: Nat, b: Nat) -> Nat:
  match c:
    case True{}:
      a
    case False{}:
      b

def sum(+n: Nat, +acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      pick(Nat.is_eq(p, 0n), Nat.add(acc, 1n), sum(p, Nat.add(acc, 1n)))

def main() -> Nat:
  sum(1000n, 0n)

#|1000n
