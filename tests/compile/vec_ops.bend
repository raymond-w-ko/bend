import Base

# A Vec is a list to the checker, an array in JS: each op on every lane.
def main() -> List<&2, Nat> & (Nat & (Maybe<&2, Nat> & (Nat & List<&2, Nat>))):
  +v = Vec.push(Nat, Vec.from_list(Nat, [1n, 2n, 3n]), 4n)
  +w = Vec.set(Nat, Vec.set(Nat, v, 1n, 9n), 7n, 5n)
  (Vec.to_list(Nat, w), (Vec.length(Nat, w), (Vec.get(Nat, w, 4n),
    (Vec.at(Nat, w, 9n, 6n), Vec.to_list(Nat, Vec.take(Nat, w, 2n))))))

#|([1n, 9n, 3n, 4n], 4n, None{}, 6n, [1n, 9n])
